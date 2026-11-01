import Foundation

struct StageWalkingDistanceMatrix: Equatable, Sendable {
    static let empty = StageWalkingDistanceMatrix(distancesByStageID: [:])
    private static let maximumSupportedDistanceInMeters = 100_000.0

    let distancesByStageID: [Int: [Int: Double]]
    let stageIDs: Set<Int>

    private let adjacentDistancesByStageID: [Int: [Int: Double]]

    init(distancesByStageID: [Int: [Int: Double]]) {
        var adjacentDistances = [Int: [Int: Double]]()
        var stageIDs = Set<Int>()

        for (sourceStageID, targets) in distancesByStageID {
            for (targetStageID, distanceInMeters) in targets
            where distanceInMeters.isFinite
                && distanceInMeters >= 0
                && distanceInMeters <= Self.maximumSupportedDistanceInMeters
            {
                stageIDs.insert(sourceStageID)
                stageIDs.insert(targetStageID)
                Self.addUndirectedDistance(
                    distanceInMeters,
                    from: sourceStageID,
                    to: targetStageID,
                    in: &adjacentDistances
                )
            }
        }

        self.distancesByStageID = adjacentDistances
        self.stageIDs = stageIDs
        self.adjacentDistancesByStageID = adjacentDistances
    }

    func containsStage(id: Int) -> Bool {
        stageIDs.contains(id)
    }

    func distanceInMeters(
        from sourceStageID: Int,
        to targetStageID: Int,
        allowedStageIDs: Set<Int>? = nil
    ) -> Double? {
        if sourceStageID == targetStageID {
            return containsStage(id: sourceStageID) ? 0 : nil
        }

        if let directDistance = distancesByStageID[sourceStageID]?[targetStageID] {
            return directDistance
        }
        if let inverseDistance = distancesByStageID[targetStageID]?[sourceStageID] {
            return inverseDistance
        }
        return shortestPathDistanceInMeters(
            from: sourceStageID,
            to: targetStageID,
            allowedStageIDs: allowedStageIDs
        )
    }

    private func shortestPathDistanceInMeters(
        from sourceStageID: Int,
        to targetStageID: Int,
        allowedStageIDs: Set<Int>?
    ) -> Double? {
        guard containsStage(id: sourceStageID), containsStage(id: targetStageID) else {
            return nil
        }

        var remainingStageIDs = stageIDs
        if let allowedStageIDs {
            remainingStageIDs.formIntersection(
                allowedStageIDs.union([sourceStageID, targetStageID])
            )
        }
        var distances = [sourceStageID: 0.0]

        while let currentStageID = remainingStageIDs.min(by: { first, second in
            (distances[first] ?? .greatestFiniteMagnitude)
                < (distances[second] ?? .greatestFiniteMagnitude)
        }) {
            guard let currentDistance = distances[currentStageID] else {
                return nil
            }
            if currentStageID == targetStageID {
                return currentDistance
            }

            remainingStageIDs.remove(currentStageID)
            for (neighborStageID, edgeDistance) in
                adjacentDistancesByStageID[currentStageID] ?? [:]
            where remainingStageIDs.contains(neighborStageID) {
                let candidateDistance = currentDistance + edgeDistance
                if candidateDistance
                    < (distances[neighborStageID] ?? .greatestFiniteMagnitude)
                {
                    distances[neighborStageID] = candidateDistance
                }
            }
        }

        return nil
    }

    private static func addUndirectedDistance(
        _ distance: Double,
        from sourceStageID: Int,
        to targetStageID: Int,
        in distances: inout [Int: [Int: Double]]
    ) {
        let currentForward = distances[sourceStageID]?[targetStageID]
        distances[sourceStageID, default: [:]][targetStageID] = min(
            currentForward ?? distance,
            distance
        )
        let currentBackward = distances[targetStageID]?[sourceStageID]
        distances[targetStageID, default: [:]][sourceStageID] = min(
            currentBackward ?? distance,
            distance
        )
    }
}

struct StageTransferPolicy: Equatable, Sendable {
    var walkingSpeedInMetersPerMinute = 80.0
    var coordinateDetourFactor = 1.5
    var maximumAnchorDistanceInMeters = 300.0
    var maximumAnchorCount = 3
    var knownRouteAirDistanceToleranceInMeters = 100.0

    fileprivate var normalized: StageTransferPolicy {
        var result = self
        if !result.walkingSpeedInMetersPerMinute.isFinite
            || result.walkingSpeedInMetersPerMinute <= 0
        {
            result.walkingSpeedInMetersPerMinute = 80
        }
        if !result.coordinateDetourFactor.isFinite
            || result.coordinateDetourFactor <= 0
        {
            result.coordinateDetourFactor = 1.5
        }
        if !result.maximumAnchorDistanceInMeters.isFinite
            || result.maximumAnchorDistanceInMeters < 0
        {
            result.maximumAnchorDistanceInMeters = 300
        }
        result.maximumAnchorCount = min(max(0, result.maximumAnchorCount), 10)
        if !result.knownRouteAirDistanceToleranceInMeters.isFinite
            || result.knownRouteAirDistanceToleranceInMeters < 0
        {
            result.knownRouteAirDistanceToleranceInMeters = 100
        }
        return result
    }
}

enum StageTransferSource: Equatable, Sendable {
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

struct StageTransferEstimate: Equatable, Sendable {
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
        latitude.isFinite
            && longitude.isFinite
            && (-90.0...90.0).contains(latitude)
            && (-180.0...180.0).contains(longitude)
            && !(latitude == 0 && longitude == 0)
    }

    func airDistanceInMeters(to other: StageTransferLocation) -> Double? {
        guard hasUsableCoordinates, other.hasUsableCoordinates else {
            return nil
        }

        let earthRadiusInMeters = 6_371_000.0
        let firstLatitude = latitude * .pi / 180
        let secondLatitude = other.latitude * .pi / 180
        let latitudeDelta = (other.latitude - latitude) * .pi / 180
        let longitudeDelta = (other.longitude - longitude) * .pi / 180
        let haversine = pow(sin(latitudeDelta / 2), 2)
            + cos(firstLatitude)
                * cos(secondLatitude)
                * pow(sin(longitudeDelta / 2), 2)
        return earthRadiusInMeters
            * 2
            * atan2(sqrt(haversine), sqrt(max(0, 1 - haversine)))
    }
}

struct StageTransferEstimator: Sendable {
    private static let maximumSupportedDistanceInMeters = 100_000.0

    private struct Anchor {
        let location: StageTransferLocation
        let connectorDistanceInMeters: Double
    }

    private struct Candidate {
        let distanceInMeters: Double
        let source: StageTransferSource
    }

    private let locationsByStageID: [FestivalPlaceID: StageTransferLocation]
    private let availableStageIDs: Set<FestivalPlaceID>
    private let matrix: StageWalkingDistanceMatrix
    private let policy: StageTransferPolicy

    init(
        stages: [Stage],
        matrix: StageWalkingDistanceMatrix,
        policy: StageTransferPolicy = StageTransferPolicy()
    ) {
        self.init(
            locations: stages.map(StageTransferLocation.init(stage:)),
            matrix: matrix,
            policy: policy
        )
    }

    init(
        locations: [StageTransferLocation],
        matrix: StageWalkingDistanceMatrix,
        policy: StageTransferPolicy = StageTransferPolicy()
    ) {
        let locationsByStageID = locations.reduce(into: [:]) { result, location in
            result[location.stageID] = location
        }
        self.locationsByStageID = locationsByStageID
        self.availableStageIDs = Set(locationsByStageID.keys)
        self.matrix = matrix
        self.policy = policy.normalized
    }

    func estimate(from firstStage: Stage, to secondStage: Stage) -> StageTransferEstimate? {
        guard firstStage.hasLocation, secondStage.hasLocation else { return nil }
        return estimate(
            from: StageTransferLocation(stage: firstStage),
            to: StageTransferLocation(stage: secondStage)
        )
    }

    func estimate(fromStageID firstStageID: FestivalPlaceID, toStageID secondStageID: FestivalPlaceID)
        -> StageTransferEstimate?
    {
        if firstStageID == secondStageID {
            return StageTransferEstimate(
                distanceInMeters: 0,
                walkingMinutes: 0,
                source: .sameStage
            )
        }

        guard let firstLocation = locationsByStageID[firstStageID],
              let secondLocation = locationsByStageID[secondStageID]
        else {
            return nil
        }

        return estimate(from: firstLocation, to: secondLocation)
    }

    private func estimate(
        from firstLocation: StageTransferLocation,
        to secondLocation: StageTransferLocation
    ) -> StageTransferEstimate? {
        if firstLocation.stageID == secondLocation.stageID {
            return StageTransferEstimate(
                distanceInMeters: 0,
                walkingMinutes: 0,
                source: .sameStage
            )
        }

        if let knownDistance = usableKnownDistanceInMeters(
            from: firstLocation,
            to: secondLocation
        ) {
            return makeEstimate(
                distanceInMeters: knownDistance,
                source: .knownRoute
            )
        }

        let firstAnchors = anchors(for: firstLocation)
        let secondAnchors = anchors(for: secondLocation)
        var candidates = anchoredCandidates(
            firstAnchors: firstAnchors,
            secondAnchors: secondAnchors
        )

        let bothStagesAreOutsideKnownNetwork =
            !matrixContains(firstLocation.stageID)
                && !matrixContains(secondLocation.stageID)
        if candidates.isEmpty || bothStagesAreOutsideKnownNetwork,
           let directAirDistance = firstLocation.airDistanceInMeters(to: secondLocation)
        {
            candidates.append(Candidate(
                distanceInMeters: directAirDistance * policy.coordinateDetourFactor,
                source: .directCoordinateEstimate
            ))
        }

        guard let bestCandidate = candidates.min(by: candidateSortOrder) else {
            return nil
        }
        return makeEstimate(
            distanceInMeters: bestCandidate.distanceInMeters,
            source: bestCandidate.source
        )
    }

    private func anchors(for location: StageTransferLocation) -> [Anchor] {
        if matrixContains(location.stageID) {
            return [Anchor(
                location: location,
                connectorDistanceInMeters: 0
            )]
        }

        guard location.hasUsableCoordinates else {
            return []
        }

        let nearbyAnchors = locationsByStageID.values.compactMap { candidate -> Anchor? in
            guard
                candidate.stageID != location.stageID,
                matrixContains(candidate.stageID),
                let airDistance = location.airDistanceInMeters(to: candidate),
                airDistance <= policy.maximumAnchorDistanceInMeters
            else {
                return nil
            }
            return Anchor(
                location: candidate,
                connectorDistanceInMeters: airDistance * policy.coordinateDetourFactor
            )
        }
        .sorted { first, second in
            if first.connectorDistanceInMeters == second.connectorDistanceInMeters {
                return first.location.stageID < second.location.stageID
            }
            return first.connectorDistanceInMeters < second.connectorDistanceInMeters
        }

        return Array(nearbyAnchors.prefix(policy.maximumAnchorCount))
    }

    private func anchoredCandidates(
        firstAnchors: [Anchor],
        secondAnchors: [Anchor]
    ) -> [Candidate] {
        firstAnchors.flatMap { firstAnchor in
            secondAnchors.compactMap { secondAnchor in
                guard let knownDistance = usableKnownDistanceInMeters(
                    from: firstAnchor.location,
                    to: secondAnchor.location
                ) else {
                    return nil
                }
                return Candidate(
                    distanceInMeters: firstAnchor.connectorDistanceInMeters
                        + knownDistance
                        + secondAnchor.connectorDistanceInMeters,
                    source: .anchoredEstimate
                )
            }
        }
    }

    private func usableKnownDistanceInMeters(
        from firstLocation: StageTransferLocation,
        to secondLocation: StageTransferLocation
    ) -> Double? {
        var allowedStageIDs = availableStageIDs
        allowedStageIDs.insert(firstLocation.stageID)
        allowedStageIDs.insert(secondLocation.stageID)
        guard let firstID = firstLocation.stageID.numericValue,
              let secondID = secondLocation.stageID.numericValue,
              let knownDistance = matrix.distanceInMeters(
            from: firstID,
            to: secondID,
            allowedStageIDs: Set(allowedStageIDs.compactMap(\.numericValue))
        ) else {
            return nil
        }

        if let airDistance = firstLocation.airDistanceInMeters(to: secondLocation),
           knownDistance + policy.knownRouteAirDistanceToleranceInMeters < airDistance
        {
            return nil
        }
        return knownDistance
    }

    private func makeEstimate(
        distanceInMeters: Double,
        source: StageTransferSource
    ) -> StageTransferEstimate? {
        guard distanceInMeters.isFinite,
              distanceInMeters >= 0,
              distanceInMeters <= Self.maximumSupportedDistanceInMeters
        else {
            return nil
        }

        let walkingMinutes: Int
        if source == .sameStage {
            walkingMinutes = 0
        } else {
            let roundedMinutes = ceil(
                distanceInMeters / policy.walkingSpeedInMetersPerMinute
            )
            guard roundedMinutes.isFinite, roundedMinutes <= Double(Int.max) else {
                return nil
            }
            walkingMinutes = max(1, Int(roundedMinutes))
        }
        return StageTransferEstimate(
            distanceInMeters: distanceInMeters,
            walkingMinutes: walkingMinutes,
            source: source
        )
    }

    private func candidateSortOrder(first: Candidate, second: Candidate) -> Bool {
        if first.distanceInMeters == second.distanceInMeters {
            return sourcePriority(first.source) < sourcePriority(second.source)
        }
        return first.distanceInMeters < second.distanceInMeters
    }

    private func matrixContains(_ id: FestivalPlaceID) -> Bool {
        id.numericValue.map { matrix.containsStage(id: $0) } ?? false
    }

    private func sourcePriority(_ source: StageTransferSource) -> Int {
        switch source {
        case .sameStage, .knownRoute:
            return 0
        case .anchoredEstimate:
            return 1
        case .directCoordinateEstimate:
            return 2
        }
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
