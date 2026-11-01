import Foundation

struct FestivalIdentity: Hashable, Codable, Sendable {
    let festivalID: String
    let editionID: String

    var storageKey: String {
        let allowed = CharacterSet.alphanumerics
        return (festivalID.addingPercentEncoding(withAllowedCharacters: allowed) ?? festivalID)
            + "/" + (editionID.addingPercentEncoding(withAllowedCharacters: allowed) ?? editionID)
    }
}

struct LanguageTag: Hashable, Sendable {
    let identifier: String

    init(_ identifier: String) {
        self.identifier = Locale.canonicalLanguageIdentifier(from: identifier)
    }
}

struct LocalizedText: Sendable {
    let values: [LanguageTag: String]

    var availableLanguages: Set<LanguageTag> {
        Set(values.keys)
    }

    func text(in language: LanguageTag) -> String? {
        values[language]
    }
}

enum FestivalEditionKind: Equatable, Sendable {
    case regular
    case archive
    case experimental
}

enum FestivalUserDataAccess: Equatable, Sendable {
    case unsupported
    case readOnly
    case editable
}

struct FestivalUserDataPolicy: Sendable {
    let savedEvents: FestivalUserDataAccess
    let artistRatings: FestivalUserDataAccess
    let artistNotes: FestivalUserDataAccess
}

enum FestivalNoticeSeverity: Sendable {
    case information
    case warning
}

struct FestivalNotice: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let severity: FestivalNoticeSeverity
    let title: LocalizedText
    let message: LocalizedText?
    let links: [FestivalLink]
}

struct FestivalPresentation: Sendable {
    let logoURL: URL?
    let accentColorHex: String?
}

struct FestivalMetadata: Sendable {
    let identity: FestivalIdentity
    let name: LocalizedText
    let editionLabel: LocalizedText
    let editionKind: FestivalEditionKind
    let dateRange: DateInterval?
    let timeZone: TimeZone
    let defaultContentLanguage: LanguageTag
    let officialLinks: [FestivalLink]
    let presentation: FestivalPresentation
    let notices: [FestivalNotice]
    let userDataPolicy: FestivalUserDataPolicy
}

struct FestivalCatalog: Sendable {
    let adapters: [any FestivalAdapter]
    let defaultIdentity: FestivalIdentity

    init(adapters: [any FestivalAdapter], defaultIdentity: FestivalIdentity) throws {
        let identities = adapters.map { $0.metadata.identity }
        guard !adapters.isEmpty, Set(identities).count == identities.count,
              identities.contains(defaultIdentity),
              identities.allSatisfy({ !$0.festivalID.isEmpty && !$0.editionID.isEmpty }) else {
            throw FestivalCatalogError.invalidRegistration
        }
        self.adapters = adapters
        self.defaultIdentity = defaultIdentity
    }

    var festivals: [FestivalMetadata] {
        adapters.map { $0.metadata }
    }

    func adapter(for identity: FestivalIdentity) -> (any FestivalAdapter)? {
        adapters.first { $0.metadata.identity == identity }
    }
}

struct FestivalCalendarDate: Hashable, Codable, Sendable {
    let year: Int
    let month: Int
    let day: Int
}

struct FestivalDay: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let date: FestivalCalendarDate
    let title: LocalizedText?
    let interval: DateInterval
}

enum FestivalPlaceID: Hashable, Codable, Sendable, Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    case numeric(Int)
    case text(String)

    init(integerLiteral value: Int) { self = .numeric(value) }

    var numericValue: Int? {
        if case .numeric(let value) = self { return value }
        return nil
    }

    var description: String {
        switch self {
        case .numeric(let value): return String(value)
        case .text(let value): return value
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.numeric(a), .numeric(b)): return a < b
        case (.numeric, .text): return true
        case (.text, .numeric): return false
        case let (.text(a), .text(b)): return a < b
        }
    }
}

struct FestivalEventDuration: Equatable, Sendable {
    let minutes: Int
    let isEstimated: Bool
}

enum FestivalDataSource: Equatable, Sendable {
    case remote
    case cache
    case staleCache
    case bundledBackup
    case bundledArchive
    case bundledExperiment
    case preview
    case screenshot
}

struct FestivalDataProvenance: Equatable, Sendable {
    let source: FestivalDataSource
    let dataUpdatedAt: Date?
    let refreshCheckedAt: Date?
    var omittedRecordCount: Int = 0
}

enum FestivalLoadingStrategy: Equatable, Sendable {
    case refreshable
    case bundledOnly
}

protocol FestivalAdapter: Sendable {
    var metadata: FestivalMetadata { get }
    var services: FestivalServices { get }
    var loadingStrategy: FestivalLoadingStrategy { get }

    func loadCachedProgram() async throws -> FestivalData?
    func loadBundledProgram() async throws -> FestivalData?
    func refresh() async throws -> FestivalData
    func deleteCache() async throws
}

struct FestivalFeatures: Sendable {
    let information: FeatureAvailability<any FestivalInformationProviding>
    let artistDetails: FeatureAvailability<any ArtistDetailsProviding>
    let placeDetails: FeatureAvailability<any FestivalPlaceDetailsProviding>
    let eventDetails: FeatureAvailability<any FestivalEventDetailsProviding>
    let admission: FeatureAvailability<any FestivalAdmissionProviding>
    let summaries: FeatureAvailability<any ArtistSummariesProviding>
    let groupings: FeatureAvailability<any ArtistGroupingsProviding>
    let similarities: FeatureAvailability<any ArtistSimilaritiesProviding>
    let areas: FeatureAvailability<any FestivalAreasProviding>
    let map: FeatureAvailability<any FestivalMapProviding>
    let sitePlan: FeatureAvailability<any FestivalSitePlanProviding>
    let distances: FeatureAvailability<any FestivalDistancesProviding>
    let automaticPlanning: FeatureAvailability<any FestivalAutomaticPlanningProviding>

    init(
        information: FeatureAvailability<any FestivalInformationProviding> = .unsupported,
        artistDetails: FeatureAvailability<any ArtistDetailsProviding> = .unsupported,
        placeDetails: FeatureAvailability<any FestivalPlaceDetailsProviding> = .unsupported,
        eventDetails: FeatureAvailability<any FestivalEventDetailsProviding> = .unsupported,
        admission: FeatureAvailability<any FestivalAdmissionProviding> = .unsupported,
        summaries: FeatureAvailability<any ArtistSummariesProviding> = .unsupported,
        groupings: FeatureAvailability<any ArtistGroupingsProviding> = .unsupported,
        similarities: FeatureAvailability<any ArtistSimilaritiesProviding> = .unsupported,
        areas: FeatureAvailability<any FestivalAreasProviding> = .unsupported,
        map: FeatureAvailability<any FestivalMapProviding> = .unsupported,
        sitePlan: FeatureAvailability<any FestivalSitePlanProviding> = .unsupported,
        distances: FeatureAvailability<any FestivalDistancesProviding> = .unsupported,
        automaticPlanning: FeatureAvailability<any FestivalAutomaticPlanningProviding> = .unsupported
    ) {
        self.information = information
        self.artistDetails = artistDetails
        self.placeDetails = placeDetails
        self.eventDetails = eventDetails
        self.admission = admission
        self.summaries = summaries
        self.groupings = groupings
        self.similarities = similarities
        self.areas = areas
        self.map = map
        self.sitePlan = sitePlan
        self.distances = distances
        self.automaticPlanning = automaticPlanning
    }
}

enum FeatureAvailability<Value: Sendable>: Sendable {
    case unsupported
    case available(Value)
    case unavailable(FeatureIssue)
}

enum FeatureIssue: Sendable {
    case missingData
    case invalidData
    case loadFailed(any Error)
}

enum FestivalContentFormat: Equatable, Sendable {
    case plainText
    case html
}

struct FestivalContent: Sendable {
    let text: LocalizedText
    let format: FestivalContentFormat
}

enum FestivalLinkOpeningMode: Equatable, Sendable {
    case externalBrowser
    case inAppBrowser
}

struct FestivalLink: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
    let destination: URL
    let openingMode: FestivalLinkOpeningMode
}

enum FestivalInformationContent: Sendable {
    case article(FestivalContent)
    case webPage(URL)
}

struct FestivalInformationPage: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
    let content: FestivalInformationContent
    let systemImageName: String?
    let links: [FestivalLink]
    let relatedPlaceIDs: [FestivalPlaceID]
    let sourceURL: URL?
    let updatedAt: Date?
}

protocol FestivalInformationProviding: Sendable {
    var pages: [FestivalInformationPage] { get }

    func page(
        for id: FestivalInformationPage.ID
    ) -> FestivalInformationPage?
}

enum FestivalMusicPreview: Sendable {
    case automatic
    case disabled
    case songURL(URL)
}

struct ArtistDetails: Sendable {
    let descriptions: FestivalContent
    let thumbnailURL: URL?
    let imageURL: URL?
    let countryCodes: [String]
    var links: [FestivalLink]
    var countryDescription: LocalizedText? = nil
    var keywords: [LanguageTag: [String]] = [:]
    var musicPreview: FestivalMusicPreview = .automatic
}

protocol ArtistDetailsProviding: Sendable {
    func details(for artistID: Artist.ID) -> ArtistDetails?
}

struct FestivalPlaceDetails: Sendable {
    let description: FestivalContent?
    let links: [FestivalLink]
}

protocol FestivalPlaceDetailsProviding: Sendable {
    func details(for placeID: FestivalPlaceID) -> FestivalPlaceDetails?
}

struct FestivalEventDetails: Sendable {
    let description: FestivalContent?
    let tags: [Tag]
    let links: [FestivalLink]
}

protocol FestivalEventDetailsProviding: Sendable {
    var tags: [Tag] { get }
    func details(for eventID: Event.ID) -> FestivalEventDetails?
}

struct FestivalAdmissionCategory: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
    let description: LocalizedText?
    let tintHex: String?
    var darkTintHex: String? = nil
}

struct FestivalAdmission: Sendable {
    let categoryIDs: Set<FestivalAdmissionCategory.ID>
    let note: LocalizedText?
}

protocol FestivalAdmissionProviding: Sendable {
    var categories: [FestivalAdmissionCategory] { get }

    func admission(for placeID: FestivalPlaceID) -> FestivalAdmission?
    func admission(for eventID: Event.ID) -> FestivalAdmission?
}

enum SummaryOrigin: Sendable {
    case editorial
    case aiGenerated
}

struct ArtistSummary: Sendable {
    let text: String
    let language: LanguageTag
    let origin: SummaryOrigin
    let sourceURL: URL?
}

protocol ArtistSummariesProviding: Sendable {
    func availableLanguages(
        for artistID: Artist.ID
    ) -> Set<LanguageTag>

    func summary(
        for artistID: Artist.ID,
        language: LanguageTag
    ) -> ArtistSummary?
}

struct ArtistGroup: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
}

struct ArtistGrouping: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
    let groups: [ArtistGroup]
}

protocol ArtistGroupingsProviding: Sendable {
    var groupings: [ArtistGrouping] { get }

    func groupIDs(
        for artistID: Artist.ID,
        in groupingID: ArtistGrouping.ID
    ) -> Set<ArtistGroup.ID>
}

protocol ArtistSimilaritiesProviding: Sendable {
    func similarArtistIDs(
        to artistID: Artist.ID,
        limit: Int
    ) -> [Artist.ID]
}

protocol FestivalAreasProviding: Sendable {
    var areas: [Area] { get }

    func areaIDs(
        for placeID: FestivalPlaceID
    ) -> Set<Area.ID>
}

struct FestivalCoordinate: Decodable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let isApproximate: Bool
    let sourceURL: URL?
}

struct MapCategory: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
    let systemImageName: String
    let tintHex: String?
    var darkTintHex: String? = nil
}

struct NormalizedMapPoint: Equatable, Sendable {
    let x: Double
    let y: Double
}

struct MapCanvasSize: Sendable {
    let width: Double
    let height: Double
}

enum MapArtworkFormat: Sendable {
    case svg
    case rasterImage
    case pdf(pageIndex: Int)
}

struct FestivalMapArtwork: Sendable {
    let localFileURL: URL
    let sourceURL: URL?
    let format: MapArtworkFormat
    let logicalSize: MapCanvasSize
    let sha256: String
}

enum FestivalMapContent: Sendable {
    case geographic(
        coordinates: [FestivalPlaceID: FestivalCoordinate]
    )
    case illustrated(
        artwork: FestivalMapArtwork,
        positions: [FestivalPlaceID: NormalizedMapPoint]
    )
}

struct FestivalMap: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
    let content: FestivalMapContent
}

protocol FestivalMapProviding: Sendable {
    var maps: [FestivalMap] { get }
    var defaultMapID: FestivalMap.ID { get }
    var categories: [MapCategory] { get }

    func category(for placeID: FestivalPlaceID) -> MapCategory?
}

struct SitePlanDocument: Sendable {
    let title: LocalizedText
    let localFileURL: URL
    let sourceURL: URL?
}

struct SitePlanPosition: Sendable {
    let pageIndex: Int
    let point: NormalizedMapPoint
}

protocol FestivalSitePlanProviding: Sendable {
    var document: SitePlanDocument { get }

    func position(for placeID: FestivalPlaceID) -> SitePlanPosition?
}

struct StraightLineDistance: Sendable {
    let meters: Double
    let coordinatesAreApproximate: Bool
}

enum TransferBasis: Sendable {
    case samePlace
    case knownWalkingRoute
    case anchoredEstimate
    case coordinateEstimate
}

struct WalkingTransfer: Sendable {
    let distanceMeters: Double
    let estimatedMinutes: Int
    let basis: TransferBasis
    let coordinatesAreApproximate: Bool
}

protocol FestivalDistancesProviding: Sendable {
    func straightLineDistance(
        from source: FestivalPlaceID,
        to destination: FestivalPlaceID
    ) -> StraightLineDistance?

    func walkingTransfer(
        from source: FestivalPlaceID,
        to destination: FestivalPlaceID
    ) -> WalkingTransfer?
}

protocol FestivalAutomaticPlanningProviding: Sendable {
    var eligibleEventIDs: Set<Event.ID> { get }

    func transfer(
        from source: FestivalPlaceID,
        to destination: FestivalPlaceID
    ) -> WalkingTransfer?
}

enum FestivalDestination: Hashable, Codable, Sendable {
    case overview
    case artist(Artist.ID)
    case event(Event.ID)
    case place(FestivalPlaceID)
    case information(FestivalInformationPage.ID)
    case news(FestivalNewsItem.ID)
}

struct FestivalRoute: Hashable, Codable, Sendable {
    let identity: FestivalIdentity
    let destination: FestivalDestination
}

protocol FestivalPublicLinksProviding: Sendable {
    func url(for destination: FestivalDestination) -> URL?
    func destination(for url: URL) -> FestivalDestination?
}

struct FestivalNewsItem: Identifiable, Sendable {
    typealias ID = String

    let id: ID
    let title: LocalizedText
    let summary: LocalizedText?
    let body: FestivalContent
    let imageURL: URL?
    let publishedAt: Date?
    let updatedAt: Date?
    let sourceURL: URL?
    let links: [FestivalLink]
    let relatedDestinations: [FestivalDestination]
}

struct FestivalNewsSnapshot: Sendable {
    var notice: LocalizedText? = nil
    let identity: FestivalIdentity
    let items: [FestivalNewsItem]
    let provenance: FestivalDataProvenance
}

protocol FestivalNewsProviding: Sendable {
    func loadCachedNews() async throws -> FestivalNewsSnapshot?
    func loadBundledNews() async throws -> FestivalNewsSnapshot?
    func refreshNews() async throws -> FestivalNewsSnapshot
    func deleteCache() async throws
}

struct FestivalServices: Sendable {
    let news: FeatureAvailability<any FestivalNewsProviding>
    let publicLinks: FeatureAvailability<any FestivalPublicLinksProviding>

    init(
        news: FeatureAvailability<any FestivalNewsProviding> = .unsupported,
        publicLinks: FeatureAvailability<any FestivalPublicLinksProviding> = .unsupported
    ) {
        self.news = news
        self.publicLinks = publicLinks
    }
}

enum FestivalCatalogError: Error { case invalidRegistration }
