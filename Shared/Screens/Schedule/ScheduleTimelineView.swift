import SwiftUI

struct Gap {
    let duration: Double
}
enum EventOrGap {
    case event(Event)
    case gap(Gap)
}

struct ScheduleTimelineView: View {
    let events: [Event]
    @Environment(\.festivalData) private var festivalData
    @State private var isShowingEndTimeInformation = false

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
            Stage.precedes(s1.0, s2.0)
        }
    }

    private func generateEventGapList(ev: [Event]) -> [EventOrGap] {
        let sortedEvents = ev.sorted { e1, e2 in
            guard let firstDate = e1.startDate, let secondDate = e2.startDate else {
                return Event.precedes(e1, e2)
            }
            if firstDate != secondDate { return firstDate < secondDate }

            // If two events start at the same time, place the longer one first.
            // This keeps layout deterministic and prevents duplicate start slots
            // from pushing later events down in this stacked timeline model.
            let e1End = e1.endDate(
                durationInMinutes: festivalData.eventDurations[e1.id] ?? 60
            )
            let e2End = e2.endDate(
                durationInMinutes: festivalData.eventDurations[e2.id] ?? 60
            )
            if let e1End, let e2End, e1End != e2End { return e1End > e2End }

            return e1.id < e2.id
        }
        var lastTime = firstEventTime
        var result: [EventOrGap] = []
        for event: Event in sortedEvents {
            guard let startDate = event.startDate else { continue }
            // If source data overlaps on the same stage, ignore entries that begin
            // inside an already occupied block. This avoids cascading drift for all
            // following events in the column.
            if startDate < lastTime {
                continue
            }

            if lastTime < startDate {
                result.append(
                    .gap(Gap(duration: startDate.timeIntervalSince(lastTime)))
                )
            }
            result.append(.event(event))
            let eventEnd = event.endDate(
                durationInMinutes: festivalData.eventDurations[event.id]
                    ?? 60
            )
            // Keep timeline monotonic even with bad/overlapping source data.
            if let eventEnd, eventEnd > lastTime { lastTime = eventEnd }
        }
        return result

    }

    private var firstEventTime: Date { events.compactMap(\.startDate).min() ?? .distantPast }

    private var lastEventEndTime: Date {
        events.compactMap {
            $0.endDate(
                durationInMinutes:
                    festivalData.eventDurations[$0.id] ?? 60)
        }.max() ?? firstEventTime
    }

    var body: some View {
        ScheduleTimelineContentView(
            timeIntervals: timeIntervalList,
            stages: stageList,
            estimatedEventDurations: festivalData.eventDurations,
            onShowEndTimeInformation: {
                isShowingEndTimeInformation = true
            }
        )
        .alert("schedule.endtimes.notice", isPresented: $isShowingEndTimeInformation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("schedule.endtimes.warning")
        }
    }

    func generateHalfHourlyDates(startDate: Date, endDate: Date) -> [Date] {
        let calendar = festivalData.metadata?.calendar ?? FestivalDateUtilities.festivalCalendar

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

#if DEBUG
struct ScheduleTimelineView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            ScheduleTimelineView(
                events: PreviewMockData.festivalData.events.filter { event in
                    event.festivalDay == 4
                }
            )
            .navigationDestination(for: AppNavigationRoute.self) { _ in
                EmptyView()
            }
        }
        .previewMockEnvironment(suiteName: "ScheduleTimelineViewPreview")
    }
}
#endif
