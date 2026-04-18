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
        let sortedEvents = ev.sorted { e1, e2 in
            if e1.date != e2.date {
                return e1.date < e2.date
            }

            // If two events start at the same time, place the longer one first.
            // This keeps layout deterministic and prevents duplicate start slots
            // from pushing later events down in this stacked timeline model.
            let e1End = e1.endDate(
                durationInMinutes: dataStore.estimatedEventDurations?[e1.id] ?? 60
            )
            let e2End = e2.endDate(
                durationInMinutes: dataStore.estimatedEventDurations?[e2.id] ?? 60
            )
            if e1End != e2End {
                return e1End > e2End
            }

            return e1.id < e2.id
        }
        var lastTime = firstEventTime
        var result: [EventOrGap] = []
        for event: Event in sortedEvents {
            // If source data overlaps on the same stage, ignore entries that begin
            // inside an already occupied block. This avoids cascading drift for all
            // following events in the column.
            if event.date < lastTime {
                continue
            }

            if lastTime < event.date {
                result.append(
                    .gap(Gap(duration: event.date.timeIntervalSince(lastTime)))
                )
            }
            result.append(.event(event))
            let eventEnd = event.endDate(
                durationInMinutes: dataStore.estimatedEventDurations?[event.id]
                    ?? 60
            )
            // Keep timeline monotonic even with bad/overlapping source data.
            if eventEnd > lastTime {
                lastTime = eventEnd
            }
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
        ScrollableProgramViewContent(
            scrollOffset: .zero,
            timeIntervals: timeIntervalList,
            stages: stageList,
            estimatedEventDurations: dataStore.estimatedEventDurations
        )
        .safeAreaInset(edge: .bottom) {
            Text("schedule.endtimes.warning")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .scheduleWarningStyle()
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
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
private struct ScheduleWarningStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            content
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
}

private extension View {
    func scheduleWarningStyle() -> some View {
        modifier(ScheduleWarningStyle())
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
