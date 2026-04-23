import AVFoundation
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class HeadController {
    enum Status: Equatable {
        case idle, requestingPermission, permissionDenied, running
        case error(String)
    }

    struct GestureEvent: Identifiable {
        let id = UUID()
        let gesture: HeadGesture
        let timestamp: Date
    }

    struct TrailPoint {
        let p: CGPoint
        let t: TimeInterval
    }

    /// Smoothed nose-tip position in normalized image coords (origin bottom-left).
    var nosePosition: CGPoint?
    /// Recent smoothed positions for the trajectory line (last ~0.6s).
    private(set) var nosePath: [TrailPoint] = []
    /// Latest detector snapshot for the baseline / phase visualization.
    private(set) var detectorSnapshot: GestureDetector.Snapshot = .init(baseline: nil, phase: .warmup)
    private(set) var recentGestures: [GestureEvent] = []
    var status: Status = .idle

    // View
    var previewEnabled: Bool = true

    // Detector tunables
    var triggerRadius: Double = 0.060
    var restRadius: Double = 0.022
    var velocityThreshold: Double = 0.25
    var cooldown: TimeInterval = 0.35

    // Smoothing
    var smoothingAlpha: Double = 0.5

    // Bindings
    var preset: BindingPreset = .spaces
    private(set) var mappings: [HeadGesture: KeyAction] = BindingPreset.spaces.mappings ?? [:]
    var injectKeys: Bool = false
    private(set) var accessibilityTrusted: Bool = KeyInjector.isAccessibilityTrusted()
    /// Why the last gesture did or didn't trigger an injection — surfaced in the UI for debugging.
    private(set) var lastInjectStatus: String = "—"

    private(set) var cameraSession: CameraSession!
    private var tracker: FaceLandmarkTracker!
    private var detector: GestureDetector!
    private let smoother = Smoother()
    private let injector = KeyInjector()

    private let trailWindow: TimeInterval = 0.6

    init() {
        let smoother = self.smoother

        cameraSession = CameraSession { [weak self] buffer in
            self?.tracker?.process(buffer)
        }
        tracker = FaceLandmarkTracker { [weak self] x, y, t in
            let (sx, sy) = smoother.step(x: x, y: y)
            self?.detector?.feed(x: sx, y: sy, timestamp: t)
            Task { @MainActor [weak self] in
                self?.recordNose(x: sx, y: sy, timestamp: t)
            }
        }
        detector = GestureDetector { [weak self] gesture in
            Task { @MainActor [weak self] in
                self?.recordGesture(gesture)
            }
        }
        syncDetectorConfig()
        smoother.alpha = smoothingAlpha
        startAccessibilityWatch()
    }

    func start() async {
        guard status != .running else { return }
        status = .requestingPermission

        guard await CameraSession.requestPermission() else {
            status = .permissionDenied
            return
        }

        do {
            try cameraSession.configure()
            cameraSession.start()
            status = .running
        } catch {
            status = .error(String(describing: error))
        }
    }

    func stop() {
        cameraSession.stop()
        status = .idle
    }

    // MARK: - Detector tunable setters

    func setTriggerRadius(_ v: Double) {
        triggerRadius = v
        detector.update { $0.triggerRadius = v }
    }

    func setRestRadius(_ v: Double) {
        restRadius = v
        detector.update { $0.restRadius = v }
    }

    func setVelocityThreshold(_ v: Double) {
        velocityThreshold = v
        detector.update { $0.velocityThreshold = v }
    }

    func setCooldown(_ v: TimeInterval) {
        cooldown = v
        detector.update { $0.cooldown = v }
    }

    func setSmoothingAlpha(_ v: Double) {
        smoothingAlpha = v
        smoother.alpha = v
    }

    func resetBaseline() {
        detector.resetBaseline()
        smoother.reset()
    }

    private func syncDetectorConfig() {
        detector.update {
            $0.triggerRadius = triggerRadius
            $0.restRadius = restRadius
            $0.velocityThreshold = velocityThreshold
            $0.cooldown = cooldown
        }
    }

    // MARK: - Bindings

    func setPreset(_ p: BindingPreset) {
        preset = p
        if let m = p.mappings { mappings = m }
    }

    func setMapping(_ action: KeyAction, for gesture: HeadGesture) {
        mappings[gesture] = action
        preset = .custom
    }

    // MARK: - Accessibility

    private func startAccessibilityWatch() {
        Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.accessibilityTrusted = KeyInjector.isAccessibilityTrusted()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Internal

    private func recordNose(x: Double, y: Double, timestamp: TimeInterval) {
        let p = CGPoint(x: x, y: y)
        nosePosition = p
        nosePath.append(TrailPoint(p: p, t: timestamp))
        while let first = nosePath.first, timestamp - first.t > trailWindow {
            nosePath.removeFirst()
        }
        detectorSnapshot = detector.snapshot
    }

    private func recordGesture(_ gesture: HeadGesture) {
        recentGestures.insert(GestureEvent(gesture: gesture, timestamp: Date()), at: 0)
        if recentGestures.count > 12 {
            recentGestures.removeLast(recentGestures.count - 12)
        }
        lastInjectStatus = attemptInject(for: gesture)
    }

    @discardableResult
    private func attemptInject(for gesture: HeadGesture) -> String {
        guard injectKeys else {
            return "\(gesture.rawValue): blocked — toggle off"
        }
        guard accessibilityTrusted else {
            return "\(gesture.rawValue): blocked — no Accessibility"
        }
        guard let action = mappings[gesture], action != .none else {
            return "\(gesture.rawValue): blocked — no mapping"
        }
        injector.inject(action)
        return "\(gesture.rawValue) → \(action.label)"
    }

    /// Manually fire the action mapped to `.right` — for verifying the injection
    /// chain without having to swing your head.
    func testInject() {
        lastInjectStatus = "test " + attemptInject(for: .right)
    }
}
