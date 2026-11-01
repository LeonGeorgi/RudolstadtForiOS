import Foundation

struct WatchSnapshotBuildInput {
    let festivalYear: Int
    let revision: UInt64
    let generatedAt: Date
    let environment: WatchSnapshotEnvironment
    let freshness: WatchSnapshotFreshness
    let events: [Event]
    let savedEventIDs: Set<Int>
    let ratingsByArtistID: [String: Int]
    let estimatedDurationsByEventID: [Int: Int]
    let recommendations: WatchRecommendationSnapshot
    let friends: WatchFriendSnapshot
    let friendProfiles: [SharedFestivalProfile]
    let transitionEvaluator: ScheduleTransitionEvaluator
    var omittedRecordCount = 0
}

enum WatchSnapshotBuildDiagnostic: Equatable {
    case duplicateEventID(Int)
    case invalidEventDate(Int)
    case unsupportedPlaceID(eventID: Int)
    case missingSavedEventID(Int)
    case missingRecommendedEventID(Int)
    case ignoredFriendProfileFromFestivalYear(Int)
    case invalidDuration(eventID: Int)
}

struct WatchSnapshotBuildResult: Equatable {
    let envelope: WatchSnapshotEnvelope
    let diagnostics: [WatchSnapshotBuildDiagnostic]
}

struct WatchSnapshotBuilder {
    private struct DatedEvent {
        let event: Event
        let startDate: Date
        let festivalDay: Int
        let numericStageID: Int
    }

    let defaultDurationMinutes: Int

    init(defaultDurationMinutes: Int = 60) {
        self.defaultDurationMinutes = max(1, defaultDurationMinutes)
    }

    func build(_ input: WatchSnapshotBuildInput) -> WatchSnapshotBuildResult {
        var diagnostics = [WatchSnapshotBuildDiagnostic]()
        let sortedEvents = input.events.compactMap { event -> DatedEvent? in
            guard let startDate = validatedStartDate(
                for: event,
                    festivalYear: input.festivalYear
            ) else {
                diagnostics.append(.invalidEventDate(event.id))
                return nil
            }
            // The existing Rudolstadt Watch payload uses numeric stage identifiers.
            guard let stageID = event.stage.id.numericValue else {
                diagnostics.append(.unsupportedPlaceID(eventID: event.id))
                return nil
            }
            return DatedEvent(
                event: event,
                startDate: startDate,
                festivalDay: event.festivalDay,
                numericStageID: stageID
            )
        }.sorted { first, second in
            if first.startDate != second.startDate {
                return first.startDate < second.startDate
            }
            return first.event.id < second.event.id
        }

        var knownEventIDs = Set<Int>()
        let datedEvents = sortedEvents.filter { datedEvent in
            let wasInserted = knownEventIDs.insert(datedEvent.event.id).inserted
            if !wasInserted {
                diagnostics.append(.duplicateEventID(datedEvent.event.id))
            }
            return wasInserted
        }
        let events = datedEvents.map(\.event)

        let missingSavedEventIDs = input.savedEventIDs
            .subtracting(knownEventIDs)
            .sorted()
        for missingID in missingSavedEventIDs {
            diagnostics.append(.missingSavedEventID(missingID))
        }

        let recommendations = normalizedRecommendations(
            input.recommendations,
            knownEventIDs: Set(events.filter(\.hasCompleteMetadata).map(\.id)),
            diagnostics: &diagnostics
        )
        let recommendationRanks = recommendations.orderedEventIDs.enumerated().reduce(
            into: [Int: Int]()
        ) { result, entry in
            result[entry.element] = entry.offset
        }

        let validFriendProfiles = input.friendProfiles.filter { profile in
            let isCurrent = profile.festivalYear == input.festivalYear
            if !isCurrent {
                diagnostics.append(
                    .ignoredFriendProfileFromFestivalYear(profile.festivalYear)
                )
            }
            return isCurrent
        }
        let friendSaveCounts: [Int: Int]
        if input.friends.state == .available {
            friendSaveCounts = validFriendProfiles.reduce(into: [:]) { result, profile in
                for eventID in Set(profile.savedEventIDs) where knownEventIDs.contains(eventID) {
                    result[eventID, default: 0] += 1
                }
            }
        } else {
            friendSaveCounts = [:]
        }

        let durationsByEventID = normalizedDurations(
            for: events,
            providedDurations: input.estimatedDurationsByEventID,
            diagnostics: &diagnostics
        )
        let eventSnapshots = datedEvents.map { datedEvent in
            let event = datedEvent.event
            return WatchEventSnapshot(
                id: event.id,
                artistID: event.artist.id,
                artistName: event.artist.name,
                stageID: datedEvent.numericStageID,
                stageNumber: event.stage.stageNumber,
                stageNameGerman: event.stage.germanName,
                stageNameEnglish: event.stage.englishName,
                festivalDay: datedEvent.festivalDay,
                startDate: datedEvent.startDate,
                endDate: datedEvent.startDate.addingTimeInterval(
                    Double(durationsByEventID[event.id] ?? defaultDurationMinutes) * 60
                ),
                isSaved: input.savedEventIDs.contains(event.id),
                hasPositiveRating: (input.ratingsByArtistID[String(event.artist.id)] ?? 0) > 0,
                recommendationRank: recommendationRanks[event.id],
                friendSaveCount: input.friends.state == .available
                    ? friendSaveCounts[event.id, default: 0]
                    : nil
            )
        }

        let planFacts = makePlanFacts(
            events: events.filter { input.savedEventIDs.contains($0.id) },
            durationsByEventID: durationsByEventID,
            evaluator: input.transitionEvaluator
        )
        let envelope = WatchSnapshotEnvelope(
            schemaVersion: WatchSnapshotEnvelope.currentSchemaVersion,
            festivalYear: input.festivalYear,
            revision: input.revision,
            generatedAt: input.generatedAt,
            environment: input.environment,
            freshness: input.freshness,
            payload: WatchFestivalSnapshot(
                events: eventSnapshots,
                missingSavedEventCount: missingSavedEventIDs.count,
                recommendations: recommendations,
                friends: input.friends,
                planTransitions: planFacts.transitions,
                planOverlaps: planFacts.overlaps,
                unplacedSavedEvents: input.events.filter {
                    $0.startDate == nil && input.savedEventIDs.contains($0.id)
                }.sorted { $0.id < $1.id }.map {
                    WatchUnplacedEventSnapshot(
                        id: $0.id, artistName: $0.artist.name,
                        stageNameGerman: $0.stage.germanName,
                        stageNameEnglish: $0.stage.englishName,
                        knownDay: $0.knownDate)
                },
                hasIncompleteProgram: input.omittedRecordCount > 0
                    || datedEvents.count != input.events.count
                    || input.events.contains { !$0.hasCompleteMetadata }
            )
        )
        return WatchSnapshotBuildResult(
            envelope: envelope,
            diagnostics: diagnostics
        )
    }

    private func validatedStartDate(
        for event: Event,
        festivalYear: Int
    ) -> Date? {
        guard let start = event.startDate,
            FestivalDateUtilities.festivalCalendar.component(.year, from: start) == festivalYear
        else { return nil }
        return start
    }

    private func normalizedRecommendations(
        _ recommendations: WatchRecommendationSnapshot,
        knownEventIDs: Set<Int>,
        diagnostics: inout [WatchSnapshotBuildDiagnostic]
    ) -> WatchRecommendationSnapshot {
        guard recommendations.state == .available else {
            return WatchRecommendationSnapshot(
                state: recommendations.state,
                generatedAt: recommendations.generatedAt,
                orderedEventIDs: []
            )
        }

        var includedIDs = Set<Int>()
        let eventIDs = recommendations.orderedEventIDs.filter { eventID in
            guard knownEventIDs.contains(eventID) else {
                diagnostics.append(.missingRecommendedEventID(eventID))
                return false
            }
            return includedIDs.insert(eventID).inserted
        }
        return WatchRecommendationSnapshot(
            state: .available,
            generatedAt: recommendations.generatedAt,
            orderedEventIDs: eventIDs
        )
    }

    private func normalizedDurations(
        for events: [Event],
        providedDurations: [Int: Int],
        diagnostics: inout [WatchSnapshotBuildDiagnostic]
    ) -> [Int: Int] {
        events.reduce(into: [:]) { result, event in
            if let duration = providedDurations[event.id], duration > 0 {
                result[event.id] = duration
            } else {
                if let duration = providedDurations[event.id], duration <= 0 {
                    diagnostics.append(.invalidDuration(eventID: event.id))
                }
                result[event.id] = defaultDurationMinutes
            }
        }
    }

    private func makePlanFacts(
        events: [Event],
        durationsByEventID: [Int: Int],
        evaluator: ScheduleTransitionEvaluator
    ) -> (
        transitions: [WatchPlanTransitionSnapshot],
        overlaps: [WatchPlanOverlapSnapshot]
    ) {
        let eventsByFestivalDay = Dictionary(grouping: events) { event in
            event.festivalDay(calendar: evaluator.calendar)
        }
        var transitions = [WatchPlanTransitionSnapshot]()
        var overlaps = [WatchPlanOverlapSnapshot]()

        for festivalDay in eventsByFestivalDay.keys.sorted() {
            let dayEvents = (eventsByFestivalDay[festivalDay] ?? []).sorted {
                first,
                second in
                Event.precedes(first, second)
            }

            let eventGroups = overlappingEventGroups(
                dayEvents,
                durationsByEventID: durationsByEventID,
                calendar: evaluator.calendar
            )
            for (previousGroup, nextGroup) in zip(
                eventGroups,
                eventGroups.dropFirst()
            ) {
                for nextEvent in nextGroup {
                    let assessments = previousGroup.map { previousEvent in
                        evaluator.assess(
                            first: previousEvent,
                            firstDurationMinutes:
                                durationsByEventID[previousEvent.id]
                                    ?? defaultDurationMinutes,
                            second: nextEvent,
                            secondDurationMinutes:
                                durationsByEventID[nextEvent.id]
                                    ?? defaultDurationMinutes,
                            policy: .savedEventWarning
                        )
                    }
                    guard let assessment = assessments.min(
                        by: transitionAssessmentPrecedes
                    ) else {
                        continue
                    }
                    transitions.append(transitionSnapshot(from: assessment))
                }
            }

            for firstIndex in dayEvents.indices {
                for secondIndex in dayEvents.indices where secondIndex > firstIndex {
                    let first = dayEvents[firstIndex]
                    let second = dayEvents[secondIndex]
                    let assessment = evaluator.assess(
                        first: first,
                        firstDurationMinutes: durationsByEventID[first.id]
                            ?? defaultDurationMinutes,
                        second: second,
                        secondDurationMinutes: durationsByEventID[second.id]
                            ?? defaultDurationMinutes,
                        policy: .savedEventWarning
                    )
                    if assessment.timeOverlapMinutes > 0 {
                        overlaps.append(WatchPlanOverlapSnapshot(
                            firstEventID: assessment.firstEventID,
                            secondEventID: assessment.secondEventID,
                            overlapMinutes: assessment.timeOverlapMinutes
                        ))
                    }
                }
            }
        }
        return (transitions, overlaps)
    }

    private func overlappingEventGroups(
        _ events: [Event],
        durationsByEventID: [Int: Int],
        calendar: Calendar
    ) -> [[Event]] {
        var groups = [[Event]]()
        var currentGroup = [Event]()
        var currentGroupEnd: Date?

        for event in events {
            guard let startDate = event.startDate else { continue }
            let endDate = startDate.addingTimeInterval(
                TimeInterval(
                    durationsByEventID[event.id] ?? defaultDurationMinutes
                ) * 60
            )
            if let groupEnd = currentGroupEnd, startDate < groupEnd {
                currentGroup.append(event)
                currentGroupEnd = max(groupEnd, endDate)
            } else {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                }
                currentGroup = [event]
                currentGroupEnd = endDate
            }
        }
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        return groups
    }

    private func transitionAssessmentPrecedes(
        _ first: ScheduleTransitionAssessment,
        _ second: ScheduleTransitionAssessment
    ) -> Bool {
        let firstPriority = transitionPriority(first.status)
        let secondPriority = transitionPriority(second.status)
        if firstPriority != secondPriority {
            return firstPriority < secondPriority
        }
        let firstLateness = first.projectedLatenessMinutes ?? -1
        let secondLateness = second.projectedLatenessMinutes ?? -1
        if firstLateness != secondLateness {
            return firstLateness > secondLateness
        }
        let firstWalkingMinutes = first.transfer?.walkingMinutes ?? -1
        let secondWalkingMinutes = second.transfer?.walkingMinutes ?? -1
        if firstWalkingMinutes != secondWalkingMinutes {
            return firstWalkingMinutes > secondWalkingMinutes
        }
        return first.firstEventID < second.firstEventID
    }

    private func transitionPriority(_ status: ScheduleTransitionStatus) -> Int {
        switch status {
        case .impossible:
            return 0
        case .tight:
            return 1
        case .unknown:
            return 2
        case .comfortable:
            return 3
        case .notApplicable:
            return 4
        }
    }

    private func transitionSnapshot(
        from assessment: ScheduleTransitionAssessment
    ) -> WatchPlanTransitionSnapshot {
        WatchPlanTransitionSnapshot(
            fromEventID: assessment.firstEventID,
            toEventID: assessment.secondEventID,
            status: transitionStatus(from: assessment.status),
            walkingMinutes: assessment.transfer?.walkingMinutes,
            projectedLatenessMinutes: assessment.projectedLatenessMinutes,
            certainty: transferCertainty(from: assessment.transfer)
        )
    }

    private func transitionStatus(
        from status: ScheduleTransitionStatus
    ) -> WatchPlanTransitionStatus {
        switch status {
        case .comfortable:
            return .comfortable
        case .tight:
            return .tight
        case .impossible:
            return .impossible
        case .notApplicable, .unknown:
            return .unknown
        }
    }

    private func transferCertainty(
        from transfer: StageTransferEstimate?
    ) -> WatchTransferCertainty {
        guard let transfer else {
            return .unknown
        }
        return transfer.source.isEstimated ? .estimated : .known
    }
}

struct WatchSnapshotRevisionGenerator {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let now: () -> Date

    init(
        userDefaults: UserDefaults = .standard,
        festivalYear: Int,
        now: @escaping () -> Date = { .now }
    ) {
        self.userDefaults = userDefaults
        self.storageKey = "watch-snapshot-revision-\(festivalYear)-v1"
        self.now = now
    }

    func next() -> UInt64 {
        let previous = userDefaults.string(forKey: storageKey).flatMap(UInt64.init) ?? 0
        let timestamp = max(0, now().timeIntervalSince1970 * 1_000)
        let timestampRevision = UInt64(timestamp.rounded(.down))
        let incrementedRevision = previous == .max ? previous : previous + 1
        let revision = max(timestampRevision, incrementedRevision)
        userDefaults.set(String(revision), forKey: storageKey)
        return revision
    }
}
