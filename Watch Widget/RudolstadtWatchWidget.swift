import SwiftUI
import WidgetKit

private struct NextEventWidgetEntry: TimelineEntry {
    let date: Date
    let projection: WatchNextEventTimelineEntry
}

private struct NextEventProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextEventWidgetEntry {
        NextEventWidgetEntry(
            date: .now,
            projection: WatchNextEventTimelineEntry(
                date: .now,
                content: .loading,
                isStale: false,
                isShowingRetainedSnapshotAfterFailedImport: false,
                snapshotRevision: nil
            )
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (NextEventWidgetEntry) -> Void
    ) {
        guard !context.isPreview else {
            completion(Self.previewEntry(date: .now))
            return
        }
        loadProjection { projection in
            completion(Self.firstEntry(in: projection))
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<NextEventWidgetEntry>) -> Void
    ) {
        loadProjection { projection in
            let entries = projection.entries.map { entry in
                NextEventWidgetEntry(date: entry.date, projection: entry)
            }
            completion(Timeline(
                entries: entries,
                policy: projection.reloadAtEnd ? .atEnd : .never
            ))
        }
    }

    private func loadProjection(
        completion: @escaping (WatchNextEventTimelineProjection) -> Void
    ) {
        let completion = UncheckedTimelineCompletion(completion)
        Task {
            let now = Date.now
            let repository = WatchSnapshotRepository.live(
                expectedFestivalYear: FestivalConfiguration.year
            )
            let state = await repository.load(now: now)
            let projection = WatchNextEventTimelineProjector().project(
                state: state,
                now: now
            )
            completion.call(projection)
        }
    }

    private static func firstEntry(
        in projection: WatchNextEventTimelineProjection
    ) -> NextEventWidgetEntry {
        guard let entry = projection.entries.first else {
            let date = Date.now
            return NextEventWidgetEntry(
                date: date,
                projection: WatchNextEventTimelineEntry(
                    date: date,
                    content: .loading,
                    isStale: false,
                    isShowingRetainedSnapshotAfterFailedImport: false,
                    snapshotRevision: nil
                )
            )
        }
        return NextEventWidgetEntry(date: entry.date, projection: entry)
    }

    private static func previewEntry(date: Date) -> NextEventWidgetEntry {
        let startDate = date.addingTimeInterval(45 * 60)
        let event = WatchEventSnapshot(
            id: 1,
            artistID: 1,
            artistName: "Rudolstadt",
            stageID: 1,
            stageNumber: 1,
            stageNameGerman: "Große Bühne",
            stageNameEnglish: "Main Stage",
            festivalDay: 3,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(60 * 60),
            isSaved: true,
            hasPositiveRating: false,
            recommendationRank: nil,
            friendSaveCount: nil
        )
        return NextEventWidgetEntry(
            date: date,
            projection: WatchNextEventTimelineEntry(
                date: date,
                content: .event(event, phase: .upcoming),
                planCompleteness: .complete,
                isStale: false,
                isShowingRetainedSnapshotAfterFailedImport: false,
                snapshotRevision: nil
            )
        )
    }
}

private struct NextEventWidgetView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.locale) private var locale
    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetFamily) private var family

    let entry: NextEventWidgetEntry

    var body: some View {
        Group {
            if entry.projection.event != nil
                && redactionReasons.contains(.privacy)
            {
                privateEventContent
                    .unredacted()
            } else {
                content
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .environment(\.timeZone, FestivalConfiguration.timeZone)
        .widgetURL(deepLinkURL)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityStatus)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.projection.content {
        case .loading:
            statusContent(
                title: "widget.loading",
                systemImage: "arrow.triangle.2.circlepath"
            )
        case .unavailable(let reason):
            statusContent(
                title: unavailableTitle(for: reason),
                systemImage: unavailableSymbol(for: reason)
            )
        case .programUnavailable:
            statusContent(
                title: "widget.program.unavailable",
                systemImage: statusSymbol(
                    default: "calendar.badge.exclamationmark"
                )
            )
        case .planUnavailable:
            statusContent(
                title: "widget.plan.unavailable",
                systemImage: statusSymbol(
                    default: "calendar.badge.exclamationmark"
                )
            )
        case .noSavedEvents:
            statusContent(
                title: "widget.no.plan",
                systemImage: statusSymbol(default: "bookmark.slash")
            )
        case .planEnded:
            statusContent(
                title: "widget.plan.finished",
                systemImage: statusSymbol(default: "calendar.badge.checkmark")
            )
        case .festivalEnded:
            statusContent(
                title: "widget.festival.finished",
                systemImage: "checkmark.circle"
            )
        case .event(let event, let phase):
            eventContent(event: event, phase: phase)
                .privacySensitive()
        }
    }

    @ViewBuilder
    private func eventContent(
        event: WatchEventSnapshot,
        phase: WatchNextEventPhase
    ) -> some View {
        switch family {
        case .accessoryInline:
            inlineEventContent(event: event, phase: phase)
        case .accessoryCircular:
            circularEventContent(event: event, phase: phase)
        case .accessoryRectangular:
            rectangularEventContent(event: event, phase: phase)
        default:
            rectangularEventContent(event: event, phase: phase)
        }
    }

    private func inlineEventContent(
        event: WatchEventSnapshot,
        phase: WatchNextEventPhase
    ) -> some View {
        HStack(spacing: 3) {
            if needsAttention {
                Image(systemName: attentionSymbol)
                    .accessibilityHidden(true)
            }
            switch phase {
            case .upcoming:
                Text(event.startDate, style: .time)
            case .ongoing:
                Text("widget.ongoing")
            }
            Text(verbatim: "·")
            artistText(for: event)
                .lineLimit(1)
        }
    }

    private func circularEventContent(
        event: WatchEventSnapshot,
        phase: WatchNextEventPhase
    ) -> some View {
        VStack(spacing: 0) {
            Image(systemName: needsAttention ? attentionSymbol : "music.note")
                .font(.caption2)
                .widgetAccentable()
                .accessibilityHidden(true)
            switch phase {
            case .upcoming:
                if isLuminanceReduced {
                    Text(event.startDate, style: .time)
                } else {
                    Text(event.startDate, style: .timer)
                        .monospacedDigit()
                }
            case .ongoing:
                Text("widget.ongoing")
            }
            if let stageNumber = event.stageNumber {
                Text(verbatim: "#\(stageNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func rectangularEventContent(
        event: WatchEventSnapshot,
        phase: WatchNextEventPhase
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                artistText(for: event)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 2)
                if needsAttention {
                    Image(systemName: attentionSymbol)
                        .font(.caption2)
                        .widgetAccentable()
                        .accessibilityHidden(true)
                }
            }
            HStack(spacing: 4) {
                stageText(for: event)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(event.startDate, style: .time)
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            switch phase {
            case .upcoming:
                if isLuminanceReduced {
                    Label("widget.next", systemImage: "clock")
                } else {
                    Label {
                        Text(event.startDate, style: .relative)
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
            case .ongoing:
                Label("widget.ongoing", systemImage: "waveform")
            }
        }
        .font(.caption2)
    }

    @ViewBuilder
    private var privateEventContent: some View {
        switch family {
        case .accessoryInline:
            Label("widget.private", systemImage: "lock.fill")
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "lock.fill")
                    .widgetAccentable()
                Image(systemName: "music.note")
                    .font(.caption2)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 3) {
                Label("widget.private", systemImage: "lock.fill")
                    .font(.headline)
                Text("widget.private.detail")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        default:
            Label("widget.private", systemImage: "lock.fill")
        }
    }

    @ViewBuilder
    private func statusContent(
        title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: systemImage)
                .font(.title3)
                .widgetAccentable()
                .accessibilityLabel(title)
        case .accessoryRectangular:
            Label(title, systemImage: systemImage)
                .font(.headline)
                .lineLimit(2)
        default:
            Label(title, systemImage: systemImage)
        }
    }

    private func stageText(for event: WatchEventSnapshot) -> Text {
        if let stageNumber = event.stageNumber {
            return Text("watch.stage") + Text(verbatim: " \(stageNumber)")
        }
        let stageName = event.localizedStageName(locale: locale)
        return stageName.isEmpty
            ? Text("watch.stage")
            : Text(verbatim: stageName)
    }

    private func artistText(for event: WatchEventSnapshot) -> Text {
        let artistName = event.artistName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return artistName.isEmpty
            ? Text("watch.event")
            : Text(verbatim: artistName)
    }

    private var needsAttention: Bool {
        entry.projection.isStale || planCompletenessStatus != nil
    }

    private var attentionSymbol: String {
        if entry.projection.isStale {
            return "clock.badge.exclamationmark"
        }
        switch entry.projection.planCompleteness {
        case .incomplete:
            return "calendar.badge.exclamationmark"
        case .unknown:
            return "questionmark.circle"
        case .complete:
            return "music.note"
        }
    }

    private var accessibilityStatus: Text {
        if entry.projection.isStale {
            if let planCompletenessStatus {
                return Text("widget.stale")
                    + Text(verbatim: ", ")
                    + Text(planCompletenessStatus)
            }
            return Text("widget.stale")
        }
        if let planCompletenessStatus {
            return Text(planCompletenessStatus)
        }
        return Text(verbatim: "")
    }

    private var planCompletenessStatus: LocalizedStringKey? {
        guard entry.projection.event != nil else {
            return nil
        }
        switch entry.projection.planCompleteness {
        case .complete:
            return nil
        case .incomplete:
            return "widget.plan.incomplete"
        case .unknown:
            return "widget.plan.unknown"
        }
    }

    private func statusSymbol(default defaultSymbol: String) -> String {
        entry.projection.isStale
            ? "clock.badge.exclamationmark"
            : defaultSymbol
    }

    private var deepLinkURL: URL? {
        guard let event = entry.projection.event else {
            return nil
        }
        return WatchDeepLink.eventURL(
            festivalYear: FestivalConfiguration.year,
            eventID: event.id
        )
    }

    private func unavailableTitle(
        for reason: WatchSnapshotUnavailableReason
    ) -> LocalizedStringKey {
        switch reason {
        case .incompatibleStoredSchema, .wrongStoredFestivalYear,
             .disallowedStoredEnvironment:
            return "widget.incompatible"
        case .noSnapshot, .corruptStoredSnapshot, .readFailure,
             .invalidIncomingSnapshot, .persistenceFailure:
            return "widget.unavailable"
        }
    }

    private func unavailableSymbol(
        for reason: WatchSnapshotUnavailableReason
    ) -> String {
        switch reason {
        case .incompatibleStoredSchema, .wrongStoredFestivalYear,
             .disallowedStoredEnvironment:
            return "exclamationmark.triangle"
        case .noSnapshot, .corruptStoredSnapshot, .readFailure,
             .invalidIncomingSnapshot, .persistenceFailure:
            return "iphone.and.arrow.forward"
        }
    }
}

private struct UncheckedTimelineCompletion<Value>: @unchecked Sendable {
    let call: (Value) -> Void

    init(_ call: @escaping (Value) -> Void) {
        self.call = call
    }
}

struct RudolstadtNextEventWidget: Widget {
    let kind = WatchWidgetKind.nextEvent

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: NextEventProvider()
        ) { entry in
            NextEventWidgetView(entry: entry)
        }
        .configurationDisplayName("widget.name")
        .description("widget.description")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

@main
struct RudolstadtWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        RudolstadtNextEventWidget()
    }
}
