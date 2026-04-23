import Foundation
import os

enum HeadGesture: String, CaseIterable, Identifiable, Sendable {
    case left, right, up, down
    var id: String { rawValue }
}

/// Baseline-anchored, velocity-gated gesture detector.
///
/// Maintains a running estimate of the user's "neutral" head position
/// (`baseline`) via slow EMA while at rest. A gesture fires only when the
/// position both (a) leaves the rest zone fast (`velocity > velocityThreshold`)
/// and (b) crosses the trigger radius. After firing, the detector waits in
/// `cooling` for the head to return — so the inevitable return swing of any
/// gesture (e.g. coming back down after looking up) cannot fire its opposite.
final class GestureDetector {
    struct Config: Sendable {
        var triggerRadius: Double = 0.060        // fire when this far from baseline
        var restRadius: Double = 0.022           // closer than this = "at rest"
        var velocityThreshold: Double = 0.25     // normalized units per second
        var baselineAlpha: Double = 0.08         // slow EMA when at rest
        var settleTimeout: TimeInterval = 1.5    // adopt new baseline if held off-center
        var cooldown: TimeInterval = 0.35        // safety: ignore re-fires within this
    }

    enum Phase: String, Sendable {
        case warmup, rest, cooling
    }

    /// Snapshot exposed to the UI (thread-safe).
    struct Snapshot: Sendable {
        var baseline: CGPoint?
        var phase: Phase
    }

    private let configLock = OSAllocatedUnfairLock<Config>(initialState: Config())
    private let snapshotLock = OSAllocatedUnfairLock<Snapshot>(
        initialState: Snapshot(baseline: nil, phase: .warmup)
    )

    private var baseline: (x: Double, y: Double)?
    private var phase: Phase = .warmup
    private var lastSample: (x: Double, y: Double, t: TimeInterval)?
    private var lastFire: TimeInterval = 0
    private var settleAccum: TimeInterval = 0

    private let onGesture: (HeadGesture) -> Void

    init(onGesture: @escaping (HeadGesture) -> Void) {
        self.onGesture = onGesture
    }

    var config: Config {
        get { configLock.withLock { $0 } }
        set { configLock.withLock { $0 = newValue } }
    }

    var snapshot: Snapshot {
        snapshotLock.withLock { $0 }
    }

    func update(_ mutate: (inout Config) -> Void) {
        configLock.withLock { mutate(&$0) }
    }

    func feed(x: Double, y: Double, timestamp t: TimeInterval) {
        let cfg = config

        let velocity = computeVelocity(x: x, y: y, t: t)
        defer {
            lastSample = (x, y, t)
            publishSnapshot()
        }

        guard let bl = baseline else {
            baseline = (x, y)
            phase = .rest
            return
        }

        let dx = x - bl.x
        let dy = y - bl.y
        let dist = (dx * dx + dy * dy).squareRoot()

        switch phase {
        case .warmup:
            phase = .rest

        case .rest:
            if dist < cfg.restRadius {
                // Track the neutral position with a slow EMA.
                baseline = (
                    bl.x + cfg.baselineAlpha * (x - bl.x),
                    bl.y + cfg.baselineAlpha * (y - bl.y)
                )
                settleAccum = 0
            } else if dist > cfg.triggerRadius
                        && velocity > cfg.velocityThreshold
                        && (t - lastFire) > cfg.cooldown {
                let gesture: HeadGesture = abs(dx) >= abs(dy)
                    ? (dx > 0 ? .right : .left)
                    : (dy > 0 ? .up : .down)
                lastFire = t
                phase = .cooling
                settleAccum = 0
                onGesture(gesture)
            }
            // else: dead zone — slow drift and small jitters are ignored.

        case .cooling:
            if dist < cfg.restRadius {
                phase = .rest
                settleAccum = 0
            } else if velocity < cfg.velocityThreshold * 0.3 {
                if let last = lastSample {
                    settleAccum += max(t - last.t, 0)
                }
                if settleAccum > cfg.settleTimeout {
                    // User has settled at a new neutral position — adopt it.
                    baseline = (x, y)
                    phase = .rest
                    settleAccum = 0
                }
            } else {
                settleAccum = 0
            }
        }
    }

    func resetBaseline() {
        baseline = nil
        phase = .warmup
        lastSample = nil
        settleAccum = 0
        publishSnapshot()
    }

    private func computeVelocity(x: Double, y: Double, t: TimeInterval) -> Double {
        guard let last = lastSample else { return 0 }
        let dt = max(t - last.t, 0.001)
        let vx = (x - last.x) / dt
        let vy = (y - last.y) / dt
        return (vx * vx + vy * vy).squareRoot()
    }

    private func publishSnapshot() {
        let bl = baseline.map { CGPoint(x: $0.x, y: $0.y) }
        snapshotLock.withLock {
            $0 = Snapshot(baseline: bl, phase: phase)
        }
    }
}
