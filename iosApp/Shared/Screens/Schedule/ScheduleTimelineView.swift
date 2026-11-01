import RudolstadtCore
import SwiftUI

struct Gap {
    let duration: Double
}
enum EventOrGap {
    case event(ScheduleTimelineEventPresentation)
    case gap(Gap)
}

struct ScheduleTimelineStagePresentation: Identifiable {
    let id: FestivalPlaceID
    let stage: Stage
    let title: String
    let items: [EventOrGap]
}

struct ScheduleTimelineView: View {
    let events: [Event]
    @Binding var selectedDay: String?
    @Environment(\.festivalData) private var festivalData
    @State private var isShowingEndTimeInformation = false

    var body: some View {
        let days = ProgramTimeline.shared.buildDays(
            events: events, days: festivalData.days.map(\.core),
            durations: festivalData.eventDurations.coreMinutes,
            zone: (festivalData.metadata?.calendar ?? FestivalDateUtilities.festivalCalendar)
                .timeZone.identifier,
            placePrecedes: { KotlinBoolean(bool: Stage.precedes($0, $1)) })
        ScheduleTimelineContentView(
            days: days, selectedDay: $selectedDay,
            estimatedEventDurations: festivalData.eventDurations,
            onShowEndTimeInformation: { isShowingEndTimeInformation = true }
        )
        .alert("schedule.endtimes.notice", isPresented: $isShowingEndTimeInformation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("schedule.endtimes.warning")
        }
    }
}

extension Dictionary where Key == Int, Value == Int {
    var coreMinutes: [EventMinutes] {
        map { EventMinutes(eventID: Int64($0.key), minutes: Int32($0.value)) }
    }
}
extension ProgramTimelineData {
    var nativeTicks: [Date] { ticks.map { Date(timeIntervalSince1970: $0.doubleValue) } }
    func nativeColumns(
        locale: Locale, prepareEvent: (Event) -> ScheduleTimelineEventPresentation
    ) -> [ScheduleTimelineStagePresentation] {
        columns.map { column in
            ScheduleTimelineStagePresentation(
                id: column.place.id, stage: column.place,
                title: column.place.localizedName(locale: locale),
                items: column.items.map { item in
                    item.event.map { .event(prepareEvent($0)) }
                        ?? .gap(Gap(duration: item.gapSeconds))
                }
            )
        }
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            ScheduleTimelineView(
                events: PreviewMockData.festivalData.events, selectedDay: .constant(nil))
        }
        .previewMockEnvironment(suiteName: "ScheduleTimelineViewPreview")
    }
#endif
