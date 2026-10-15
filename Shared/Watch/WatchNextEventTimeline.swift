import Foundation

enum WatchWidgetKind {
    static let nextEvent = "RudolstadtNextEvent"
}

enum WatchNextEventPhase: Equatable, Sendable {
    case upcoming
    case ongoing
}

enum WatchPlanCompleteness: Equatable, Sendable {
    case complete
    case incomplete(missingSavedEventCount: Int)
    case unknown
}

enum WatchNextEventContent: Equatable, Sendable {
    case loading
    case unavailable(WatchSnapshotUnavailableReason)
    case programUnavailable
    case planUnavailable
    case noSavedEvents
    case planEnded
    case festivalEnded
    case event(WatchEventSnapshot, phase: WatchNextEventPhase)
}

struct WatchNextEventTimelineEntry: Equatable, Sendable {
    let date: Date
    let content: WatchNextEventContent
    let planCompleteness: WatchPlanCompleteness
    let isStale: Bool
    let isShowingRetainedSnapshotAfterFailedImport: Bool
    let snapshotRevision: UInt64?

    init(
        date: Date,
        content: WatchNextEventContent,
        planCompleteness: WatchPlanCompleteness = .unknown,
        isStale: Bool,
        isShowingRetainedSnapshotAfterFailedImport: Bool,
        snapshotRevision: UInt64?
    ) {
        self.date = date
        self.content = content
        self.planCompleteness = planCompleteness
        self.isStale = isStale
        self.isShowingRetainedSnapshotAfterFailedImport =
            isShowingRetainedSnapshotAfterFailedImport
        self.snapshotRevision = snapshotRevision
    }

    var event: WatchEventSnapshot? {
        guard case .event(let event, _) = content else {
            return nil
        }
        return event
    }
}

struct WatchNextEventTimelineProjection: Equatable, Sendable {
    let entries: [WatchNextEventTimelineEntry]
    let reloadAtEnd: Bool
}

struct WatchNextEventTimelineProjector: Sendable {
    private let freshnessPolicy: WatchSnapshotFreshnessPolicy
    private let maximumEntryCount: Int

    init(
        freshnessPolicy: WatchSnapshotFreshnessPolicy = WatchSnapshotFreshnessPolicy(),
        maximumEntryCount: Int = 64
    ) {
        self.freshnessPolicy = freshnessPolicy
        self.maximumEntryCount = max(2, maximumEntryCount)
    }

    func entry(
        for state: WatchSnapshotState,
        at date: Date
    ) -> WatchNextEventTimelineEntry {
        switch state.availability {
        case .loading:
            return WatchNextEventTimelineEntry(
                date: date,
                content: .loading,
                isStale: false,
                isShowingRetainedSnapshotAfterFailedImport: false,
                snapshotRevision: nil
            )
        case .unavailable(let reason):
            return WatchNextEventTimelineEntry(
                date: date,
                content: .unavailable(reason),
                isStale: false,
                isShowingRetainedSnapshotAfterFailedImport: false,
                snapshotRevision: nil
            )
        case .available, .stale:
            guard let snapshot = state.snapshot else {
                return WatchNextEventTimelineEntry(
                    date: date,
                    content: .unavailable(.noSnapshot),
                    isStale: false,
                    isShowingRetainedSnapshotAfterFailedImport: false,
                    snapshotRevision: nil
                )
            }
            return makeEntry(
                snapshot: snapshot,
                state: state,
                date: date
            )
        }
    }

    func project(
        state: WatchSnapshotState,
        now: Date
    ) -> WatchNextEventTimelineProjection {
        switch state.availability {
        case .loading, .unavailable:
            return WatchNextEventTimelineProjection(
                entries: [entry(for: state, at: now)],
                reloadAtEnd: false
            )
        case .available, .stale:
            break
        }
        guard let snapshot = state.snapshot else {
            return WatchNextEventTimelineProjection(
                entries: [entry(for: state, at: now)],
                reloadAtEnd: false
            )
        }

        let festivalEnd = snapshot.payload.events.map(\.endDate).max()
        let relevantFreshnessDates = freshnessBoundaryDates(
            snapshot: snapshot,
            after: now
        ).filter { date in
            festivalEnd.map { date <= $0 } ?? true
        }
        let boundaryDates = Set(
            [now]
                + eventBoundaryDates(snapshot: snapshot, after: now)
                + relevantFreshnessDates
        )
        .sorted()
        var semanticEntries = [WatchNextEventTimelineEntry]()
        for date in boundaryDates {
            let candidate = makeEntry(snapshot: snapshot, state: state, date: date)
            guard let previous = semanticEntries.last else {
                semanticEntries.append(candidate)
                continue
            }
            if previous.content != candidate.content
                || previous.isStale != candidate.isStale
                || previous.isShowingRetainedSnapshotAfterFailedImport
                    != candidate.isShowingRetainedSnapshotAfterFailedImport
            {
                semanticEntries.append(candidate)
                if semanticEntries.count > maximumEntryCount {
                    return WatchNextEventTimelineProjection(
                        entries: Array(
                            semanticEntries.prefix(maximumEntryCount)
                        ),
                        reloadAtEnd: true
                    )
                }
            }
        }
        return WatchNextEventTimelineProjection(
            entries: semanticEntries,
            reloadAtEnd: false
        )
    }

    private func makeEntry(
        snapshot: WatchSnapshotEnvelope,
        state: WatchSnapshotState,
        date: Date
    ) -> WatchNextEventTimelineEntry {
        WatchNextEventTimelineEntry(
            date: date,
            content: content(snapshot: snapshot, at: date),
            planCompleteness: snapshot.payload.planCompleteness,
            isStale: !freshnessPolicy.eventScheduleStaleReasons(
                for: snapshot,
                now: date
            ).isEmpty,
            isShowingRetainedSnapshotAfterFailedImport:
                state.isShowingRetainedSnapshotAfterFailedImport,
            snapshotRevision: snapshot.revision
        )
    }

    private func content(
        snapshot: WatchSnapshotEnvelope,
        at date: Date
    ) -> WatchNextEventContent {
        let allEvents = snapshot.payload.events
        guard !allEvents.isEmpty else {
            return .programUnavailable
        }
        if allEvents.allSatisfy({ $0.endDate <= date }) {
            return .festivalEnded
        }

        let savedEvents = allEvents.filter(\.isSaved)
        guard !savedEvents.isEmpty else {
            switch snapshot.payload.planCompleteness {
            case .complete:
                return .noSavedEvents
            case .incomplete, .unknown:
                return .planUnavailable
            }
        }

        let alreadyStarted = savedEvents.filter { $0.startDate <= date }
        if let latestStartDate = alreadyStarted.map(\.startDate).max(),
           let primaryStartedEvent = alreadyStarted
            .filter({ $0.startDate == latestStartDate })
            .sorted(by: eventPrecedes)
            .first,
           primaryStartedEvent.endDate > date
        {
            return .event(primaryStartedEvent, phase: .ongoing)
        }

        if let nextEvent = savedEvents
            .filter({ $0.startDate > date })
            .sorted(by: eventPrecedes)
            .first
        {
            return .event(nextEvent, phase: .upcoming)
        }
        return .planEnded
    }

    private func eventPrecedes(
        _ first: WatchEventSnapshot,
        _ second: WatchEventSnapshot
    ) -> Bool {
        if first.startDate != second.startDate {
            return first.startDate < second.startDate
        }
        if first.endDate != second.endDate {
            return first.endDate > second.endDate
        }
        return first.id < second.id
    }

    private func eventBoundaryDates(
        snapshot: WatchSnapshotEnvelope,
        after now: Date
    ) -> [Date] {
        let savedBoundaries = snapshot.payload.events
            .filter(\.isSaved)
            .flatMap { [$0.startDate, $0.endDate] }
            .filter { $0 > now }
        let festivalEnd = snapshot.payload.events
            .map(\.endDate)
            .max()
            .flatMap { $0 > now ? $0 : nil }
        return savedBoundaries + [festivalEnd].compactMap { $0 }
    }

    private func freshnessBoundaryDates(
        snapshot: WatchSnapshotEnvelope,
        after now: Date
    ) -> [Date] {
        var dates = [Date]()

        switch snapshot.freshness.festivalDataSource {
        case .remote, .cache:
            appendFreshnessBoundaries(
                timestamp: snapshot.freshness.festivalDataUpdatedAt,
                maximumAge: freshnessPolicy.maximumFestivalDataAge,
                after: now,
                to: &dates
            )
        case .staleCache, .bundledBackup:
            break
        }

        appendFreshnessBoundaries(
            timestamp: snapshot.generatedAt,
            maximumAge: freshnessPolicy.maximumSnapshotAge,
            after: now,
            to: &dates
        )
        return dates
    }

    private func appendFreshnessBoundaries(
        timestamp: Date?,
        maximumAge: TimeInterval,
        after now: Date,
        to dates: inout [Date]
    ) {
        guard let timestamp else {
            return
        }
        let futureTimestampBecomesValid = timestamp.addingTimeInterval(
            -freshnessPolicy.maximumClockSkew
        )
        if futureTimestampBecomesValid > now {
            dates.append(futureTimestampBecomesValid)
        }

        // The freshness policy uses a strict `>` comparison. Scheduling one
        // second later makes the projected state match that policy exactly.
        let becomesTooOld = timestamp
            .addingTimeInterval(maximumAge)
            .addingTimeInterval(1)
        if becomesTooOld > now {
            dates.append(becomesTooOld)
        }
    }
}

struct WatchDayPlanEvent: Equatable, Identifiable, Sendable {
    let event: WatchEventSnapshot
    let phase: WatchNextEventPhase
    let conflictMinutes: Int?
    let incomingTransition: WatchPlanTransitionSnapshot?
    let friendSaveCount: Int?

    var id: Int {
        event.id
    }
}

struct WatchDayPlan: Equatable, Sendable {
    let festivalDay: Int
    let displayDate: Date
    let ongoingEvents: [WatchDayPlanEvent]
    let upcomingEvents: [WatchDayPlanEvent]

    var events: [WatchDayPlanEvent] {
        ongoingEvents + upcomingEvents
    }
}

enum WatchDayPlanContent: Equatable, Sendable {
    case loading
    case unavailable(WatchSnapshotUnavailableReason)
    case programUnavailable
    case planUnavailable
    case noSavedEvents
    case noFestivalToday
    case noSavedEventsToday
    case planEnded
    case festivalEnded
    case plan(WatchDayPlan)

    var plan: WatchDayPlan? {
        guard case .plan(let plan) = self else {
            return nil
        }
        return plan
    }
}

struct WatchDayPlanProjection: Equatable, Sendable {
    let content: WatchDayPlanContent
    let planCompleteness: WatchPlanCompleteness
    let isStale: Bool
    let isShowingRetainedSnapshotAfterFailedImport: Bool
    let snapshotRevision: UInt64?
}

struct WatchDayPlanProjector: Sendable {
    private let freshnessPolicy: WatchSnapshotFreshnessPolicy
    private let calendar: Calendar

    init(
        freshnessPolicy: WatchSnapshotFreshnessPolicy = WatchSnapshotFreshnessPolicy(),
        calendar: Calendar? = nil
    ) {
        self.freshnessPolicy = freshnessPolicy
        if let calendar {
            self.calendar = calendar
        } else {
            var festivalCalendar = Calendar(identifier: .gregorian)
            festivalCalendar.timeZone = FestivalConfiguration.timeZone
            self.calendar = festivalCalendar
        }
    }

    func project(
        state: WatchSnapshotState,
        at date: Date
    ) -> WatchDayPlanProjection {
        switch state.availability {
        case .loading:
            return WatchDayPlanProjection(
                content: .loading,
                planCompleteness: .unknown,
                isStale: false,
                isShowingRetainedSnapshotAfterFailedImport: false,
                snapshotRevision: nil
            )
        case .unavailable(let reason):
            return WatchDayPlanProjection(
                content: .unavailable(reason),
                planCompleteness: .unknown,
                isStale: false,
                isShowingRetainedSnapshotAfterFailedImport: false,
                snapshotRevision: nil
            )
        case .available, .stale:
            guard let snapshot = state.snapshot else {
                return WatchDayPlanProjection(
                    content: .unavailable(.noSnapshot),
                    planCompleteness: .unknown,
                    isStale: false,
                    isShowingRetainedSnapshotAfterFailedImport: false,
                    snapshotRevision: nil
                )
            }
            return WatchDayPlanProjection(
                content: content(snapshot: snapshot, at: date),
                planCompleteness: snapshot.payload.planCompleteness,
                isStale: !freshnessPolicy.eventScheduleStaleReasons(
                    for: snapshot,
                    now: date
                ).isEmpty,
                isShowingRetainedSnapshotAfterFailedImport:
                    state.isShowingRetainedSnapshotAfterFailedImport,
                snapshotRevision: snapshot.revision
            )
        }
    }

    private func content(
        snapshot: WatchSnapshotEnvelope,
        at date: Date
    ) -> WatchDayPlanContent {
        let allEvents = snapshot.payload.events
        guard !allEvents.isEmpty else {
            return .programUnavailable
        }
        if allEvents.allSatisfy({ $0.endDate <= date }) {
            return .festivalEnded
        }

        let savedEvents = allEvents
            .filter(\.isSaved)
            .sorted(by: eventPrecedes)
        guard !savedEvents.isEmpty else {
            switch snapshot.payload.planCompleteness {
            case .complete:
                return .noSavedEvents
            case .incomplete, .unknown:
                return .planUnavailable
            }
        }

        guard let festivalDay = currentFestivalDay(
            eventDays: Set(allEvents.map(\.festivalDay)),
            festivalYear: snapshot.festivalYear,
            at: date
        ) else {
            return .noFestivalToday
        }
        let dayEvents = savedEvents.filter {
            $0.festivalDay == festivalDay
        }
        guard !dayEvents.isEmpty else {
            return .noSavedEventsToday
        }

        let ongoingEvents = dayEvents.filter {
            $0.startDate <= date && $0.endDate > date
        }
        let futureEvents = dayEvents.filter { $0.startDate > date }
        guard !ongoingEvents.isEmpty || !futureEvents.isEmpty else {
            return .planEnded
        }

        let upcomingEvents = futureEvents
        let visibleEvents = ongoingEvents + upcomingEvents
        let visibleEventIDs = Set(visibleEvents.map(\.id))
        let transitionSourceEventIDs = Set(dayEvents.map(\.id))
        let showsFriendCounts = friendCountsAreFresh(
            in: snapshot,
            at: date
        )

        let plan = WatchDayPlan(
            festivalDay: festivalDay,
            displayDate: displayDate(
                festivalDay: festivalDay,
                festivalYear: snapshot.festivalYear,
                fallback: visibleEvents.first?.startDate ?? date
            ),
            ongoingEvents: ongoingEvents.map {
                makePlanEvent(
                    event: $0,
                    phase: .ongoing,
                    payload: snapshot.payload,
                    visibleEventIDs: visibleEventIDs,
                    transitionSourceEventIDs: transitionSourceEventIDs,
                    friendCountsAreFresh: showsFriendCounts
                )
            },
            upcomingEvents: upcomingEvents.map {
                makePlanEvent(
                    event: $0,
                    phase: .upcoming,
                    payload: snapshot.payload,
                    visibleEventIDs: visibleEventIDs,
                    transitionSourceEventIDs: transitionSourceEventIDs,
                    friendCountsAreFresh: showsFriendCounts
                )
            }
        )
        return .plan(plan)
    }

    private func makePlanEvent(
        event: WatchEventSnapshot,
        phase: WatchNextEventPhase,
        payload: WatchFestivalSnapshot,
        visibleEventIDs: Set<Int>,
        transitionSourceEventIDs: Set<Int>,
        friendCountsAreFresh: Bool
    ) -> WatchDayPlanEvent {
        let conflictMinutes = payload.planOverlaps.compactMap { overlap -> Int? in
            let otherEventID: Int
            if overlap.firstEventID == event.id {
                otherEventID = overlap.secondEventID
            } else if overlap.secondEventID == event.id {
                otherEventID = overlap.firstEventID
            } else {
                return nil
            }
            return visibleEventIDs.contains(otherEventID)
                ? overlap.overlapMinutes
                : nil
        }.max()
        let incomingTransition = payload.planTransitions
            .filter {
                $0.toEventID == event.id
                    && transitionSourceEventIDs.contains($0.fromEventID)
                    && $0.status != .comfortable
            }
            .sorted(by: transitionPrecedes)
            .first
        let friendSaveCount = friendCountsAreFresh
            ? event.friendSaveCount.flatMap { $0 > 0 ? $0 : nil }
            : nil

        return WatchDayPlanEvent(
            event: event,
            phase: phase,
            conflictMinutes: conflictMinutes,
            incomingTransition: incomingTransition,
            friendSaveCount: friendSaveCount
        )
    }

    private func friendCountsAreFresh(
        in snapshot: WatchSnapshotEnvelope,
        at date: Date
    ) -> Bool {
        guard snapshot.payload.friends.state == .available,
              let updatedAt = snapshot.payload.friends.updatedAt
        else {
            return false
        }
        let age = date.timeIntervalSince(updatedAt)
        let snapshotAge = date.timeIntervalSince(snapshot.generatedAt)
        return age >= -freshnessPolicy.maximumClockSkew
            && age <= freshnessPolicy.maximumFriendDataAge
            && snapshotAge >= -freshnessPolicy.maximumClockSkew
            && snapshotAge <= freshnessPolicy.maximumSnapshotAge
    }

    private func currentFestivalDay(
        eventDays: Set<Int>,
        festivalYear: Int,
        at date: Date
    ) -> Int? {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour],
            from: date
        )
        guard components.year == festivalYear,
              components.month == 7,
              let day = components.day,
              let hour = components.hour
        else {
            return nil
        }
        let festivalDay = hour < 5 ? day - 1 : day
        return eventDays.contains(festivalDay) ? festivalDay : nil
    }

    private func displayDate(
        festivalDay: Int,
        festivalYear: Int,
        fallback: Date
    ) -> Date {
        calendar.date(from: DateComponents(
            year: festivalYear,
            month: 7,
            day: festivalDay,
            hour: 12
        )) ?? fallback
    }

    private func eventPrecedes(
        _ first: WatchEventSnapshot,
        _ second: WatchEventSnapshot
    ) -> Bool {
        if first.startDate != second.startDate {
            return first.startDate < second.startDate
        }
        if first.endDate != second.endDate {
            return first.endDate > second.endDate
        }
        return first.id < second.id
    }

    private func transitionPrecedes(
        _ first: WatchPlanTransitionSnapshot,
        _ second: WatchPlanTransitionSnapshot
    ) -> Bool {
        let firstPriority = transitionPriority(first.status)
        let secondPriority = transitionPriority(second.status)
        if firstPriority != secondPriority {
            return firstPriority < secondPriority
        }
        return first.fromEventID < second.fromEventID
    }

    private func transitionPriority(
        _ status: WatchPlanTransitionStatus
    ) -> Int {
        switch status {
        case .impossible:
            return 0
        case .tight:
            return 1
        case .unknown:
            return 2
        case .comfortable:
            return 3
        }
    }
}

private extension WatchFestivalSnapshot {
    var planCompleteness: WatchPlanCompleteness {
        guard let missingSavedEventCount else {
            return .unknown
        }
        return missingSavedEventCount == 0
            ? .complete
            : .incomplete(missingSavedEventCount: missingSavedEventCount)
    }
}

struct WatchEventDeepLink: Equatable, Sendable {
    let festivalYear: Int
    let eventID: Int
}

enum WatchDeepLink {
    static let scheme = "rudolstadt-watch"

    static func eventURL(
        festivalYear: Int,
        eventID: Int
    ) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "event"
        components.path = "/\(festivalYear)/\(eventID)"
        return components.url
    }

    static func event(from url: URL) -> WatchEventDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme,
              components.host?.lowercased() == "event"
        else {
            return nil
        }
        let pathComponents = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
        guard pathComponents.count == 2,
              let festivalYear = Int(pathComponents[0]),
              let eventID = Int(pathComponents[1])
        else {
            return nil
        }
        return WatchEventDeepLink(
            festivalYear: festivalYear,
            eventID: eventID
        )
    }
}

extension WatchEventSnapshot {
    func localizedStageName(locale: Locale) -> String {
        let prefersGerman = locale.language.languageCode?.identifier == "de"
        let preferredName = (prefersGerman ? stageNameGerman : stageNameEnglish)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = (prefersGerman ? stageNameEnglish : stageNameGerman)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return preferredName.isEmpty ? fallbackName : preferredName
    }
}
