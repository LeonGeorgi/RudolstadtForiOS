import Foundation
import RudolstadtCore

typealias RecommendationSnapshot = RecommendationResult
extension RecommendationResult: @unchecked @retroactive Sendable {
    convenience init(recommendedEventIds: [Int], estimatedEventDurations: [Int: Int]) {
        self.init(
            eventIDs: KotlinCore.ids(recommendedEventIds),
            durations: estimatedEventDurations.sorted { $0.key < $1.key }.map {
                EventMinutes(eventID: Int64($0.key), minutes: Int32($0.value))
            })
    }
    var recommendedEventIds: [Int] { eventIDs.map(\.intValue) }
    var estimatedEventDurations: [Int: Int] {
        Dictionary(uniqueKeysWithValues: durations.map { (Int($0.eventID), Int($0.minutes)) })
    }
}

protocol RecommendationProviding: Sendable {
    func buildSnapshot(data: FestivalData, savedEventIds: [Int], ratings: [String: Int], now: Date)
        -> RecommendationSnapshot
}

/// Schedules the shared calculation with native cancellation and optional injected services.
final class RecommendationService: RecommendationProviding {
    private let walkingDistanceMatrix: StageWalkingDistanceMatrix?
    init(calendar: Calendar = .current, walkingDistanceMatrix: StageWalkingDistanceMatrix? = nil) {
        self.walkingDistanceMatrix = walkingDistanceMatrix
    }
    func buildSnapshot(
        data: FestivalData, savedEventIds: [Int], ratings: [String: Int], now: Date = .now
    ) -> RecommendationSnapshot {
        let provider = data.features.automaticPlanning.value
        let transfers: any TransferSource
        if let shared = provider as? ProgramDistanceCatalog {
            transfers = shared
        } else if let provider {
            transfers = NativeTransferSource { from, to in
                provider.transfer(
                    from: FestivalPlaceID(coreID: from), to: FestivalPlaceID(coreID: to)
                ).map(
                    StageTransferEstimate.init)?.core
            }
        } else {
            transfers =
                StageTransferEstimator(
                    stages: data.stages, matrix: walkingDistanceMatrix ?? data.walkingDistanceMatrix
                ).engine
        }
        return ProgramRecommendations.shared.build(
            program: data.coreProgram, saved: KotlinCore.ids(savedEventIds),
            ratings: ratings.mapValues { KotlinInt(value: Int32($0)) },
            now: now.timeIntervalSince1970,
            capabilityBacked: data.metadata != nil,
            eligibleIDs: provider.map { Set(KotlinCore.ids($0.eligibleEventIDs)) },
            transfer: transfers, cancelled: { KotlinBoolean(bool: Task.isCancelled) })
    }
    func estimateEventDurations(events: [Event]) -> [Int: Int] {
        Dictionary(
            uniqueKeysWithValues: FestivalDurationResolver.resolve(events).compactMap { event in
                event.duration.map { (event.id, $0.minutes) }
            })
    }
}

typealias ScheduleEventSections = ProgramSections
extension ProgramSections {
    convenience init(events: [Event], selectedDay: Int) {
        let value = ProgramSchedule.shared.sections(
            events: events, dayNumber: KotlinInt(value: Int32(selectedDay)), dayID: nil)
        self.init(
            scheduled: value.scheduled, unknownTime: value.unknownTime,
            unknownDate: value.unknownDate)
    }
    convenience init(events: [Event], selectedProgramDay: String?) {
        let value = ProgramSchedule.shared.sections(
            events: events, dayNumber: nil, dayID: selectedProgramDay)
        self.init(
            scheduled: value.scheduled, unknownTime: value.unknownTime,
            unknownDate: value.unknownDate)
    }
}

struct SchedulePresenter {
    let festivalData: FestivalData
    let recommendationState: RecommendationState
    let scheduleFilterType: ScheduleFilter
    let profileState: ProfileState
    init(
        festivalData: FestivalData, recommendationState: RecommendationState,
        scheduleFilterType: ScheduleFilter,
        profileState: ProfileState, calendar: Calendar = .current
    ) {
        self.festivalData = festivalData
        self.recommendationState = recommendationState
        self.scheduleFilterType = scheduleFilterType
        self.profileState = profileState
    }
    var availableEventDays: [Int] {
        ProgramSchedule.shared.days(events: festivalData.events).map(\.intValue)
    }
    var shownEvents: LoadingEntity<[Event]> {
        let state = SchedulePresentation.shared.shown(
            events: festivalData.events, filter: scheduleFilterType.rawValue,
            profile: profileState, recommendation: recommendationState)
        switch state.phase {
        case .ready: return .success(state.events)
        case .failed:
            return .failure(FailureReason(rawValue: state.failure ?? "") ?? .couldNotLoadFromFile)
        default: return .loading
        }
    }
}
