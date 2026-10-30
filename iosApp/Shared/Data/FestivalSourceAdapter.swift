import CryptoKit
import Foundation
import PDFKit
import RudolstadtCore

/// Loads and prepares the same program values consumed by the app.
struct FestivalSourceAdapter: FestivalAdapter {
    let metadata: FestivalMetadata
    var services: FestivalServices
    let loadingStrategy: FestivalLoadingStrategy
    let source: any FestivalDataProviding
    let bundledSource: FestivalDataSource
    let dayBoundaryHour: Int
    let includesAreas: Bool
    let includesAdmission: Bool
    let offersAutomaticPlanning: Bool
    let informationPages: [FestivalInformationPage]
    var earliestProgramDate: FestivalCalendarDate? = nil
    var eventTagPresentation = FestivalEventTagPresentation()
    var supplementaryPlaces: [FestivalSupplementaryPlace] = []

    func loadInitialCachedProgram() throws -> FestivalData? {
        switch source.loadInitialCachedData() {
        case .loaded(let data):
            return try prepare(
                data, source: source.isCacheStale ? .staleCache : .cache,
                updatedAt: source.cacheModificationDate)
        case .stale(let data):
            return try prepare(data, source: .staleCache, updatedAt: source.cacheModificationDate)
        case .notFound, .unparsable: return nil
        }
    }

    func loadCachedProgram() async throws -> FestivalData? {
        try Task.checkCancellation()
        switch source.loadCachedData() {
        case .loaded(let data):
            return try prepare(
                data, source: source.isCacheStale ? .staleCache : .cache,
                updatedAt: source.cacheModificationDate)
        case .stale(let data):
            return try prepare(data, source: .staleCache, updatedAt: source.cacheModificationDate)
        case .notFound: return nil
        case .unparsable: throw FestivalLoadingError.invalidSnapshot
        }
    }

    func loadBundledProgram() async throws -> FestivalData? {
        try Task.checkCancellation()
        switch source.loadBundledData() {
        case .loaded(let data), .stale(let data): return try prepare(data, source: bundledSource)
        case .notFound: return nil
        case .unparsable: throw FestivalLoadingError.invalidSnapshot
        }
    }

    func refresh() async throws -> FestivalData {
        let data = try await source.refresh()
        try Task.checkCancellation()
        return try prepare(
            data, source: bundledSource == .bundledBackup ? .remote : bundledSource,
            updatedAt: bundledSource == .bundledBackup ? Date.now : nil)
    }

    func deleteCache() async throws {
        guard source.deleteCache() else { throw FestivalLoadingError.cacheDeletionFailed }
    }

    func prepare(
        _ input: FestivalData, source dataSource: FestivalDataSource,
        updatedAt: Date? = nil
    ) throws -> FestivalData {
        guard input.identity == nil || input.identity == metadata.identity else {
            throw FestivalLoadingError.wrongIdentity
        }
        if let expectedYear = Int(metadata.identity.editionID), input.festivalYear != expectedYear {
            throw FestivalLoadingError.wrongIdentity
        }
        let prepared = try ProgramPreparation.shared.prepare(
            input: input.coreProgram, zone: metadata.timeZone.identifier,
            boundaryHour: Int32(dayBoundaryHour), earliestDate: earliestProgramDate?.stableID,
            defaultLanguage: metadata.defaultContentLanguage.identifier,
            includesAreas: includesAreas, includesAdmission: includesAdmission,
            musicLinks: source.loadArtistLinks().mapValues(\.core),
            taxonomy: source.loadBrowseTaxonomy().map { $0.group() },
            supplementaryPlaces: supplementaryPlaces.map(\.core),
            planCategories: FestivalPlanCategory.allCases.map { category in
                MapCategory(id: category.rawValue,
                    title: bilingual(
                        String(localized: String.LocalizationValue(category.localizationKey), locale: Locale(identifier: "de")),
                        String(localized: String.LocalizationValue(category.localizationKey), locale: Locale(identifier: "en"))),
                    systemImageName: category.symbolName,
                    tintHex: category == .stage ? nil : "#007AFF",
                    darkTintHex: category == .stage ? nil : "#0A84FF").core
            },
            tagPolicy: eventTagPresentation.core,
            normalizeLinkKey: normalizeArtistLinkKey,
            resolveURL: { value, requiresScheme in
                guard let url = URL(string: value), !requiresScheme.boolValue || url.scheme != nil else { return nil }
                return url.absoluteString
            })
        var data = input
        data.artists = prepared.program.artists
        data.areas = prepared.program.areas
        data.stages = prepared.program.places
        data.events = prepared.program.events
        data.preparedTags = prepared.tags
        let places = data.stages
        let events = data.events
        let coordinates = Dictionary(uniqueKeysWithValues: prepared.coordinates.map {
                (FestivalPlaceID(coreID: $0.placeKey), $0.coordinate.native)
            })
        let catalogs = ProgramCatalogs.shared.build(
            prepared: prepared, matrix: data.walkingDistanceMatrix,
            supplementary: supplementaryPlaces.map(\.core),
            similarities: data.artistSimilarities.map {
                $0.similarArtistIDsByArtistID.map {
                    SimilarArtistIDs(artistID: Int64($0.key), similarIDs: KotlinCore.ids($0.value))
                }
            },
            includesAreas: includesAreas, includesAdmission: includesAdmission,
            automaticPlanning: offersAutomaticPlanning)
        let categories = prepared.mapCategories
        let assignments = Dictionary(
            uniqueKeysWithValues: prepared.mapAssignments.map {
                (FestivalPlaceID(coreID: $0.key), $0.value)
            })
        var maps = [FestivalMap]()
        if !coordinates.isEmpty {
            maps.append(
                FestivalMap(
                    id: "geographic", title: bilingual("Karte", "Map"),
                    content: .geographic(coordinates: coordinates)))
        }
        var sitePlan: FeatureAvailability<any FestivalSitePlanProviding> = .unsupported
        if let plan = data.sitePlan {
            do {
                guard let url = plan.resourceURL(), let document = PDFDocument(url: url),
                    let page = document.page(at: 0)
                else { throw FestivalLoadingError.unavailable }
                let bounds = page.bounds(for: .mediaBox)
                let bytes = try Data(contentsOf: url)
                let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                guard hash == plan.sourceSHA256 else { throw FestivalLoadingError.invalidSnapshot }
                let positions = Dictionary(
                    uniqueKeysWithValues: plan.locations.compactMap {
                        place -> (FestivalPlaceID, NormalizedMapPoint)? in
                        guard let point = place.point else { return nil }
                        return (
                            place.stageID.map(FestivalPlaceID.numeric) ?? .text(place.id),
                            NormalizedMapPoint(x: point.x, y: point.y)
                        )
                    })
                let title = bilingual("Geländeplan", "Site plan")
                var artwork = FestivalMapArtwork(
                    localFileURL: url, sourceURL: plan.sourceURL, format: .pdf(pageIndex: 0),
                    logicalSize: MapCanvasSize(width: bounds.width, height: bounds.height),
                    sha256: hash)
                if let background = plan.background {
                    guard let backgroundURL = background.resourceURL() else {
                        throw FestivalLoadingError.unavailable
                    }
                    let backgroundBytes = try Data(contentsOf: backgroundURL)
                    let backgroundHash = SHA256.hash(data: backgroundBytes).map {
                        String(format: "%02x", $0)
                    }.joined()
                    guard backgroundHash == background.sha256 else {
                        throw FestivalLoadingError.invalidSnapshot
                    }
                    artwork = FestivalMapArtwork(
                        localFileURL: backgroundURL, sourceURL: plan.sourceURL,
                        format: .rasterImage,
                        logicalSize: MapCanvasSize(
                            width: background.width, height: background.height),
                        sha256: backgroundHash)
                }
                maps.append(
                    FestivalMap(
                        id: "site-plan", title: title,
                        content: .illustrated(artwork: artwork, positions: positions)))
                sitePlan = .available(
                    FestivalPlanCatalog(
                        document: SitePlanDocument(
                            title: title, localFileURL: url, sourceURL: plan.sourceURL),
                        positions: positions.mapValues { SitePlanPosition(pageIndex: 0, point: $0) }
                    ))
            } catch { sitePlan = .unavailable(.loadFailed(error)) }
        }
        let features = FestivalFeatures(
            information: informationPages.isEmpty
                ? .unsupported : .available(FestivalInformationCatalog(pages: informationPages)),
            artistDetails: .available(catalogs.artists), placeDetails: .available(catalogs.places),
            eventDetails: catalogs.eventDetails.map { .available($0) } ?? input.features.eventDetails,
            admission: catalogs.admission.map { .available($0) } ?? .unsupported,
            summaries: catalogs.summaries.map { .available($0) } ?? .unsupported,
            groupings: .available(catalogs.artists),
            similarities: catalogs.similarities.map { .available($0) } ?? .unsupported,
            areas: catalogs.areas.map { .available($0) } ?? .unsupported,
            map: maps.first.map {
                .available(
                    FestivalMapCatalog(
                        maps: maps, defaultMapID: $0.id, categories: categories,
                        assignments: assignments))
            } ?? .unsupported,
            sitePlan: sitePlan,
            distances: catalogs.distances.map { .available($0) } ?? .unsupported,
            automaticPlanning: catalogs.planning.map { .available($0) } ?? .unsupported)
        var preparedData = data
        preparedData.identity = metadata.identity
        preparedData.metadata = metadata
        preparedData.days = prepared.days.map(\.native)
        preparedData.features = features
        preparedData.provenance = FestivalDataProvenance(
            source: dataSource, dataUpdatedAt: updatedAt,
            refreshCheckedAt: dataSource == .remote ? updatedAt : nil,
            omittedRecordCount: data.omittedRecordCount)
        preparedData.stages = places
        preparedData.events = events
        return try preparedData.prepared(using: metadata)
    }
}

typealias FestivalSupplementaryPlace = ProgramSupplementaryPlace
extension ProgramSupplementaryPlace: @unchecked @retroactive Sendable {
    var core: ProgramSupplementaryPlace { self }
}
