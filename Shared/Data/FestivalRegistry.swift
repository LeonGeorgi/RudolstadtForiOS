import Foundation

/// The only registration point for bundled festival integrations.
enum FestivalRegistry {
    static let legacyProfileNamespaces = [
        FestivalIdentity(festivalID: "ludwigsburg", editionID: "2026"): "ludwigsburg-2026"
    ]

    @MainActor
    static func makeProfileStore(metadata: FestivalMetadata, defaults: UserDefaults) -> FestivalProfileStore {
        let isRudolstadt = metadata.identity.festivalID == FestivalEdition.current.identity.festivalID
        if metadata.identity == FestivalEdition.current.identity || (isRudolstadt && metadata.editionKind == .archive) {
            return FestivalProfileStore(userDefaults: defaults,
                readOnlyFestivalYear: metadata.editionKind == .archive ? Int(metadata.identity.editionID) : nil,
                userDataPolicy: metadata.userDataPolicy)
        }
        let policy = metadata.userDataPolicy
        return FestivalProfileStore(cloudKitEnabled: false,
            persistence: UserDefaultsFestivalProfilePersistence(userDefaults: defaults,
                festivalYear: Int(metadata.identity.editionID) ?? 0,
                isReadOnly: policy.savedEvents != .editable && policy.artistRatings != .editable && policy.artistNotes != .editable,
                namespace: profileNamespace(for: metadata.identity, defaults: defaults)),
            userDataPolicy: policy)
    }

    private static func profileNamespace(for identity: FestivalIdentity, defaults: UserDefaults) -> String {
        let canonical = identity.storageKey
        let keys = defaults.dictionaryRepresentation().keys
        if keys.contains(where: { $0.hasPrefix("festival/" + canonical + "/") }) { return canonical }
        if let legacy = FestivalRegistry.legacyProfileNamespaces[identity],
           keys.contains(where: { $0.hasPrefix("festival/" + legacy + "/") }) { return legacy }
        return canonical
    }

    static let catalog: FestivalCatalog = {
        let cacheURL: URL
        do {
            cacheURL = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                                   appropriateFor: nil, create: true)
        } catch { preconditionFailure("Cannot resolve festival cache: \(error)") }
        let cache = DataLoader(cacheURL: cacheURL)
        let current = rudolstadt(year: FestivalConfiguration.year, source: RudolstadtFestivalDataProvider(cache: cache), archive: false)
        let archives = [2025, 2024, 2023, 2022, 2019].map {
            rudolstadt(year: $0, source: RudolstadtArchiveDataProvider(year: $0), archive: true)
        }
        let ludwigsburg = FestivalSourceAdapter(
            metadata: FestivalMetadata(identity: FestivalIdentity(festivalID: "ludwigsburg", editionID: "2026"),
                name: bilingual("Straßenmusikfestival Ludwigsburg", "Ludwigsburg Street Music Festival"),
                editionLabel: bilingual("2026", "2026"), editionKind: .experimental, dateRange: nil,
                timeZone: FestivalConfiguration.timeZone, defaultContentLanguage: LanguageTag("de"),
                officialLinks: [link("website", "Website", "Website", "https://strassenmusikfestival.de")],
                presentation: FestivalPresentation(logoURL: nil, accentColorHex: nil),
                notices: [FestivalNotice(id: "experimental", severity: .warning,
                    title: bilingual("Testfestival · Straßenmusikfestival Ludwigsburg 2026", "Trial festival · Ludwigsburg Street Music Festival 2026"), message: nil, links: [])],
                userDataPolicy: FestivalUserDataPolicy(savedEvents: .editable, artistRatings: .editable, artistNotes: .editable)),
            services: FestivalServices(), loadingStrategy: .bundledOnly, source: LudwigsburgFestivalDataProvider(), bundledSource: .bundledExperiment,
            dayBoundaryHour: 0, includesAreas: false, includesAdmission: false,
            offersAutomaticPlanning: false, informationPages: [])
        do { return try FestivalCatalog(adapters: [current] + archives + [ludwigsburg], defaultIdentity: current.metadata.identity) }
        catch { preconditionFailure("Invalid festival registration: \(error)") }
    }()

    static func rudolstadt(year: Int, source: any FestivalDataProviding, archive: Bool, includesSupplementaryInformation: Bool = true) -> FestivalSourceAdapter {
        let access: FestivalUserDataAccess = archive ? .readOnly : .editable
        let identity = FestivalIdentity(festivalID: "rudolstadt", editionID: String(year))
        return FestivalSourceAdapter(
            metadata: FestivalMetadata(identity: identity, name: bilingual("Rudolstadt", "Rudolstadt"),
                editionLabel: bilingual(String(year), String(year)), editionKind: archive ? .archive : .regular,
                dateRange: nil, timeZone: FestivalConfiguration.timeZone, defaultContentLanguage: LanguageTag("de"),
                officialLinks: [link("website", "Offizielle Website", "Official website", "https://www.rudolstadt-festival.de"),
                    link("official-app", "Offizielle App", "Official app", "https://apps.apple.com/app/id534902145")],
                presentation: FestivalPresentation(logoURL: nil, accentColorHex: nil),
                notices: archive ? [FestivalNotice(id: "archive", severity: .warning,
                    title: bilingual("Archiv · Rudolstadt \(year)", "Archive · Rudolstadt \(year)"), message: nil, links: [])] : [],
                userDataPolicy: FestivalUserDataPolicy(savedEvents: access, artistRatings: access, artistNotes: access)),
            services: FestivalServices(publicLinks: .available(RudolstadtPublicLinks(year: year))),
            loadingStrategy: archive ? .bundledOnly : .refreshable, source: source, bundledSource: archive ? .bundledArchive : .bundledBackup,
            dayBoundaryHour: 5, includesAreas: true, includesAdmission: true,
            offersAutomaticPlanning: !archive, informationPages: archive || !includesSupplementaryInformation ? [] : travelPages,
            earliestProgramDate: year == 2023 ? FestivalCalendarDate(year: 2023, month: 7, day: 6) : nil,
            eventTagPresentation: rudolstadtEventTags,
            supplementaryPlaces: archive || !includesSupplementaryInformation ? [] : parkingPlaces)
    }

    private static func link(_ id: String, _ de: String, _ en: String, _ url: String) -> FestivalLink {
        guard let url = URL(string: url) else { preconditionFailure("Invalid registered URL") }
        return FestivalLink(id: id, title: bilingual(de, en), destination: url, openingMode: .externalBrowser)
    }

    private static func localized(_ key: String, _ language: String) -> String {
        String(localized: String.LocalizationValue(key), locale: Locale(identifier: language))
    }

    private static var rudolstadtEventTags: FestivalEventTagPresentation {
        FestivalEventTagPresentation(discoveryOrder: ["Workshop", "Tanzworkshop", "Vortrag", "Mitmachtanz", "Tanzabend",
            "Kindertanz", "Film", "Ausstellung", "Länderschwerpunkt", "EBU", "RUTH"],
            hiddenTimelineNames: ["Bühne", "Straßenmusik"],
            titleOverrides: ["Mitmachtanz": bilingual(localized("program.discovery.dance-along", "de"), localized("program.discovery.dance-along", "en"))],
            introductions: Dictionary(uniqueKeysWithValues: [("Länderschwerpunkt", "country"), ("EBU", "ebu"), ("RUTH", "ruth")].map {
                ($0.0, bilingual(localized("program.discovery." + $0.1 + ".intro", "de"), localized("program.discovery." + $0.1 + ".intro", "en")))
            }))
    }

    private static var parkingPlaces: [FestivalSupplementaryPlace] {
        let category = MapCategory(id: "parking", title: bilingual("Parkplätze", "Parking"), systemImageName: "parkingsign.circle", tintHex: nil)
        return [
            ("parking-raiffeisen", "raiffeisenstraße", 50.723778, 11.364995),
            ("parking-correns", "erich-correns-ring", 50.701339, 11.317835)
        ].map { id, key, latitude, longitude in
            let title = "park_and_ride.parking." + key + ".title"
            let description = "park_and_ride.parking." + key + ".description"
            return FestivalSupplementaryPlace(place: Stage(id: .text(id),
                name: bilingual(localized(title, "de"), localized(title, "en")), reference: nil),
                details: FestivalPlaceDetails(description: FestivalContent(text: bilingual(
                    localized(description, "de"), localized(description, "en")), format: .plainText), links: []),
                coordinate: FestivalCoordinate(latitude: latitude, longitude: longitude, isApproximate: false, sourceURL: nil), category: category)
        }
    }

    private static var travelPages: [FestivalInformationPage] {
        let parking = FestivalInformationPage(id: "park-and-ride", title: bilingual("Park & Ride", "Park & Ride"),
            content: .article(FestivalContent(text: bilingual(
                localized("park_and_ride.navi.description", "de"),
                localized("park_and_ride.navi.description", "en")), format: .plainText)),
            systemImageName: "car", links: [link("source", "Offizielle Informationen", "Official information", "https://www.rudolstadt-festival.de")],
            relatedPlaceIDs: [.text("parking-raiffeisen"), .text("parking-correns")], sourceURL: nil, updatedAt: nil)
        let bus = FestivalInformationPage(id: "bus", title: bilingual("Bus", "Bus"),
            content: .webPage(URL(string: "https://auskunft.kombus-online.eu/widget/tff/?tpl=165D206D86C")!),
            systemImageName: "bus", links: [], relatedPlaceIDs: [], sourceURL: nil, updatedAt: nil)
        return [parking, bus]
    }
}

struct RudolstadtPublicLinks: FestivalPublicLinksProviding {
    let year: Int
    func url(for destination: FestivalDestination) -> URL? {
        if case .artist(let id) = destination { return ArtistShareLink(year: year, artistID: id).url }
        return nil
    }
    func destination(for url: URL) -> FestivalDestination? {
        guard let link = ArtistShareLink(url: url), link.year == year else { return nil }
        return .artist(link.artistID)
    }
}

// Compatibility names for saved selection and the existing Rudolstadt sync composition.
extension FestivalEdition {
    static let current = FestivalEdition(identity: FestivalIdentity(festivalID: "rudolstadt", editionID: String(FestivalConfiguration.year)))
    static let ludwigsburg2026 = FestivalEdition(identity: FestivalIdentity(festivalID: "ludwigsburg", editionID: "2026"))
    static let archive2025 = archive(2025)
    static let archive2024 = archive(2024)
    static let archive2023 = archive(2023)
    static let archive2022 = archive(2022)
    static let archive2019 = archive(2019)
    private static func archive(_ year: Int) -> FestivalEdition {
        FestivalEdition(identity: FestivalIdentity(festivalID: "rudolstadt", editionID: String(year)))
    }
    var usesLiveServices: Bool { self == .current }
}
