import Foundation
import os

/// Exponential moving average for 2D points.
/// `alpha` near 1.0 = light smoothing, near 0.0 = heavy smoothing.
final class Smoother {
    private struct State {
        var alpha: Double = 0.5
        var current: (x: Double, y: Double)?
    }

    private let state = OSAllocatedUnfairLock<State>(initialState: State())

    var alpha: Double {
        get { state.withLock { $0.alpha } }
        set { state.withLock { $0.alpha = newValue } }
    }

    func step(x: Double, y: Double) -> (Double, Double) {
        state.withLock { s in
            let a = s.alpha
            let next: (x: Double, y: Double)
            if let c = s.current {
                next = (c.x + a * (x - c.x), c.y + a * (y - c.y))
            } else {
                next = (x, y)
            }
            s.current = next
            return next
        }
    }

    func reset() {
        state.withLock { $0.current = nil }
    }
}
