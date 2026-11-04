import Foundation
import RudolstadtCore

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

public enum FestivalPlaceID: Hashable, Codable, Sendable, Comparable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    case numeric(Int)
    case text(String)

    public init(integerLiteral value: Int) { self = .numeric(value) }

    var numericValue: Int? {
        if case .numeric(let value) = self { return value }
        return nil
    }

    public var description: String {
        switch self {
        case .numeric(let value): return String(value)
        case .text(let value): return value
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.numeric(a), .numeric(b)): return a < b
        case (.numeric, .text): return true
        case (.text, .numeric): return false
        case let (.text(a), .text(b)): return a < b
        }
    }
}

struct FestivalEventDuration: Codable, Equatable, Sendable {
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
    /// Restores only an already converted cache, before the first UI frame.
    func loadInitialCachedProgram() throws -> FestivalData?
    func loadBundledProgram() async throws -> FestivalData?
    func refresh() async throws -> FestivalData
    func deleteCache() async throws
}

extension FestivalAdapter {
    func loadInitialCachedProgram() throws -> FestivalData? { nil }
}

struct FestivalFeatures: Sendable {
    let information: FeatureAvailability<any FestivalInformationProviding>
    let artistDetails: FeatureAvailability<any ArtistDetailsProviding>
    let placeDetails: FeatureAvailability<any FestivalPlaceDetailsProviding>
    let eventDetails: FeatureAvailability<EventDetailsFeature>
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
        eventDetails: FeatureAvailability<EventDetailsFeature> = .unsupported,
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

enum FestivalContentFormat: Equatable, Sendable { case plainText, html }

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

protocol ArtistDetailsProviding: Sendable {
    func details(for artistID: Artist.ID) -> ArtistDetails?
}

protocol FestivalPlaceDetailsProviding: Sendable {
    func details(for placeID: FestivalPlaceID) -> FestivalPlaceDetails?
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

protocol ArtistSummariesProviding: Sendable {
    func availableLanguages(
        for artistID: Artist.ID
    ) -> Set<LanguageTag>

    func summary(
        for artistID: Artist.ID,
        language: LanguageTag
    ) -> ArtistSummary?
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

struct FestivalCoordinate: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let isApproximate: Bool
    let sourceURL: URL?
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
    case artist(Artist.ID, highlightedEventID: Event.ID? = nil)
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

// Domain values are the actual shared objects; extensions below only adapt Apple types.
typealias FestivalContent = ProgramContent
typealias FestivalEditorialContent = ProgramEditorialContent
typealias FestivalInformationField = ProgramInformationField
typealias ArtistDetails = ProgramArtistDetails
typealias ArtistSummary = ProgramSummary
typealias ArtistGroup = ProgramGroup
typealias ArtistGrouping = ProgramGrouping
typealias FestivalAdmissionCategory = ProgramCategory
typealias MapCategory = ProgramCategory

extension ProgramContent: @unchecked @retroactive Sendable {
    convenience init(text: LocalizedText, format: FestivalContentFormat) {
        self.init(texts: text.core, html: format == .html)
    }
    var text: LocalizedText { LocalizedText(core: texts) }
    var format: FestivalContentFormat { html ? .html : .plainText }
    var core: ProgramContent { self }
    var native: FestivalContent { self }
}
extension ProgramEditorialContent: @unchecked @retroactive Sendable {
    convenience init(
        article: FestivalContent? = nil,
        informationFields: [FestivalInformationField] = [],
        links: [FestivalLink] = []
    ) {
        self.init(article: article, fields: informationFields, links: links.map(\.core))
    }
    var nativeLinks: [FestivalLink] { links.compactMap(\.native) }
}
extension ProgramInformationField: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public var id: String { fieldID }
    var title: LocalizedText { LocalizedText(core: titles) }
    var value: LocalizedText { LocalizedText(core: values) }
    convenience init(id: String, title: LocalizedText, value: LocalizedText) {
        self.init(fieldID: id, titles: title.core, values: value.core)
    }
}
extension ProgramArtistDetails: @unchecked @retroactive Sendable {
    convenience init(
        descriptions: FestivalContent, thumbnailURL: URL?, imageURL: URL?, countryCodes: [String],
        links: [FestivalLink], countryDescription: LocalizedText? = nil,
        keywords: [LanguageTag: [String]] = [:], musicPreview: FestivalMusicPreview = .automatic
    ) {
        let kind: String; let url: String?
        switch musicPreview {
        case .automatic: kind = "automatic"; url = nil
        case .disabled: kind = "disabled"; url = nil
        case .songURL(let value): kind = "songURL"; url = value.absoluteString
        }
        self.init(
            descriptions: descriptions, thumbnail: thumbnailURL?.absoluteString,
            image: imageURL?.absoluteString,
            countryCodes: countryCodes, links: links.map(\.core),
            countryDescription: countryDescription?.core,
            keywords: Dictionary(
                uniqueKeysWithValues: keywords.map { ($0.key.identifier, $0.value) }),
            previewKind: kind, previewURL: url)
    }
    var core: ProgramArtistDetails { self }
    var native: ArtistDetails { self }
}
extension ProgramSummary: @unchecked @retroactive Sendable {
    convenience init(text: String, language: LanguageTag, origin: SummaryOrigin, sourceURL: URL?) {
        self.init(
            text: text, language: language.identifier, aiGenerated: origin == .aiGenerated,
            sourceURL: sourceURL?.absoluteString)
    }
    var core: ProgramSummary { self }
    var native: ArtistSummary { self }
}
extension ProgramGroup: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public var id: String { groupID }
    var title: LocalizedText { LocalizedText(core: titles) }
    convenience init(id: String, title: LocalizedText) {
        self.init(groupID: id, titles: title.core)
    }
}
extension ProgramGrouping: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public var id: String { groupingID }
    var title: LocalizedText { LocalizedText(core: titles) }
    convenience init(id: String, title: LocalizedText, groups: [ArtistGroup]) {
        self.init(groupingID: id, titles: title.core, groups: groups)
    }
}
extension ProgramCategory: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public var id: String { categoryID }
    var title: LocalizedText { LocalizedText(core: titles) }
    convenience init(
        id: String, title: LocalizedText, description: LocalizedText?, tintHex: String?,
        darkTintHex: String? = nil
    ) {
        self.init(
            categoryID: id, titles: title.core, descriptionTexts: description?.core,
            systemImageName: nil,
            tintHex: tintHex, darkTintHex: darkTintHex)
    }
    convenience init(
        id: String, title: LocalizedText, systemImageName: String, tintHex: String?,
        darkTintHex: String? = nil
    ) {
        self.init(
            categoryID: id, titles: title.core, descriptionTexts: nil,
            systemImageName: systemImageName,
            tintHex: tintHex, darkTintHex: darkTintHex)
    }
    var core: ProgramCategory { self }
    var nativeAdmission: FestivalAdmissionCategory { self }
    var nativeMap: MapCategory { self }
}

typealias FestivalEditionKind = EditionKind
typealias FestivalUserDataAccess = UserDataAccess
typealias FestivalUserDataPolicy = UserDataPolicy
typealias FestivalNoticeSeverity = NoticeSeverity
typealias FestivalNotice = ProgramNotice
typealias FestivalPresentation = ProgramPresentation
typealias FestivalMetadata = ProgramMetadata

extension UserDataPolicy: @unchecked @retroactive Sendable {}
extension ProgramPresentation: @unchecked @retroactive Sendable {
    convenience init(logoURL: URL?, accentColorHex: String?) {
        self.init(logo: logoURL?.absoluteString, accentColorHex: accentColorHex)
    }
    var logoURL: URL? { logo.flatMap(URL.init(string:)) }
}
extension ProgramNotice: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public var id: String { noticeID }
    var title: LocalizedText { LocalizedText(core: titles) }
    var message: LocalizedText? { messages.map(LocalizedText.init(core:)) }
    var links: [FestivalLink] { noticeLinks.compactMap(\.native) }
    convenience init(
        id: String, severity: FestivalNoticeSeverity, title: LocalizedText, message: LocalizedText?,
        links: [FestivalLink]
    ) {
        self.init(
            noticeID: id, severity: severity, titles: title.core, messages: message?.core,
            noticeLinks: links.map(\.core))
    }
}
extension ProgramMetadata: @unchecked @retroactive Sendable {
    var identity: FestivalIdentity {
        FestivalIdentity(festivalID: festival.festivalID, editionID: festival.editionID)
    }
    var name: LocalizedText { LocalizedText(core: names) }
    var editionLabel: LocalizedText { LocalizedText(core: editionTitles) }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .gmt }
    var defaultContentLanguage: LanguageTag { LanguageTag(defaultLanguage) }
    var officialLinks: [FestivalLink] { links.compactMap(\.native) }
    var dateRange: DateInterval? {
        guard let start = rangeStart, let end = rangeEnd else { return nil }
        return DateInterval(start: start.date, end: end.date)
    }
    convenience init(
        identity: FestivalIdentity, name: LocalizedText, editionLabel: LocalizedText,
        editionKind: FestivalEditionKind,
        dateRange: DateInterval?, timeZone: TimeZone, defaultContentLanguage: LanguageTag,
        officialLinks: [FestivalLink],
        presentation: FestivalPresentation, notices: [FestivalNotice],
        userDataPolicy: FestivalUserDataPolicy
    ) {
        self.init(
            festival: identity.core, names: name.core, editionTitles: editionLabel.core,
            editionKind: editionKind,
            rangeStart: dateRange.map { KotlinDouble(value: $0.start.timeIntervalSince1970) },
            rangeEnd: dateRange.map { KotlinDouble(value: $0.end.timeIntervalSince1970) },
            timeZoneID: timeZone.identifier, defaultLanguage: defaultContentLanguage.identifier,
            links: officialLinks.map(\.core),
            presentation: presentation, notices: notices, userDataPolicy: userDataPolicy)
    }
}

typealias FestivalPlaceDetails = ProgramPlaceInformation
typealias FestivalAdmission = ProgramAdmission
extension ProgramPlaceInformation: @unchecked @retroactive Sendable {
    convenience init(description: FestivalContent?, links: [FestivalLink]) {
        self.init(content: description, programLinks: links.map(\.core))
    }
    var links: [FestivalLink] { programLinks.compactMap(\.native) }
}
extension EventDetailsFeature: @unchecked @retroactive Sendable {}
extension EventDetailContent: @unchecked @retroactive Sendable {}
extension ProgramAdmission: @unchecked @retroactive Sendable {
    convenience init(categoryIDs: Set<String>, note: LocalizedText?) {
        self.init(categoryIDs: categoryIDs, notes: note?.core)
    }
    var note: LocalizedText? { notes.map(LocalizedText.init(core:)) }
}

typealias FestivalNewsItem = NewsArticle
typealias FestivalNewsSnapshot = NewsSnapshot
extension NewsArticle: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public var id: String { articleID }
    var title: LocalizedText { LocalizedText(core: titles) }
    var summary: LocalizedText? { summaries.map(LocalizedText.init(core:)) }
    var imageURL: URL? { image.flatMap(URL.init(string:)) }
    var updatedAt: Date? { updatedTimestamp?.date }
    var sourceURL: URL? { sourceURLString.flatMap(URL.init(string:)) }
    var links: [FestivalLink] { articleLinks.compactMap(\.native) }
    var relatedDestinations: [FestivalDestination] { destinations.compactMap(\.native) }
    convenience init(
        id: String, title: LocalizedText, summary: LocalizedText?, body: FestivalContent,
        imageURL: URL?, publishedAt: Date?, updatedAt: Date?, sourceURL: URL?,
        links: [FestivalLink],
        relatedDestinations: [FestivalDestination]
    ) {
        self.init(
            articleID: id, titles: title.core, summaries: summary?.core, body: body,
            publishedAt: publishedAt.map { KotlinDouble(value: $0.timeIntervalSince1970) },
            image: imageURL?.absoluteString,
            updatedTimestamp: updatedAt.map { KotlinDouble(value: $0.timeIntervalSince1970) },
            sourceURLString: sourceURL?.absoluteString,
            articleLinks: links.map(\.core), destinations: relatedDestinations.map(\.core))
    }
}
extension NewsSnapshot: @unchecked @retroactive Sendable {
    var identity: FestivalIdentity {
        FestivalIdentity(festivalID: festivalID, editionID: editionID)
    }
    var items: [FestivalNewsItem] { articles }
    var provenance: FestivalDataProvenance {
        FestivalDataProvenance(
            source: snapshotSource.flatMap(FestivalDataSource.init(core:)) ?? .cache,
            dataUpdatedAt: dataUpdatedAt?.date, refreshCheckedAt: refreshCheckedAt?.date)
    }
    var notice: LocalizedText? {
        if let noticeTexts { return LocalizedText(core: noticeTexts) }
        guard let noticeKey else { return nil }
        return LocalizedText(
            values: Dictionary(
                uniqueKeysWithValues: ["de", "en"].map {
                    (
                        LanguageTag($0),
                        String(
                            localized: String.LocalizationValue(noticeKey),
                            locale: Locale(identifier: $0))
                    )
                }))
    }
    convenience init(
        identity: FestivalIdentity, items: [FestivalNewsItem], provenance: FestivalDataProvenance
    ) {
        self.init(
            festivalID: identity.festivalID, editionID: identity.editionID, articles: items,
            contextID: 0,
            snapshotSource: provenance.source.core,
            dataUpdatedAt: provenance.dataUpdatedAt.map {
                KotlinDouble(value: $0.timeIntervalSince1970)
            },
            refreshCheckedAt: provenance.refreshCheckedAt.map {
                KotlinDouble(value: $0.timeIntervalSince1970)
            }, noticeTexts: nil, noticeKey: nil)
    }
}
extension FestivalDestination {
    var core: ContentDestination {
        let kind: String; let id: String?
        switch self {
        case .overview: kind = "overview"; id = nil
        case .artist(let value, _): kind = "artist"; id = String(value)
        case .event(let value): kind = "event"; id = String(value)
        case .place(let value): kind = "place"; id = value.coreID
        case .information(let value): kind = "information"; id = value
        case .news(let value): kind = "news"; id = value
        }
        return ContentDestination(kind: kind, id: id)
    }
}
extension ContentDestination {
    var native: FestivalDestination? {
        switch kind {
        case "overview": return .overview
        case "artist": return id.flatMap(Int.init).map { .artist($0) }
        case "event": return id.flatMap(Int.init).map(FestivalDestination.event)
        case "place": return id.map { .place(FestivalPlaceID(coreID: $0)) }
        case "information": return id.map(FestivalDestination.information)
        case "news": return id.map(FestivalDestination.news)
        default: return nil
        }
    }
}
