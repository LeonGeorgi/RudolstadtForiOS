import Foundation
import PDFKit
import CryptoKit

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

    func loadCachedProgram() async throws -> FestivalData? {
        try Task.checkCancellation()
        switch source.loadCachedData() {
        case .loaded(let data): return try prepare(data, source: source.isCacheStale ? .staleCache : .cache, updatedAt: source.cacheModificationDate)
        case .stale(let data): return try prepare(data, source: .staleCache, updatedAt: source.cacheModificationDate)
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
        return try prepare(data, source: bundledSource == .bundledBackup ? .remote : bundledSource,
                            updatedAt: bundledSource == .bundledBackup ? Date.now : nil)
    }

    func deleteCache() async throws {
        guard source.deleteCache() else { throw FestivalLoadingError.cacheDeletionFailed }
    }

    func prepare(_ input: FestivalData, source dataSource: FestivalDataSource,
                  updatedAt: Date? = nil) throws -> FestivalData {
        guard input.identity == nil || input.identity == metadata.identity else { throw FestivalLoadingError.wrongIdentity }
        var data = input
        let musicLinks = source.loadArtistLinks()
        data.artists = data.artists.map { original in
            var artist = original
            if let music = musicLinks[artist.name] ?? musicLinks[normalizeArtistLinkKey(artist.name)] {
                for (id, value) in [("spotify", music.spotifyURL), ("appleMusic", music.appleMusicURL)] {
                    if let value, let url = URL(string: value), url.scheme != nil {
                        artist.additionalLinks.append(FestivalLink(id: id, title: LocalizedText(values: [LanguageTag("en"): id]),
                            destination: url, openingMode: .externalBrowser))
                    }
                }
                switch music.appleMusicPreviewSelection {
                case .automatic: break
                case .disabled: artist.musicPreview = .disabled
                case .songURL(let value): artist.musicPreview = URL(string: value).map(FestivalMusicPreview.songURL) ?? .disabled
                }
            }
            return artist
        }
        if let expectedYear = Int(metadata.identity.editionID), data.festivalYear != expectedYear {
            throw FestivalLoadingError.wrongIdentity
        }
        let calendar = metadata.calendar
        let validStages = data.stages.filter(\.isMetadataAvailable)
        var places = validStages
        places += supplementaryPlaces.map { item in
            var place = item.place
            place.localizedDescriptions = item.details.description
            place.latitude = item.coordinate?.latitude ?? .nan
            place.longitude = item.coordinate?.longitude ?? .nan
            place.locationIsApproximate = item.coordinate?.isApproximate ?? false
            place.mapCategory = item.category
            return place
        }
        var extraPlaces = [FestivalPlaceID: FestivalPlanLocation]()
        for place in data.sitePlan?.locations ?? [] where place.stageID == nil {
            let id = FestivalPlaceID.text(place.id)
            extraPlaces[id] = place
            places.append(Stage(id: id, name: bilingual(place.nameDE, place.nameEN), reference: place.reference))
        }
        var daysByID = [String: FestivalDay]()
        var events = [Event]()
        for event in data.events {
            var day: FestivalDay?
            if let date = event.startDate ?? event.knownDate {
                let logicalDate: Date
                if event.startDate != nil, calendar.component(.hour, from: date) < dayBoundaryHour {
                    logicalDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date
                } else { logicalDate = date }
                let local = FestivalCalendarDate(logicalDate, calendar: calendar)
                if let midnight = local.date(in: calendar),
                   earliestProgramDate?.date(in: calendar).map({ midnight >= $0 }) != false,
                   let start = calendar.date(bySettingHour: dayBoundaryHour, minute: 0, second: 0, of: midnight),
                   let end = calendar.date(byAdding: .day, value: 1, to: start) {
                    day = FestivalDay(id: local.stableID, date: local, title: nil,
                                      interval: DateInterval(start: start, end: end))
                    daysByID[local.stableID] = day
                }
            }
            var preparedEvent = event
            preparedEvent.programDay = day
            preparedEvent.timeZone = metadata.timeZone
            events.append(preparedEvent)
        }
        events = FestivalDurationResolver.resolve(events)
        let taxonomy = source.loadBrowseTaxonomy()
        let artistKinds = ArtistType.allCases.map {
            ArtistGroup(id: String($0.rawValue), title: bilingual($0.germanName, $0.englishName))
        }
        var groupings = [ArtistGrouping(id: "artist-kind", title: bilingual("Künstlerarten", "Artist types"), groups: artistKinds)]
        if !taxonomy.isEmpty {
            groupings.append(ArtistGrouping(id: "genre", title: bilingual("Genres", "Genres"), groups: taxonomy.map {
                ArtistGroup(id: $0.id, title: bilingual($0.labelDE, $0.labelEN))
            }))
        }
        let artists = FestivalArtistCatalog(artists: Dictionary(uniqueKeysWithValues: data.artists.map { ($0.id, $0) }),
                                           groupings: groupings)
        let palette: [Int: (String, String)] = [1: ("#BA5661", "#DA8188"), 2: ("#078393", "#4EABBA"), 3: ("#64619B", "#9392C8")]
        let admission = includesAdmission ? StageType.allCases.filter { $0 != .unknown }.map { type in
            FestivalAdmissionCategory(id: String(type.rawValue), title: bilingual(type.germanName, type.englishName),
                description: nil, tintHex: palette[type.rawValue]?.0, darkTintHex: palette[type.rawValue]?.1)
        } : []
        var placeCatalog = FestivalPlaceCatalog(stages: Dictionary(uniqueKeysWithValues: validStages.map { ($0.id, $0) }),
            extraPlaces: extraPlaces,
            areas: includesAreas ? data.areas : [],
            categories: admission, eventPlaces: Dictionary(uniqueKeysWithValues: events.compactMap { event in
                event.placeID.map { (event.id, $0) }
            }))
        placeCatalog.supplementaryDetails = Dictionary(uniqueKeysWithValues: supplementaryPlaces.map { ($0.place.id, $0.details) })
        var coordinates = [FestivalPlaceID: FestivalCoordinate]()
        for stage in validStages where stage.hasLocation {
            coordinates[stage.id] = FestivalCoordinate(latitude: stage.latitude, longitude: stage.longitude,
                isApproximate: stage.locationIsApproximate, sourceURL: data.sitePlan?.coordinateSourceURL)
        }
        for (id, place) in extraPlaces { coordinates[id] = place.coordinate }
        for place in supplementaryPlaces { coordinates[place.place.id] = place.coordinate }
        var categories: [MapCategory]
        var assignments = [FestivalPlaceID: String]()
        if let plan = data.sitePlan {
            categories = FestivalPlanCategory.allCases.map { category in
                MapCategory(id: category.rawValue,
                    title: bilingual(String(localized: String.LocalizationValue(category.localizationKey), locale: Locale(identifier: "de")),
                                     String(localized: String.LocalizationValue(category.localizationKey), locale: Locale(identifier: "en"))),
                    systemImageName: category.symbolName, tintHex: category == .stage ? nil : "#007AFF",
                    darkTintHex: category == .stage ? nil : "#0A84FF")
            }
            for location in plan.locations {
                let id = location.stageID.map(FestivalPlaceID.numeric) ?? .text(location.id)
                assignments[id] = location.category.rawValue
            }
        } else {
            categories = admission.map { MapCategory(id: $0.id, title: $0.title, systemImageName: "music.mic", tintHex: $0.tintHex, darkTintHex: $0.darkTintHex) }
            for stage in validStages { assignments[stage.id] = String(stage.stageType.rawValue) }
        }
        for place in supplementaryPlaces {
            if let category = place.category {
                if !categories.contains(where: { $0.id == category.id }) { categories.append(category) }
                assignments[place.place.id] = category.id
            }
        }
        var maps = [FestivalMap]()
        if !coordinates.isEmpty {
            maps.append(FestivalMap(id: "geographic", title: bilingual("Karte", "Map"), content: .geographic(coordinates: coordinates)))
        }
        var sitePlan: FeatureAvailability<any FestivalSitePlanProviding> = .unsupported
        if let plan = data.sitePlan {
            do {
            guard let url = plan.resourceURL(), let document = PDFDocument(url: url), let page = document.page(at: 0)
            else { throw FestivalLoadingError.unavailable }
            let bounds = page.bounds(for: .mediaBox)
            let bytes = try Data(contentsOf: url)
            let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            guard hash == plan.sourceSHA256 else { throw FestivalLoadingError.invalidSnapshot }
            let positions = Dictionary(uniqueKeysWithValues: plan.locations.compactMap { place -> (FestivalPlaceID, NormalizedMapPoint)? in
                guard let point = place.point else { return nil }
                return (place.stageID.map(FestivalPlaceID.numeric) ?? .text(place.id), NormalizedMapPoint(x: point.x, y: point.y))
            })
            let title = bilingual("Geländeplan", "Site plan")
            var artwork = FestivalMapArtwork(localFileURL: url, sourceURL: plan.sourceURL, format: .pdf(pageIndex: 0),
                logicalSize: MapCanvasSize(width: bounds.width, height: bounds.height), sha256: hash)
            if let background = plan.background {
                guard let backgroundURL = background.resourceURL() else { throw FestivalLoadingError.unavailable }
                let backgroundBytes = try Data(contentsOf: backgroundURL)
                let backgroundHash = SHA256.hash(data: backgroundBytes).map { String(format: "%02x", $0) }.joined()
                guard backgroundHash == background.sha256 else { throw FestivalLoadingError.invalidSnapshot }
                artwork = FestivalMapArtwork(localFileURL: backgroundURL, sourceURL: plan.sourceURL, format: .rasterImage,
                    logicalSize: MapCanvasSize(width: background.width, height: background.height), sha256: backgroundHash)
            }
            maps.append(FestivalMap(id: "site-plan", title: title, content: .illustrated(artwork: artwork, positions: positions)))
            sitePlan = .available(FestivalPlanCatalog(document: SitePlanDocument(title: title, localFileURL: url, sourceURL: plan.sourceURL),
                positions: positions.mapValues { SitePlanPosition(pageIndex: 0, point: $0) }))
            } catch { sitePlan = .unavailable(.loadFailed(error)) }
        }
        var transferLocations = validStages.map(StageTransferLocation.init(stage:))
        let stageIDs = Set(validStages.map(\.id))
        transferLocations += coordinates.filter { !stageIDs.contains($0.key) }.map {
            StageTransferLocation(stageID: $0.key, latitude: $0.value.latitude, longitude: $0.value.longitude)
        }
        let distances = FestivalDistanceCatalog(estimator: StageTransferEstimator(locations: transferLocations, matrix: data.walkingDistanceMatrix),
            coordinates: coordinates, knownPlaceIDs: Set(places.map(\.id)),
            eligibleEventIDs: Set(events.filter { $0.startDate != nil && $0.placeID != nil && $0.duration != nil }.map(\.id)))
        let features = FestivalFeatures(
            information: informationPages.isEmpty ? .unsupported : .available(FestivalInformationCatalog(pages: informationPages)),
            artistDetails: .available(artists), placeDetails: .available(placeCatalog),
            eventDetails: .available(FestivalEventCatalog(events: Dictionary(uniqueKeysWithValues: data.events.map { ($0.id, $0) }),
                tags: eventTagPresentation.tags(in: data.events))),
            admission: includesAdmission ? .available(placeCatalog) : .unsupported,
            summaries: data.artists.contains(where: { !$0.localizedSummaries.isEmpty }) ? .available(artists) : .unsupported,
            groupings: .available(artists),
            similarities: data.artistSimilarities.map { .available(FestivalSimilarityProvider(values: $0.similarArtistIDsByArtistID)) } ?? .unsupported,
            areas: includesAreas ? .available(placeCatalog) : .unsupported,
            map: maps.first.map { .available(FestivalMapCatalog(maps: maps, defaultMapID: $0.id, categories: categories, assignments: assignments)) } ?? .unsupported,
            sitePlan: sitePlan, distances: coordinates.isEmpty && data.walkingDistanceMatrix.stageIDs.isEmpty ? .unsupported : .available(distances),
            automaticPlanning: offersAutomaticPlanning ? .available(distances) : .unsupported)
        var preparedData = data
        preparedData.identity = metadata.identity
        preparedData.metadata = metadata
        preparedData.days = daysByID.values.sorted { $0.interval.start < $1.interval.start }
        preparedData.features = features
        preparedData.provenance = FestivalDataProvenance(source: dataSource, dataUpdatedAt: updatedAt,
                refreshCheckedAt: dataSource == .remote ? updatedAt : nil, omittedRecordCount: data.omittedRecordCount)
        preparedData.stages = places
        preparedData.events = events
        return try preparedData.prepared(using: metadata)
    }
}


struct FestivalSupplementaryPlace: Sendable {
    let place: Stage
    let details: FestivalPlaceDetails
    let coordinate: FestivalCoordinate?
    let category: MapCategory?
}
