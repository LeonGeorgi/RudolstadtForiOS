import Foundation

/// Resolves timeline durations without running the optional optimizer.
enum FestivalDurationResolver {
    static func resolve(_ events: [Event]) -> [Event] {
        var durations = [Int: FestivalEventDuration]()
        let groups = Dictionary(grouping: events.filter { $0.startDate != nil && $0.placeID != nil }) {
            $0.placeID
        }
        for group in groups.values {
            let ordered = group.sorted {
                if $0.startDate != $1.startDate { return ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
                return $0.id > $1.id
            }
            var next: Event?
            for event in ordered {
                defer { next = event }
                if let duration = event.duration, duration.minutes > 0 {
                    durations[event.id] = duration
                    continue
                }
                var minutes = 60
                if let nextStart = next?.startDate, let start = event.startDate {
                    let gap = nextStart.timeIntervalSince(start) / 60
                    if gap > 0 {
                        let rounded = floor(gap / 30) * 30
                        let half = floor(gap / 2 / 30) * 30
                        let estimate = rounded < 30 ? gap
                            : rounded < 60 ? rounded
                            : half < 30 ? gap / 2
                            : half <= 90 ? half : gap > 300 ? 60 : 90
                        minutes = gap < 60 ? Int(gap) : max(60, Int(estimate))
                    }
                }
                if minutes > 0 {
                    durations[event.id] = FestivalEventDuration(minutes: minutes, isEstimated: true)
                }
            }
        }
        return events.map {
            var event = $0
            event.resolvedDuration = event.duration ?? durations[event.id]
            return event
        }
    }
}
