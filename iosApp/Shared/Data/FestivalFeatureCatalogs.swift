import Foundation
import RudolstadtCore

typealias FestivalArtistCatalog = ProgramArtistCatalog
typealias FestivalPlaceCatalog = ProgramPlaceCatalog
typealias FestivalEventCatalog = ProgramEventCatalog
typealias FestivalSimilarityProvider = ProgramSimilarityCatalog
typealias FestivalDistanceCatalog = ProgramDistanceCatalog

extension ProgramArtistCatalog: ArtistDetailsProviding, ArtistSummariesProviding,
    ArtistGroupingsProviding, @unchecked @retroactive Sendable
{
    convenience init(artists: [Int: Artist], groupings: [ArtistGrouping]) {
        self.init(values: Array(artists.values), groupings: groupings)
    }
    func details(for artistID: Int) -> ArtistDetails? { details(id: Int64(artistID)) }
    func availableLanguages(for artistID: Int) -> Set<LanguageTag> {
        Set(languages(id: Int64(artistID)).map(LanguageTag.init))
    }
    func summary(for artistID: Int, language: LanguageTag) -> ArtistSummary? {
        summary(id: Int64(artistID), language: language.identifier)
    }
    func groupIDs(for artistID: Int, in groupingID: String) -> Set<String> {
        groupIDs(id: Int64(artistID), grouping: groupingID)
    }
}
extension ProgramPlaceCatalog: FestivalPlaceDetailsProviding, FestivalAreasProviding,
    FestivalAdmissionProviding, @unchecked @retroactive Sendable
{
    func details(for placeID: FestivalPlaceID) -> FestivalPlaceDetails? {
        details(id: placeID.coreID)
    }
    func areaIDs(for placeID: FestivalPlaceID) -> Set<Int> {
        Set(areaIDs(id: placeID.coreID).map(\.intValue))
    }
    func admission(for placeID: FestivalPlaceID) -> FestivalAdmission? {
        admission(id: placeID.coreID)
    }
    func admission(for eventID: Int) -> FestivalAdmission? { eventAdmission(id: Int64(eventID)) }
}
extension ProgramEventCatalog: FestivalEventDetailsProviding, @unchecked @retroactive Sendable {
    convenience init(events: [Int: Event], tags: [Tag]) {
        self.init(events: Array(events.values), tags: tags)
    }
    func details(for eventID: Int) -> FestivalEventDetails? { details(id: Int64(eventID)) }
}
extension ProgramSimilarityCatalog: ArtistSimilaritiesProviding, @unchecked @retroactive Sendable {
    convenience init(values: [Int: [Int]]) {
        self.init(
            values: values.map {
                SimilarArtistIDs(artistID: Int64($0.key), similarIDs: KotlinCore.ids($0.value))
            })
    }
    func similarArtistIDs(to artistID: Int, limit: Int) -> [Int] {
        similar(id: Int64(artistID), limit: Int32(limit)).map(\.intValue)
    }
}
extension ProgramDistanceCatalog: FestivalDistancesProviding, FestivalAutomaticPlanningProviding,
    @unchecked @retroactive Sendable
{
    var eligibleEventIDs: Set<Int> { Set(eligibleIDs.map(\.intValue)) }
    func straightLineDistance(from source: FestivalPlaceID, to destination: FestivalPlaceID)
        -> StraightLineDistance?
    {
        straightLine(from: source.coreID, to: destination.coreID).map {
            StraightLineDistance(meters: $0.meters, coordinatesAreApproximate: $0.approximate)
        }
    }
    func walkingTransfer(from source: FestivalPlaceID, to destination: FestivalPlaceID)
        -> WalkingTransfer?
    {
        walking(from: source.coreID, to: destination.coreID)?.native
    }
    func transfer(from source: FestivalPlaceID, to destination: FestivalPlaceID) -> WalkingTransfer?
    {
        planningTransfer(from: source.coreID, to: destination.coreID)?.native
    }
}
extension ProgramWalkingTransfer {
    var native: WalkingTransfer {
        let result = StageTransferEstimate(transfer)
        let basis: TransferBasis
        switch result.source {
        case .sameStage: basis = .samePlace
        case .knownRoute: basis = .knownWalkingRoute
        case .anchoredEstimate: basis = .anchoredEstimate
        case .directCoordinateEstimate: basis = .coordinateEstimate
        }
        return WalkingTransfer(
            distanceMeters: result.distanceInMeters, estimatedMinutes: result.walkingMinutes,
            basis: basis, coordinatesAreApproximate: approximate)
    }
}

typealias FestivalEventTagPresentation = ProgramTagPolicy
extension ProgramTagPolicy: @unchecked @retroactive Sendable {
    convenience init(
        discoveryOrder: [String]? = nil, hiddenTimelineNames: Set<String> = [],
        titleOverrides: [String: LocalizedText] = [:], introductions: [String: LocalizedText] = [:]
    ) {
        self.init(
            discoveryOrder: discoveryOrder, hiddenTimelineNames: hiddenTimelineNames,
            titleOverrides: titleOverrides.mapValues(\.core),
            introductions: introductions.mapValues(\.core))
    }
    var core: ProgramTagPolicy { self }
    func tags(in events: [Event]) -> [Tag] {
        ProgramPreparation.shared.tags(events: events, policy: self)
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
