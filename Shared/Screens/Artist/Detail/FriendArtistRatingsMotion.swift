#if os(iOS)
import SwiftUI

/// The approved chain simulation, sampled once rather than integrated on every frame.
enum FriendArtistRatingsMotion {
    static let sampleDuration = 0.1 / 2.6
    static let duration = sampleDuration * Double(opening.count - 1)

    struct Values {
        var first = 0.0
        var second = 0.0
        var third = 0.0
        var reveal = 0.0

        static let expanded = Values(first: 1, second: 1, third: 1, reveal: 1)

        subscript(index: Int) -> Double {
            [first, second, third][min(max(index, 0), 2)]
        }
    }

    struct Frames: Keyframes {
        let opening: Bool
        let initial: Values

        var body: some Keyframes<Values> {
            KeyframeTrack(\.first) { track(index: 0, from: initial.first) }
            KeyframeTrack(\.second) { track(index: 1, from: initial.second) }
            KeyframeTrack(\.third) { track(index: 2, from: initial.third) }
            KeyframeTrack(\.reveal) {
                CubicKeyframe(opening ? 1 : 0, duration: opening ? 0.13 : 0.18)
            }
        }

        @KeyframeTrackContentBuilder<Double>
        private func track(index: Int, from initial: Double) -> some KeyframeTrackContent<Double> {
            for sample in (opening ? FriendArtistRatingsMotion.opening : closing).dropFirst() {
                CubicKeyframe(
                    opening ? initial + (1 - initial) * sample[index] : initial * sample[index],
                    duration: sampleDuration
                )
            }
        }
    }

    static func point(from start: CGPoint, to end: CGPoint, index: Int, progress: Double) -> CGPoint {
        let index = min(max(index, 0), 2)
        let distance = start.x - end.x
        let scale = min(max(abs(distance) / 250, 0.6), 1.5)
        let first = CGPoint(
            x: start.x - distance * (0.256 + Double(index) * 0.017),
            y: start.y + (36 + Double(index) * 12) * scale
        )
        let second = CGPoint(
            x: end.x + distance * 0.34,
            y: end.y + [110.0, 90, 0][index] * scale
        )
        let t = progress, u = 1 - t
        return CGPoint(
            x: u*u*u*start.x + 3*u*u*t*first.x + 3*u*t*t*second.x + t*t*t*end.x,
            y: u*u*u*start.y + 3*u*u*t*first.y + 3*u*t*t*second.y + t*t*t*end.y
        )
    }

    static func reveal(_ progress: Double) -> Double {
        let t = min(max(progress, 0), 1)
        return t*t*(3 - 2*t)
    }

    static func openingValue(at elapsed: TimeInterval) -> Values {
        let timeline = KeyframeTimeline(initialValue: Values()) {
            Frames(opening: true, initial: .init())
        }
        return timeline.value(time: min(max(elapsed, 0), timeline.duration))
    }

    private static let opening: [[Double]] = [
        [0, 0, 0],
        [0.01522, 0.0034, 0.0006],
        [0.09878, 0.04405, 0.01655],
        [0.23643, 0.14201, 0.07996],
        [0.40255, 0.2735, 0.19068],
        [0.58844, 0.421, 0.32305],
        [0.77663, 0.58696, 0.46447],
        [0.91446, 0.77115, 0.61926],
        [0.98416, 0.92033, 0.78305],
        [1.00085, 0.98786, 0.91943],
        [1.00105, 1.00367, 0.98922],
        [1.00024, 1.00325, 1.0046],
        [1.00001, 1.0011, 1.00341],
        [0.99999, 1.00014, 1.00111],
        [0.99999, 0.99995, 1.00012],
        [1, 0.99996, 0.9999],
        [1, 0.99999, 0.99993],
        [1, 1, 0.99998],
        [1, 1, 1],
        [1, 1, 1],
        [1, 1, 1],
    ]

    private static let closing: [[Double]] = [
        [1, 1, 1],
        [0.99972, 0.99792, 0.98477],
        [0.99211, 0.97092, 0.89791],
        [0.95803, 0.88683, 0.75169],
        [0.87857, 0.73308, 0.58337],
        [0.73674, 0.54828, 0.4131],
        [0.5438, 0.36987, 0.25241],
        [0.34872, 0.20992, 0.11486],
        [0.18054, 0.08317, 0.02372],
        [0.06161, 0.01251, -0.00105],
        [0.00609, -0.00415, -0.00111],
        [-0.00435, -0.00312, -0.00024],
        [-0.0028, -0.00099, 0],
        [-0.00084, -0.0001, 0.00003],
        [-0.00006, 0.00008, 0.00001],
        [0.0001, 0.00006, 0],
        [0.00006, 0.00002, 0],
        [0.00002, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
    ]
}
#endif
