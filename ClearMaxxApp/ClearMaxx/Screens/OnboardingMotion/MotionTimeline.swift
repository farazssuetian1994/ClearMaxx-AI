//
//  MotionTimeline.swift
//  ClearMaxx — the clock and keyframe maths behind the onboarding motion graphics.
//
//  Every onboarding hero is a pure function of one number: `t`, its position in
//  a looping 6-second timeline (0 ..< 1). All the time-based maths lives here,
//  free of SwiftUI, so the choreography is unit-testable and any single frame
//  can be rendered on demand (previews, Reduce Motion).
//

import Foundation

enum MotionTimeline {
    /// Every onboarding hero loops on the same beat.
    static let loopDuration: TimeInterval = 6

    /// Position in the loop, `0 ..< 1`, after `elapsed` seconds. A clock read
    /// from just before a restart (zero or negative elapsed) is the loop start.
    static func progress(elapsed: TimeInterval, duration: TimeInterval = loopDuration) -> Double {
        guard duration > 0, elapsed > 0 else { return 0 }
        return elapsed.truncatingRemainder(dividingBy: duration) / duration
    }

    /// 0 before `from`, 1 after `to`, a straight line between.
    static func linear(_ t: Double, from: Double, to: Double) -> Double {
        guard to > from else { return t >= to ? 1 : 0 }
        return min(max((t - from) / (to - from), 0), 1)
    }

    /// 0 before `from`, 1 after `to`, eased in and out between (smoothstep).
    static func ramp(_ t: Double, from: Double, to: Double) -> Double {
        let x = linear(t, from: from, to: to)
        return x * x * (3 - 2 * x)
    }

    /// Fades in across `appear`, holds at 1, fades out across `disappear`.
    static func window(_ t: Double, appear: ClosedRange<Double>, disappear: ClosedRange<Double>) -> Double {
        ramp(t, from: appear.lowerBound, to: appear.upperBound)
            * (1 - ramp(t, from: disappear.lowerBound, to: disappear.upperBound))
    }

    static func lerp(_ a: Double, _ b: Double, _ x: Double) -> Double { a + (b - a) * x }

    /// Scale for a "pop": small before `from`, overshoots to `overshoot` at the
    /// midpoint, then settles on exactly 1 by `to`.
    static func pop(_ t: Double, from: Double, to: Double, overshoot: Double = 1.3) -> Double {
        let mid = (from + to) / 2
        if t < mid { return lerp(0.2, overshoot, ramp(t, from: from, to: mid)) }
        return lerp(overshoot, 1, ramp(t, from: mid, to: to))
    }

    /// Ease-out that runs slightly past 1 before settling: a springy arrival.
    static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        let u = x - 1
        return 1 + c3 * u * u * u + c1 * u * u
    }

    /// An integer counting from `start` to `end` across `range`.
    static func countUp(_ t: Double, from start: Int, to end: Int, over range: ClosedRange<Double>) -> Int {
        let x = ramp(t, from: range.lowerBound, to: range.upperBound)
        return start + Int((Double(end - start) * x).rounded())
    }

    /// Phase (0 ..< 1) of a shorter effect that repeats every `period` seconds
    /// inside the main loop, such as a pulse ring.
    static func subPhase(_ t: Double, period: TimeInterval) -> Double {
        let cycles = t * loopDuration / period
        return cycles - cycles.rounded(.down)
    }
}
