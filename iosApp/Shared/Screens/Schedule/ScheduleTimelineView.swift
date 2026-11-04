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
    let events: [ScheduleTimelinePositionedEvent]

    init(id: FestivalPlaceID, stage: Stage, title: String, items: [EventOrGap]) {
        self.id = id
        self.stage = stage
        self.title = title
        var startHours: CGFloat = 0.25
        events = items.compactMap { item in
            switch item {
            case .event(let presentation):
                defer { startHours += CGFloat(presentation.duration) / 60 }
                return ScheduleTimelinePositionedEvent(
                    presentation: presentation, startHours: startHours)
            case .gap(let gap):
                startHours += CGFloat(gap.duration) / 3600
                return nil
            }
        }
    }
}

struct ScheduleTimelinePositionedEvent: Identifiable {
    let presentation: ScheduleTimelineEventPresentation
    let startHours: CGFloat

    var id: Int { presentation.event.id }

    func frame(
        columnIndex: Int, columnWidth: CGFloat, timeWidth: CGFloat,
        columnSpacing: CGFloat, heightPerHour: CGFloat
    ) -> CGRect {
        CGRect(
            x: timeWidth + columnSpacing + CGFloat(columnIndex) * (columnWidth + columnSpacing),
            y: startHours * heightPerHour,
            width: columnWidth,
            height: CGFloat(presentation.duration) / 60 * heightPerHour)
    }
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
