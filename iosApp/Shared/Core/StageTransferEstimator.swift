import Foundation
import RudolstadtCore

typealias StageWalkingDistanceMatrix = WalkingDistanceMatrix
extension WalkingDistanceMatrix: @unchecked @retroactive Sendable {
    static let empty = WalkingDistanceMatrix(distances: [:])
    convenience init(distancesByStageID: [Int: [Int: Double]]) {
        self.init(
            distances: Dictionary(
                uniqueKeysWithValues: distancesByStageID.map { from, targets in
                    (
                        FestivalPlaceID.numeric(from).coreID,
                        Dictionary(
                            uniqueKeysWithValues: targets.map {
                                (
                                    FestivalPlaceID.numeric($0.key).coreID,
                                    KotlinDouble(value: $0.value)
                                )
                            })
                    )
                }))
    }
    var stageIDs: Set<Int> { Set(placeIDs.compactMap { FestivalPlaceID(coreID: $0).numericValue }) }
    func containsStage(id: Int) -> Bool { placeIDs.contains(FestivalPlaceID.numeric(id).coreID) }
    func distanceInMeters(from sourceStageID: Int, to targetStageID: Int, allowedStageIDs: Set<Int>? = nil) -> Double? {
        distance(
            from: FestivalPlaceID.numeric(sourceStageID).coreID,
            to: FestivalPlaceID.numeric(targetStageID).coreID,
            allowed: allowedStageIDs.map { Set($0.map { FestivalPlaceID.numeric($0).coreID }) })?.doubleValue
    }
}

struct StageTransferPolicy: Codable, Equatable, Sendable {
    var walkingSpeedInMetersPerMinute = 80.0
    var coordinateDetourFactor = 1.5
    var maximumAnchorDistanceInMeters = 300.0
    var maximumAnchorCount = 3
    var knownRouteAirDistanceToleranceInMeters = 100.0

}

enum StageTransferSource: String, Codable, Equatable, Sendable {
    case sameStage
    case knownRoute
    case anchoredEstimate
    case directCoordinateEstimate

    var isEstimated: Bool {
        switch self {
        case .anchoredEstimate, .directCoordinateEstimate:
            return true
        case .sameStage, .knownRoute:
            return false
        }
    }
}

struct StageTransferEstimate: Codable, Equatable, Sendable {
    let distanceInMeters: Double
    let walkingMinutes: Int
    let source: StageTransferSource
}

struct StageTransferLocation: Equatable, Sendable {
    let stageID: FestivalPlaceID
    let latitude: Double
    let longitude: Double

    init(stageID: FestivalPlaceID, latitude: Double, longitude: Double) {
        self.stageID = stageID
        self.latitude = latitude
        self.longitude = longitude
    }

    init(stage: Stage) {
        self.init(
            stageID: stage.id,
            latitude: stage.latitude,
            longitude: stage.longitude
        )
    }

    var hasUsableCoordinates: Bool {
        KotlinCore.bridge.usableCoordinates(latitude: latitude, longitude: longitude)
    }

    func airDistanceInMeters(to other: StageTransferLocation) -> Double? {
        KotlinCore.bridge.airDistance(first: CoreLocation(self).core, second: CoreLocation(other).core)?.doubleValue
    }
}

struct StageTransferEstimator: @unchecked Sendable {
    let engine: TransferEstimator
    init(stages: [Stage], matrix: StageWalkingDistanceMatrix, policy: StageTransferPolicy = StageTransferPolicy()) {
        self.init(locations: stages.map(StageTransferLocation.init(stage:)), matrix: matrix, policy: policy)
    }
    init(locations: [StageTransferLocation], matrix: StageWalkingDistanceMatrix, policy: StageTransferPolicy = StageTransferPolicy()) {
        engine = TransferEstimator(
            locations: locations.map { CoreLocation($0).core },
            matrix: matrix, policy: policy.core)
    }
    func estimate(from firstStage: Stage, to secondStage: Stage) -> StageTransferEstimate? {
        guard firstStage.hasLocation, secondStage.hasLocation else { return nil }
        return estimate(fromStageID: firstStage.id, toStageID: secondStage.id)
    }
    func estimate(fromStageID source: FestivalPlaceID, toStageID destination: FestivalPlaceID) -> StageTransferEstimate? {
        engine.estimate(from: source.coreID, to: destination.coreID).map(StageTransferEstimate.init)
    }
}


extension StageTransferLocation {
    init(stageID: Int, latitude: Double, longitude: Double) {
        self.init(stageID: .numeric(stageID), latitude: latitude, longitude: longitude)
    }
}

extension StageTransferEstimator {
    func estimate(fromStageID source: Int, toStageID destination: Int) -> StageTransferEstimate? {
        estimate(fromStageID: .numeric(source), toStageID: .numeric(destination))
    }
}


extension StageTransferEstimate {
    init(_ transfer: WalkingTransfer) {
        let source: StageTransferSource
        switch transfer.basis {
        case .samePlace: source = .sameStage
        case .knownWalkingRoute: source = .knownRoute
        case .anchoredEstimate: source = .anchoredEstimate
        case .coordinateEstimate: source = .directCoordinateEstimate
        }
        self.init(distanceInMeters: transfer.distanceMeters, walkingMinutes: transfer.estimatedMinutes, source: source)
    }
}
