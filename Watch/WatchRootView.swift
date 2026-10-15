import SwiftUI

struct WatchRootView: View {
    @ObservedObject var receiver: WatchSnapshotReceiver

    @State private var navigationPath = [Int]()
    @State private var pendingDeepLink: WatchEventDeepLink?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                WatchPlanView(
                    projection: WatchDayPlanProjector().project(
                        state: receiver.state,
                        at: context.date
                    ),
                    state: receiver.state
                )
            }
            .navigationTitle("watch.title")
            .navigationDestination(for: Int.self) { eventID in
                eventDestination(eventID: eventID)
            }
        }
        .environment(\.timeZone, FestivalConfiguration.timeZone)
        .onOpenURL(perform: receiveDeepLink)
        .onChange(of: receiver.state) {
            routePendingDeepLinkIfPresent()
        }
        .task(id: pendingDeepLink) {
            guard let pendingDeepLink else {
                return
            }
            await receiver.refreshFreshness()
            guard !Task.isCancelled else {
                return
            }
            finishRoutingDeepLink(pendingDeepLink)
        }
    }

    @ViewBuilder
    private func eventDestination(eventID: Int) -> some View {
        if let event = receiver.state.snapshot?.payload.events.first(
            where: { $0.id == eventID }
        ) {
            WatchEventDetailView(
                event: event,
                planEvent: currentPlanEvent(eventID: eventID),
                isStale: isCurrentSnapshotStale
            )
        } else {
            WatchEventUnavailableView()
        }
    }

    private var isCurrentSnapshotStale: Bool {
        currentPlanProjection.isStale
    }

    private var currentPlanProjection: WatchDayPlanProjection {
        WatchDayPlanProjector().project(
            state: receiver.state,
            at: .now
        )
    }

    private func currentPlanEvent(eventID: Int) -> WatchDayPlanEvent? {
        guard case .plan(let plan) = currentPlanProjection.content else {
            return nil
        }
        return plan.events.first { $0.id == eventID }
    }

    private func receiveDeepLink(_ url: URL) {
        guard let deepLink = WatchDeepLink.event(from: url),
              deepLink.festivalYear == FestivalConfiguration.year
        else {
            pendingDeepLink = nil
            navigationPath.removeAll()
            return
        }
        pendingDeepLink = deepLink
        routePendingDeepLinkIfPresent()
    }

    private func routePendingDeepLinkIfPresent() {
        guard let pendingDeepLink else {
            return
        }
        guard receiver.state.snapshot?.payload.events.contains(
            where: { $0.id == pendingDeepLink.eventID }
        ) == true else {
            return
        }
        self.pendingDeepLink = nil
        navigationPath = [pendingDeepLink.eventID]
    }

    private func finishRoutingDeepLink(_ deepLink: WatchEventDeepLink) {
        guard pendingDeepLink == deepLink else {
            return
        }
        routePendingDeepLinkIfPresent()
        if pendingDeepLink == deepLink {
            pendingDeepLink = nil
            navigationPath.removeAll()
        }
    }
}

private struct WatchPlanView: View {
    let projection: WatchDayPlanProjection
    let state: WatchSnapshotState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                dataWarnings

                switch projection.content {
                case .loading:
                    WatchSnapshotStatusView(state: state)
                case .unavailable:
                    WatchSnapshotStatusView(state: state)
                case .programUnavailable:
                    WatchEmptyStateView(
                        title: "watch.program.unavailable",
                        detail: "watch.program.unavailable.detail",
                        systemImage: "calendar.badge.exclamationmark"
                    )
                case .planUnavailable:
                    WatchEmptyStateView(
                        title: planUnavailableTitle,
                        detail: planUnavailableDetail,
                        systemImage: "calendar.badge.exclamationmark"
                    )
                case .noSavedEvents:
                    WatchEmptyStateView(
                        title: "watch.plan.empty",
                        detail: "watch.plan.empty.detail",
                        systemImage: "bookmark.slash"
                    )
                case .noFestivalToday:
                    WatchEmptyStateView(
                        title: "watch.festival.not_today",
                        detail: "watch.festival.not_today.detail",
                        systemImage: "calendar"
                    )
                case .noSavedEventsToday:
                    WatchEmptyStateView(
                        title: "watch.plan.empty_today",
                        detail: "watch.plan.empty_today.detail",
                        systemImage: "bookmark.slash"
                    )
                case .planEnded:
                    WatchEmptyStateView(
                        title: "watch.plan.finished",
                        detail: "watch.plan.finished.detail",
                        systemImage: "calendar.badge.checkmark"
                    )
                case .festivalEnded:
                    WatchEmptyStateView(
                        title: "watch.festival.finished",
                        detail: "watch.festival.finished.detail",
                        systemImage: "checkmark.circle"
                    )
                case .plan(let plan):
                    dayPlanContent(plan)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var dataWarnings: some View {
        if projection.isStale {
            WatchDataWarning(
                title: "watch.stale",
                systemImage: "clock.badge.exclamationmark"
            )
        }
        if hasIncompatibleImport {
            WatchDataWarning(
                title: "watch.incompatible.received",
                systemImage: "exclamationmark.triangle"
            )
        }
        if projection.isShowingRetainedSnapshotAfterFailedImport {
            WatchDataWarning(
                title: "watch.update.failed",
                systemImage: "arrow.triangle.2.circlepath"
            )
        }
        switch projection.planCompleteness {
        case .complete:
            EmptyView()
        case .incomplete where !isShowingPlanUnavailable:
            WatchDataWarning(
                title: "watch.plan.incomplete",
                systemImage: "calendar.badge.exclamationmark"
            )
        case .unknown where snapshotContainsSavedEvents:
            WatchDataWarning(
                title: "watch.plan.completeness.unknown",
                systemImage: "questionmark.circle"
            )
        case .incomplete, .unknown:
            EmptyView()
        }
    }

    private func dayPlanContent(_ plan: WatchDayPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("watch.plan.title")
                    .font(.headline)
                Text(
                    plan.displayDate,
                    format: .dateTime.weekday(.wide).day().month()
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !plan.ongoingEvents.isEmpty {
                planSection(
                    title: "watch.now",
                    systemImage: "waveform",
                    tint: .green,
                    events: plan.ongoingEvents
                )
            }
            if !plan.upcomingEvents.isEmpty {
                planSection(
                    title: "watch.next",
                    systemImage: "clock",
                    tint: .secondary,
                    events: plan.upcomingEvents
                )
            }
        }
    }

    private func planSection(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        events: [WatchDayPlanEvent]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            .font(.caption)
            .foregroundStyle(tint)

            ForEach(events) { event in
                NavigationLink(value: event.id) {
                    WatchPlanEventRow(planEvent: event)
                }
                .buttonStyle(.plain)

                if event.id != events.last?.id {
                    Divider()
                }
            }
        }
    }

    private var isShowingPlanUnavailable: Bool {
        if case .planUnavailable = projection.content {
            return true
        }
        return false
    }

    private var planUnavailableTitle: LocalizedStringKey {
        switch projection.planCompleteness {
        case .unknown:
            return "watch.plan.completeness.unknown"
        case .complete, .incomplete:
            return "watch.plan.incomplete"
        }
    }

    private var planUnavailableDetail: LocalizedStringKey {
        switch projection.planCompleteness {
        case .unknown:
            return "watch.plan.completeness.unknown.detail"
        case .complete, .incomplete:
            return "watch.plan.incomplete.detail"
        }
    }

    private var snapshotContainsSavedEvents: Bool {
        state.snapshot?.payload.events.contains(where: \.isSaved) == true
    }

    private var hasIncompatibleImport: Bool {
        switch state.importDiagnostic {
        case .incompatibleSchema, .wrongFestivalYear, .disallowedEnvironment:
            return true
        case .none, .payloadTooLarge, .corrupt, .invalidPayload,
             .storageReadFailure, .persistenceFailure:
            return false
        }
    }
}

private struct WatchPlanEventRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    let planEvent: WatchDayPlanEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            rowLayout {
                Text(planEvent.event.startDate, style: .time)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(
                        planEvent.phase == .ongoing ? .green : .primary
                    )

                VStack(alignment: .leading, spacing: 3) {
                    WatchPlanText.artist(for: planEvent.event)
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    Label {
                        WatchPlanText.stage(
                            for: planEvent.event,
                            locale: locale
                        )
                    } icon: {
                        Image(systemName: "music.note.house")
                            .accessibilityHidden(true)
                    }
                    .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Label {
                    Text("watch.saved")
                } icon: {
                    Image(systemName: "bookmark.fill")
                        .accessibilityHidden(true)
                }

                if let friendSaveCount = planEvent.friendSaveCount {
                    Label {
                        WatchPlanText.friendCount(friendSaveCount)
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .accessibilityHidden(true)
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            WatchPlanFactsView(planEvent: planEvent)
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("watch.event.open")
    }

    private var rowLayout: AnyLayout {
        if dynamicTypeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
        }
        return AnyLayout(HStackLayout(alignment: .top, spacing: 8))
    }

    private var accessibilityLabel: Text {
        Text(planEvent.event.startDate, style: .time)
            + Text(verbatim: ", ")
            + WatchPlanText.artist(for: planEvent.event)
            + Text(verbatim: ", ")
            + WatchPlanText.stage(for: planEvent.event, locale: locale)
    }

    private var accessibilityValue: Text {
        var value = Text("watch.saved")
        if let conflict = WatchPlanText.conflict(for: planEvent) {
            value = value + Text(verbatim: ", ") + conflict
        }
        if let transition = WatchPlanText.transition(
            for: planEvent,
            suppressOverlapRedundancy: false
        ) {
            value = value + Text(verbatim: ", ") + transition
        }
        if let friendSaveCount = planEvent.friendSaveCount {
            value = value
                + Text(verbatim: ", ")
                + WatchPlanText.friendCount(friendSaveCount)
        }
        return value
    }
}

private struct WatchPlanFactsView: View {
    let planEvent: WatchDayPlanEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let conflict = WatchPlanText.conflict(for: planEvent) {
                Label {
                    conflict
                } icon: {
                    Image(systemName: "rectangle.2.swap")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.red)
            }
            if let transition = WatchPlanText.transition(for: planEvent) {
                Label {
                    transition
                } icon: {
                    Image(systemName: "figure.walk")
                        .accessibilityHidden(true)
                }
                .foregroundStyle(transitionColor)
            }
        }
        .font(.caption2)
    }

    private var transitionColor: Color {
        switch planEvent.incomingTransition?.status {
        case .impossible:
            return .red
        case .tight:
            return .orange
        case .unknown, .comfortable, .none:
            return .secondary
        }
    }
}

private struct WatchDataWarning: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(.yellow)
    }
}

private enum WatchPlanText {
    static func artist(for event: WatchEventSnapshot) -> Text {
        let artistName = event.artistName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return artistName.isEmpty
            ? Text("watch.event")
            : Text(verbatim: artistName)
    }

    static func stage(
        for event: WatchEventSnapshot,
        locale: Locale
    ) -> Text {
        if let stageNumber = event.stageNumber {
            let format = NSLocalizedString(
                "watch.stage.number.format",
                comment: "Festival stage number"
            )
            return Text(verbatim: String.localizedStringWithFormat(
                format,
                stageNumber
            ))
        }
        let stageName = event.localizedStageName(locale: locale)
        return stageName.isEmpty
            ? Text("watch.stage")
            : Text(verbatim: stageName)
    }

    static func friendCount(_ count: Int) -> Text {
        Text(verbatim: "\(count) ")
            + (count == 1 ? Text("watch.friend") : Text("watch.friends"))
    }

    static func detailedStage(
        for event: WatchEventSnapshot,
        locale: Locale
    ) -> Text {
        var text = stage(for: event, locale: locale)
        let stageName = event.localizedStageName(locale: locale)
        if event.stageNumber != nil, !stageName.isEmpty {
            text = text + Text(verbatim: " · \(stageName)")
        }
        return text
    }

    static func conflict(for planEvent: WatchDayPlanEvent) -> Text? {
        guard let conflictMinutes = planEvent.conflictMinutes else {
            return nil
        }
        return Text("watch.conflict")
            + Text(verbatim: " · ")
            + Text("watch.approximately")
            + Text(verbatim: " \(conflictMinutes) ")
            + Text("watch.minutes.overlap")
    }

    static func transition(
        for planEvent: WatchDayPlanEvent,
        suppressOverlapRedundancy: Bool = true
    ) -> Text? {
        guard let transition = planEvent.incomingTransition else {
            return nil
        }
        if suppressOverlapRedundancy,
           planEvent.conflictMinutes != nil,
           transition.status == .impossible
        {
            return nil
        }

        switch transition.status {
        case .comfortable:
            return nil
        case .tight:
            var text = Text("watch.transition.tight")
            if let walkingMinutes = transition.walkingMinutes {
                text = text
                    + Text(verbatim: " · ")
                    + walkingTime(
                        minutes: walkingMinutes,
                        certainty: transition.certainty
                    )
            }
            return text
        case .impossible:
            var text = Text("watch.transition.impossible")
            if let latenessMinutes = transition.projectedLatenessMinutes {
                text = text
                    + Text(verbatim: " · ")
                    + Text("watch.approximately")
                    + Text(verbatim: " \(latenessMinutes) ")
                    + Text("watch.minutes.late")
            }
            return text
        case .unknown:
            return Text("watch.transition.unknown")
        }
    }

    private static func walkingTime(
        minutes: Int,
        certainty: WatchTransferCertainty
    ) -> Text {
        var text = Text("watch.approximately")
            + Text(verbatim: " \(minutes) ")
            + Text("watch.minutes.walk")
        if certainty == .estimated {
            text = text
                + Text(verbatim: " (")
                + Text("watch.estimated")
                + Text(verbatim: ")")
        }
        return text
    }
}

private struct WatchEventDetailView: View {
    @Environment(\.locale) private var locale

    let event: WatchEventSnapshot
    let planEvent: WatchDayPlanEvent?
    let isStale: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if isStale {
                    WatchDataWarning(
                        title: "watch.stale",
                        systemImage: "clock.badge.exclamationmark"
                    )
                }

                Label {
                    Text(event.startDate, style: .date)
                    Text(verbatim: " · ")
                    Text(event.startDate, style: .time)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "calendar")
                        .accessibilityHidden(true)
                }

                WatchPlanText.artist(for: event)
                    .font(.headline)

                Label {
                    WatchPlanText.detailedStage(for: event, locale: locale)
                } icon: {
                    Image(systemName: "music.note.house")
                        .accessibilityHidden(true)
                }

                Label {
                    if event.isSaved {
                        Text("watch.saved")
                    } else {
                        Text("watch.not_saved")
                    }
                } icon: {
                    Image(systemName: event.isSaved ? "bookmark.fill" : "bookmark.slash")
                        .accessibilityHidden(true)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                if let planEvent {
                    if let friendSaveCount = planEvent.friendSaveCount {
                        Label {
                            WatchPlanText.friendCount(friendSaveCount)
                        } icon: {
                            Image(systemName: "person.2.fill")
                                .accessibilityHidden(true)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    WatchPlanFactsView(planEvent: planEvent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("watch.event")
    }
}

private struct WatchEventUnavailableView: View {
    var body: some View {
        WatchEmptyStateView(
            title: "watch.event.unavailable",
            detail: "watch.event.unavailable.detail",
            systemImage: "calendar.badge.exclamationmark"
        )
        .navigationTitle("watch.event")
    }
}

private struct WatchEmptyStateView: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct WatchSnapshotStatusView: View {
    let state: WatchSnapshotState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch state.availability {
            case .loading:
                ProgressView()
                Text("watch.loading")
                    .foregroundStyle(.secondary)
            case .available:
                Label("watch.ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .stale:
                Label(
                    "watch.stale",
                    systemImage: "clock.badge.exclamationmark"
                )
                .foregroundStyle(.yellow)
            case .unavailable(let reason):
                Label(
                    unavailableTitle(for: reason),
                    systemImage: unavailableSymbol(for: reason)
                )
                .foregroundStyle(.secondary)
                Text(unavailableDetail(for: reason))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func unavailableTitle(
        for reason: WatchSnapshotUnavailableReason
    ) -> LocalizedStringKey {
        switch reason {
        case .incompatibleStoredSchema, .wrongStoredFestivalYear,
             .disallowedStoredEnvironment:
            return "watch.incompatible"
        case .noSnapshot, .corruptStoredSnapshot, .invalidIncomingSnapshot,
             .readFailure, .persistenceFailure:
            return "watch.unavailable"
        }
    }

    private func unavailableDetail(
        for reason: WatchSnapshotUnavailableReason
    ) -> LocalizedStringKey {
        switch reason {
        case .incompatibleStoredSchema, .wrongStoredFestivalYear,
             .disallowedStoredEnvironment:
            return "watch.incompatible.detail"
        case .noSnapshot:
            return "watch.unavailable.detail"
        case .invalidIncomingSnapshot:
            return "watch.transfer.detail"
        case .corruptStoredSnapshot, .readFailure, .persistenceFailure:
            return "watch.storage.detail"
        }
    }

    private func unavailableSymbol(
        for reason: WatchSnapshotUnavailableReason
    ) -> String {
        switch reason {
        case .incompatibleStoredSchema, .wrongStoredFestivalYear,
             .disallowedStoredEnvironment:
            return "exclamationmark.triangle"
        case .noSnapshot, .corruptStoredSnapshot, .invalidIncomingSnapshot,
             .readFailure, .persistenceFailure:
            return "iphone.and.arrow.forward"
        }
    }
}

#Preview {
    WatchSnapshotStatusView(
        state: WatchSnapshotState(
            snapshot: nil,
            availability: .unavailable(.noSnapshot),
            importDiagnostic: nil
        )
    )
}
