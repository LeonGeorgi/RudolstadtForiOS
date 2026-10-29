import Foundation
import RudolstadtCore

enum ScheduleTransitionStatus: String, Codable, Equatable, Sendable {
    case notApplicable
    case comfortable
    case tight
    case impossible
    case unknown
}

struct ScheduleTransitionPolicy: Codable, Equatable, Sendable {
    var arrivalBufferMinutes: Int
    var maximumMissedMinutes: Int
    var tightTransitionThresholdMinutes: Int
    var estimatedTransfersCanBlock: Bool

    static let recommendation = ScheduleTransitionPolicy(
        arrivalBufferMinutes: 2,
        maximumMissedMinutes: 0,
        tightTransitionThresholdMinutes: 5,
        estimatedTransfersCanBlock: false
    )

    static let savedEventWarning = ScheduleTransitionPolicy(
        arrivalBufferMinutes: 0,
        maximumMissedMinutes: 5,
        tightTransitionThresholdMinutes: 5,
        estimatedTransfersCanBlock: true
    )
}

struct ScheduleTransitionAssessment: Codable, Equatable, Sendable {
    let firstEventID: Int
    let secondEventID: Int
    let timeOverlapMinutes: Int
    let availableTransferMinutes: Int?
    let transfer: StageTransferEstimate?
    let projectedLatenessMinutes: Int?
    let status: ScheduleTransitionStatus

    var isConflict: Bool {
        status == .impossible
    }
}

struct ScheduleTransitionEvaluator: Sendable {
    let transferEstimator: StageTransferEstimator
    let transferProvider: (@Sendable (FestivalPlaceID, FestivalPlaceID) -> StageTransferEstimate?)?
    let calendar: Calendar

    init(
        transferEstimator: StageTransferEstimator,
        calendar: Calendar = .current,
        transferProvider: (@Sendable (FestivalPlaceID, FestivalPlaceID) -> StageTransferEstimate?)? = nil
    ) {
        self.transferProvider = transferProvider
        self.transferEstimator = transferEstimator
        // Legacy callers use the Rudolstadt clock. Capability-backed programs
        // supply their own festival calendar with the transfer provider.
        self.calendar = transferProvider == nil
            ? FestivalDateUtilities.calendarInFestivalTimeZone(basedOn: calendar)
            : calendar
    }

    func assess(
        first firstEvent: Event,
        firstDurationMinutes: Int,
        second secondEvent: Event,
        secondDurationMinutes: Int,
        policy: ScheduleTransitionPolicy
    ) -> ScheduleTransitionAssessment {
        ProgramTransitions.shared.assess(
            first: firstEvent, firstDuration: Int32(firstDurationMinutes),
            second: secondEvent, secondDuration: Int32(secondDurationMinutes), policy: policy.core,
            transfer: coreTransfers
        ).native
    }
    var coreTransfers: any TransferSource {
        if let transferProvider {
            return NativeTransferSource { from, to in
                transferProvider(FestivalPlaceID(coreID: from), FestivalPlaceID(coreID: to))?.core
            }
        }
        return transferEstimator.engine
    }
}

/// Adapts an injected native feature provider. Built-in catalogs execute entirely in Kotlin.
final class NativeTransferSource: NSObject, TransferSource {
    private let resolve: (String, String) -> Transfer?
    init(_ resolve: @escaping (String, String) -> Transfer?) { self.resolve = resolve }
    func transfer(from: String, to: String) -> Transfer? { resolve(from, to) }
}
