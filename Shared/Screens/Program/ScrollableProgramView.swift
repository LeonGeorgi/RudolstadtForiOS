import SwiftUI

struct Gap {
    let duration: Double
}
enum EventOrGap {
    case event(Event)
    case gap(Gap)
}

struct ScrollableProgramView: View {
    let events: [Event]
    @EnvironmentObject var dataStore: DataStore

    var eventDays: [Int] {
        Set(
            events.lazy.map { (event: Event) in
                event.festivalDay
            }
        ).sorted(by: <)
    }

    private var timeIntervalList: [Date] {
        let startTime = firstEventTime
        let endTime = lastEventEndTime
        return generateHalfHourlyDates(startDate: startTime, endDate: endTime)
    }

    private var stageList: [(Stage, [EventOrGap])] {
        let d = Dictionary(grouping: events) { event in
            event.stage
        }
        return d.map { entry in
            (entry.key, generateEventGapList(ev: entry.value))
        }.sorted { s1, s2 in
            s1.0.stageNumber ?? 1000 < s2.0.stageNumber ?? 1000
        }
    }

    private func generateEventGapList(ev: [Event]) -> [EventOrGap] {
        var lastTime = firstEventTime
        var result: [EventOrGap] = []
        for event: Event in ev {
            if lastTime < event.date {
                result.append(
                    .gap(Gap(duration: event.date.timeIntervalSince(lastTime)))
                )
            }
            result.append(.event(event))
            lastTime = event.endDate(
                durationInMinutes: dataStore.estimatedEventDurations?[event.id]
                    ?? 60
            )
        }
        return result

    }

    private var firstEventTime: Date {
        let firstEvent =
            events.min { e1, e2 in
                e1.date < e2.date
            }?.date ?? Date()
        return firstEvent
    }

    private var lastEventEndTime: Date {
        let lastEvent = events.max { e1, e2 in
            e1.endDate(
                durationInMinutes: dataStore.estimatedEventDurations?[e1.id]
                    ?? 60
            )
                < e2.endDate(
                    durationInMinutes: dataStore.estimatedEventDurations?[e2.id]
                        ?? 60
                )
        }
        guard let lastEvent = lastEvent else {
            return Date()
        }
        let lastEventEndDate = lastEvent.endDate(
            durationInMinutes: dataStore.estimatedEventDurations?[lastEvent.id]
                ?? 60
        )
        return lastEventEndDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            ScrollableProgramViewContent(
                scrollOffset: .zero,
                timeIntervals: timeIntervalList,
                stages: stageList,
                estimatedEventDurations: dataStore.estimatedEventDurations
            )

            VStack {
                Text("schedule.endtimes.warning")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                    .padding(.bottom, 2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    func generateHalfHourlyDates(startDate: Date, endDate: Date) -> [Date] {
        let calendar = Calendar.current

        // Runde das Startdatum auf die nächste halbe oder ganze Stunde ab
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: startDate
        )
        let hour = startComponents.hour!
        let minute = startComponents.minute!
        let roundedMinute = (minute / 30) * 30
        let roundedStartDate = calendar.date(
            from: DateComponents(
                year: startComponents.year,
                month: startComponents.month,
                day: startComponents.day,
                hour: hour,
                minute: roundedMinute
            )
        )!

        // Erstelle eine Liste von Daten in halbstündigen Schritten
        var dates: [Date] = []
        var currentDate = roundedStartDate

        while currentDate < endDate {
            dates.append(currentDate)
            currentDate = currentDate.addingTimeInterval(30 * 60)
        }

        // Füge das erste Datum nach dem Enddatum hinzu
        dates.append(currentDate)
        return dates
    }
}
private let dayOfWeekFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM. EEEE"
    return formatter
}()

struct ScrollableProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollableProgramView(events: [Event.example])
    }
}
