#if os(iOS)
import SwiftUI

enum FriendArtistRatingsMotion {
    private static let badgeDuration: TimeInterval = 0.30
    private static let stagger: TimeInterval = 0.05
    private static let counterDelay = 3 * stagger
    private static let fullDuration = badgeDuration + counterDelay
    private static let splitStart = counterDelay + 0.08
    private static let splitFadeDuration = 0.065

    static func duration(forFriendCount count: Int) -> TimeInterval {
        let badgeCount = min(max(count, 1), 4)
        return badgeDuration + Double(badgeCount - 1) * stagger
    }

    struct Flight: Equatable {
        let start: ContinuousClock.Instant
        let from: TimeInterval
        let to: TimeInterval

        var deadline: ContinuousClock.Instant {
            start.advanced(by: .seconds(abs(to - from)))
        }

        func playhead(at now: ContinuousClock.Instant) -> TimeInterval {
            if now >= deadline { return to }
            let elapsed = max(0, start.duration(to: now) / .seconds(1))
            return to > from ? from + elapsed : from - elapsed
        }
    }

    static func badgeProgress(at playhead: TimeInterval, index: Int) -> Double {
        let start = Double(index) * stagger
        return reveal((playhead - start) / badgeDuration)
    }

    static func counter(at playhead: TimeInterval) -> (progress: Double, opacity: Double) {
        (
            flightProgress(at: playhead, delay: counterDelay, duration: fullDuration),
            1 - reveal((playhead - splitStart) / splitFadeDuration)
        )
    }

    static func fan(at playhead: TimeInterval, index: Int, count: Int) -> (spread: Double, opacity: Double) {
        // Fit larger visible groups into the same interval as the four-avatar preview.
        let delay = 0.09 * Double(index) / Double(max(count - 1, 3))
        let start = splitStart + delay
        return (
            flightProgress(at: playhead, delay: start, duration: fullDuration),
            reveal((playhead - start) / splitFadeDuration)
        )
    }

    private static func flightProgress(at playhead: TimeInterval, delay: TimeInterval, duration: TimeInterval) -> Double {
        reveal((playhead - delay) / (duration - delay))
    }

    static func controlPoint(from start: CGPoint, to referenceTarget: CGPoint, targetHeights: [CGFloat]) -> CGPoint {
        let top = targetHeights.min() ?? referenceTarget.y
        let bottom = targetHeights.max() ?? referenceTarget.y
        return CGPoint(
            x: referenceTarget.x + (start.x - referenceTarget.x) * 0.33,
            y: (top + bottom) / 2
        )
    }

    static func point(from start: CGPoint, to end: CGPoint, control: CGPoint, progress: Double) -> CGPoint {
        let t = progress
        let u = 1 - t
        return CGPoint(
            x: u*u*start.x + 2*u*t*control.x + t*t*end.x,
            y: u*u*start.y + 2*u*t*control.y + t*t*end.y
        )
    }

    static func reveal(_ progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        return t*t*(3 - 2*t)
    }
}
#endif
