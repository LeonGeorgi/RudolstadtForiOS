import Foundation

struct FestivalArtistCatalog: ArtistDetailsProviding, ArtistSummariesProviding, ArtistGroupingsProviding {
    let artists: [Int: Artist]
    let groupings: [ArtistGrouping]

    func details(for artistID: Int) -> ArtistDetails? {
        artists[artistID]?.details
    }

    func availableLanguages(for artistID: Int) -> Set<LanguageTag> {
        Set(artists[artistID]?.localizedSummaries.keys.map { $0 } ?? [])
    }

    func summary(for artistID: Int, language: LanguageTag) -> ArtistSummary? {
        artists[artistID]?.localizedSummaries[language]
    }

    func groupIDs(for artistID: Int, in groupingID: String) -> Set<String> {
        artists[artistID]?.groupIDs[groupingID] ?? []
    }
}

struct FestivalPlaceCatalog: FestivalPlaceDetailsProviding, FestivalAreasProviding, FestivalAdmissionProviding {
    let stages: [FestivalPlaceID: Stage]
    let extraPlaces: [FestivalPlaceID: FestivalPlanLocation]
    let areas: [Area]
    let categories: [FestivalAdmissionCategory]
    let eventPlaces: [Int: FestivalPlaceID]
    var supplementaryDetails: [FestivalPlaceID: FestivalPlaceDetails] = [:]

    func details(for placeID: FestivalPlaceID) -> FestivalPlaceDetails? {
        if let details = supplementaryDetails[placeID] { return details }
        if let stage = stages[placeID] {
            return FestivalPlaceDetails(description: stage.localizedDescriptions, links: [])
        }
        if let place = extraPlaces[placeID] {
            return FestivalPlaceDetails(description: FestivalContent(
                text: bilingual(place.noteDE, place.noteEN), format: .plainText), links: [])
        }
        return nil
    }

    func areaIDs(for placeID: FestivalPlaceID) -> Set<Int> {
        guard let area = stages[placeID]?.area, areas.contains(where: { $0.id == area.id }) else { return [] }
        return [area.id]
    }

    func admission(for placeID: FestivalPlaceID) -> FestivalAdmission? {
        guard let stage = stages[placeID], stage.stageType != .unknown else { return nil }
        let id = String(stage.stageType.rawValue)
        guard categories.contains(where: { $0.id == id }) else { return nil }
        return FestivalAdmission(categoryIDs: [id], note: nil)
    }

    func admission(for eventID: Int) -> FestivalAdmission? {
        eventPlaces[eventID].flatMap { admission(for: $0) }
    }
}

struct FestivalEventCatalog: FestivalEventDetailsProviding {
    let events: [Int: Event]
    let tags: [Tag]
    func details(for eventID: Int) -> FestivalEventDetails? {
        events[eventID].map { event in
            FestivalEventDetails(description: nil,
                tags: event.tags.compactMap { raw in tags.first { $0.id == raw.id } }, links: [])
        }
    }
}

struct FestivalEventTagPresentation: Sendable {
    var discoveryOrder: [String]? = nil
    var hiddenTimelineNames: Set<String> = []
    var titleOverrides: [String: LocalizedText] = [:]
    var introductions: [String: LocalizedText] = [:]

    func tags(in events: [Event]) -> [Tag] {
        let raw = Dictionary(events.flatMap(\.tags).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return raw.values.sorted { a, b in
            let first = discoveryOrder?.firstIndex(of: a.germanName) ?? .max
            let second = discoveryOrder?.firstIndex(of: b.germanName) ?? .max
            return first == second
                ? a.id.compare(b.id, options: .numeric, locale: Locale(identifier: "en_US_POSIX")) == .orderedAscending
                : first < second
        }.map { tag in
            Tag(id: tag.id, title: titleOverrides[tag.germanName] ?? tag.title,
                introduction: introductions[tag.germanName],
                isDiscoverable: discoveryOrder?.contains(tag.germanName) ?? true,
                showsOnTimeline: !hiddenTimelineNames.contains(tag.germanName))
        }
    }
}

struct FestivalSimilarityProvider: ArtistSimilaritiesProviding {
    let values: [Int: [Int]]
    func similarArtistIDs(to artistID: Int, limit: Int) -> [Int] {
        Array((values[artistID] ?? []).prefix(max(0, limit)))
    }
}

struct FestivalMapCatalog: FestivalMapProviding {
    let maps: [FestivalMap]
    let defaultMapID: String
    let categories: [MapCategory]
    let assignments: [FestivalPlaceID: String]
    func category(for placeID: FestivalPlaceID) -> MapCategory? {
        assignments[placeID].flatMap { id in categories.first { $0.id == id } }
    }
}

struct FestivalPlanCatalog: FestivalSitePlanProviding {
    let document: SitePlanDocument
    let positions: [FestivalPlaceID: SitePlanPosition]
    func position(for placeID: FestivalPlaceID) -> SitePlanPosition? { positions[placeID] }
}

struct FestivalDistanceCatalog: FestivalDistancesProviding, FestivalAutomaticPlanningProviding {
    let estimator: StageTransferEstimator
    let coordinates: [FestivalPlaceID: FestivalCoordinate]
    let knownPlaceIDs: Set<FestivalPlaceID>
    let eligibleEventIDs: Set<Int>

    func straightLineDistance(from source: FestivalPlaceID, to destination: FestivalPlaceID) -> StraightLineDistance? {
        guard let a = coordinates[source], let b = coordinates[destination],
              let meters = StageTransferLocation(stageID: source, latitude: a.latitude, longitude: a.longitude)
                .airDistanceInMeters(to: StageTransferLocation(stageID: destination, latitude: b.latitude, longitude: b.longitude))
        else { return nil }
        return StraightLineDistance(meters: meters, coordinatesAreApproximate: a.isApproximate || b.isApproximate)
    }

    func walkingTransfer(from source: FestivalPlaceID, to destination: FestivalPlaceID) -> WalkingTransfer? {
        guard knownPlaceIDs.contains(source), knownPlaceIDs.contains(destination),
              let result = estimator.estimate(fromStageID: source, toStageID: destination) else { return nil }
        let basis: TransferBasis
        switch result.source {
        case .sameStage: basis = .samePlace
        case .knownRoute: basis = .knownWalkingRoute
        case .anchoredEstimate: basis = .anchoredEstimate
        case .directCoordinateEstimate: basis = .coordinateEstimate
        }
        return WalkingTransfer(distanceMeters: result.distanceInMeters, estimatedMinutes: result.walkingMinutes,
                               basis: basis, coordinatesAreApproximate:
                                coordinates[source]?.isApproximate == true || coordinates[destination]?.isApproximate == true)
    }

    func transfer(from source: FestivalPlaceID, to destination: FestivalPlaceID) -> WalkingTransfer? {
        guard coordinates[source]?.isApproximate != true, coordinates[destination]?.isApproximate != true else { return nil }
        return walkingTransfer(from: source, to: destination)
    }
}

struct FestivalInformationCatalog: FestivalInformationProviding {
    let pages: [FestivalInformationPage]
    func page(for id: String) -> FestivalInformationPage? { pages.first { $0.id == id } }
}

func bilingual(_ german: String?, _ english: String?) -> LocalizedText {
    var values = [LanguageTag: String]()
    if let german, !german.isEmpty { values[LanguageTag("de")] = german }
    if let english, !english.isEmpty { values[LanguageTag("en")] = english }
    return LocalizedText(values: values)
}
