import Foundation
import RudolstadtCore

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
        self.freshnessPolicy = freshnessPolicy; self.maximumEntryCount = maximumEntryCount
    }
    func entry(for state: WatchSnapshotState, at date: Date) -> WatchNextEventTimelineEntry {
        guard let snapshot = state.projectionSnapshot else {
            return WatchNextEventTimelineEntry(
                date: date,
                content: state.availability == .loading
                    ? .loading : .unavailable(state.projectionFailure),
                isStale: false, isShowingRetainedSnapshotAfterFailedImport: false,
                snapshotRevision: nil)
        }
        return PersonalPlan.shared.next(
            input: snapshot.corePlan, now: date.timeIntervalSince1970,
            policy: freshnessPolicy.core
        ).native(snapshot: snapshot, state: state)
    }
    func project(state: WatchSnapshotState, now: Date) -> WatchNextEventTimelineProjection {
        guard let snapshot = state.projectionSnapshot else {
            return WatchNextEventTimelineProjection(
                entries: [entry(for: state, at: now)], reloadAtEnd: false)
        }
        let result = PersonalPlan.shared.timeline(
            input: snapshot.corePlan, now: now.timeIntervalSince1970,
            policy: freshnessPolicy.core, maximumEntries: Int32(clamping: maximumEntryCount))
        return WatchNextEventTimelineProjection(
            entries: result.entries.map { $0.native(snapshot: snapshot, state: state) },
            reloadAtEnd: result.reloadAtEnd)
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
        var festivalCalendar = Calendar(identifier: .gregorian)
        festivalCalendar.timeZone = FestivalConfiguration.timeZone
        self.calendar = calendar ?? festivalCalendar
    }
    func project(state: WatchSnapshotState, at date: Date) -> WatchDayPlanProjection {
        guard let snapshot = state.projectionSnapshot else {
            return WatchDayPlanProjection(
                content: state.availability == .loading
                    ? .loading : .unavailable(state.projectionFailure),
                planCompleteness: .unknown, isStale: false,
                isShowingRetainedSnapshotAfterFailedImport: false, snapshotRevision: nil)
        }
        let result = PersonalPlan.shared.day(
            input: snapshot.corePlan, now: date.timeIntervalSince1970,
            zone: calendar.timeZone.identifier, policy: freshnessPolicy.core)
        let content: WatchDayPlanContent
        switch result.kind {
        case "plan":
            let rows = result.rows.compactMap { row -> WatchDayPlanEvent? in
                guard
                    let event = snapshot.payload.events.first(where: { Int64($0.id) == row.eventID }
                    )
                else { return nil }
                return WatchDayPlanEvent(
                    event: event, phase: row.ongoing ? .ongoing : .upcoming,
                    conflictMinutes: row.conflictMinutes.map { Int($0.int32Value) },
                    incomingTransition: row.incomingTransitionIndex.map {
                        snapshot.payload.planTransitions[Int($0.int32Value)]
                    },
                    friendSaveCount: row.friendSaveCount.map { Int($0.int32Value) })
            }
            content = .plan(
                WatchDayPlan(
                    festivalDay: Int(result.day?.int32Value ?? 0),
                    displayDate: result.displayDate.map {
                        Date(timeIntervalSince1970: $0.doubleValue)
                    } ?? date,
                    ongoingEvents: rows.filter { $0.phase == .ongoing },
                    upcomingEvents: rows.filter { $0.phase == .upcoming }))
        case "programUnavailable": content = .programUnavailable
        case "planUnavailable": content = .planUnavailable
        case "noSavedEvents": content = .noSavedEvents
        case "noFestivalToday": content = .noFestivalToday
        case "noSavedEventsToday": content = .noSavedEventsToday
        case "planEnded": content = .planEnded
        case "festivalEnded": content = .festivalEnded
        default: content = .programUnavailable
        }
        return WatchDayPlanProjection(
            content: content, planCompleteness: snapshot.payload.planCompleteness,
            isStale: result.stale,
            isShowingRetainedSnapshotAfterFailedImport: state
                .isShowingRetainedSnapshotAfterFailedImport,
            snapshotRevision: snapshot.revision)
    }
}

private extension NextPlanEntry {
    func native(snapshot: WatchSnapshotEnvelope, state: WatchSnapshotState)
        -> WatchNextEventTimelineEntry
    {
        let content: WatchNextEventContent
        switch kind {
        case "event":
            if let eventID,
                let event = snapshot.payload.events.first(where: {
                    Int64($0.id) == eventID.int64Value
                })
            {
                content = .event(event, phase: ongoing ? .ongoing : .upcoming)
            } else {
                content = .programUnavailable
            }
        case "programUnavailable": content = .programUnavailable
        case "planUnavailable": content = .planUnavailable
        case "noSavedEvents": content = .noSavedEvents
        case "planEnded": content = .planEnded
        case "festivalEnded": content = .festivalEnded
        default: content = .programUnavailable
        }
        return WatchNextEventTimelineEntry(
            date: Date(timeIntervalSince1970: timestamp), content: content,
            planCompleteness: snapshot.payload.planCompleteness, isStale: stale,
            isShowingRetainedSnapshotAfterFailedImport: state
                .isShowingRetainedSnapshotAfterFailedImport,
            snapshotRevision: snapshot.revision)
    }
}
private extension WatchSnapshotState {
    var projectionSnapshot: WatchSnapshotEnvelope? {
        switch availability {
        case .available, .stale: return snapshot;
        default: return nil
        }
    }
    var projectionFailure: WatchSnapshotUnavailableReason {
        if case .unavailable(let reason) = availability { return reason }
        return .noSnapshot
    }
}
extension WatchSnapshotEnvelope {
    var coreFreshness: PlanFreshness {
        PlanFreshness(
            generatedAt: generatedAt.timeIntervalSince1970,
            source: freshness.festivalDataSource.rawValue,
            dataUpdatedAt: freshness.festivalDataUpdatedAt.map {
                KotlinDouble(value: $0.timeIntervalSince1970)
            },
            recommendationsAvailable: payload.recommendations.state == .available,
            recommendationsAt: payload.recommendations.generatedAt.map {
                KotlinDouble(value: $0.timeIntervalSince1970)
            },
            friendsAvailable: payload.friends.state == .available,
            friendsAt: payload.friends.updatedAt.map {
                KotlinDouble(value: $0.timeIntervalSince1970)
            })
    }
    var corePlan: PersonalPlanSnapshot {
        PersonalPlanSnapshot(
            year: Int32(festivalYear),
            events: payload.events.map {
                PlanEvent(
                    eventID: Int64($0.id), start: $0.startDate.timeIntervalSince1970,
                    end: $0.endDate.timeIntervalSince1970,
                    day: Int32($0.festivalDay), saved: $0.isSaved,
                    friendSaveCount: $0.friendSaveCount.map { KotlinInt(value: Int32($0)) })
            },
            missingSavedCount: payload.missingSavedEventCount.map { KotlinInt(value: Int32($0)) },
            hasUnplacedSavedEvents: payload.unplacedSavedEvents?.isEmpty == false,
            incompleteProgram: payload.hasIncompleteProgram == true, freshness: coreFreshness,
            transitions: payload.planTransitions.map {
                PlanTransition(
                    from: Int64($0.fromEventID), to: Int64($0.toEventID), status: $0.status.rawValue
                )
            },
            conflicts: payload.planOverlaps.map {
                PlanConflict(
                    first: Int64($0.firstEventID), second: Int64($0.secondEventID),
                    minutes: Int32($0.overlapMinutes))
            })
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
