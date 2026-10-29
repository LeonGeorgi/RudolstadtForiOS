import Foundation

/// Resolves timeline durations without running the optional optimizer.
enum FestivalDurationResolver {
    static func resolve(_ events: [Event]) -> [Event] {
        let durations = Dictionary(
            uniqueKeysWithValues: KotlinCore.bridge.durations(
                events: events.map { CoreEvent($0, forPlanning: false).core }
            ).map {
                (
                    Int($0.eventID),
                    FestivalEventDuration(
                        minutes: Int($0.duration.minutes), isEstimated: $0.duration.isEstimated)
                )
            })
        return events.map { event in
            guard event.duration == nil, let duration = durations[event.id] else { return event }
            return event.replacing(resolvedDuration: duration)
        }
    }
}
