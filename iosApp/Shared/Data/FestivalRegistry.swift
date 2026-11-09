import Foundation
import RudolstadtCore

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
                archiveFestivalYear: metadata.editionKind == .archive ? Int(metadata.identity.editionID) : nil,
                userDataPolicy: metadata.userDataPolicy)
        }
        let policy = metadata.userDataPolicy
        return FestivalProfileStore(cloudSyncEnabled: false,
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
        let archiveYears = KotlinCore.bridge.archiveYears().map(\.intValue)
        let archives = archiveYears.map {
            rudolstadt(year: $0, source: RudolstadtArchiveDataProvider(year: $0), archive: true)
        }
        let definition: CoreFestivalDefinition = KotlinCore.bridge.ludwigsburgDefinition()
        let ludwigsburg = FestivalSourceAdapter(
            metadata: definition.metadata,
            services: FestivalServices(), loadingStrategy: .bundledOnly, source: LudwigsburgFestivalDataProvider(), bundledSource: .bundledExperiment,
            dayBoundaryHour: Int(definition.dayBoundaryHour),
            includesAreas: definition.includesAreas,
            includesAdmission: definition.includesAdmission,
            offersAutomaticPlanning: definition.automaticPlanning, informationPages: [])
        var adapters: [any FestivalAdapter] = [current] + archives + [ludwigsburg]
        #if DEBUG
        adapters.append(FantasyFestivalDataProvider.makeAdapter())
        #endif
        do { return try FestivalCatalog(adapters: adapters, defaultIdentity: current.metadata.identity) }
        catch { preconditionFailure("Invalid festival registration: \(error)") }
    }()

    static func rudolstadt(year: Int, source: any FestivalDataProviding, archive: Bool, includesSupplementaryInformation: Bool = true) -> FestivalSourceAdapter {
        let definition: CoreFestivalDefinition = KotlinCore.bridge.rudolstadtDefinition(
            year: Int32(year), archive: archive)
        return FestivalSourceAdapter(
            metadata: definition.metadata,
            services: FestivalServices(publicLinks: .available(RudolstadtPublicLinks(year: year))),
            loadingStrategy: archive ? .bundledOnly : .refreshable, source: source, bundledSource: archive ? .bundledArchive : .bundledBackup,
            dayBoundaryHour: Int(definition.dayBoundaryHour),
            includesAreas: definition.includesAreas,
            includesAdmission: definition.includesAdmission,
            offersAutomaticPlanning: definition.automaticPlanning, informationPages: archive || !includesSupplementaryInformation ? [] : travelPages,
            earliestProgramDate: definition.earliestProgramDate,
            eventTagPresentation: rudolstadtEventTags,
            supplementaryPlaces: archive || !includesSupplementaryInformation ? [] : parkingPlaces)
    }

    private static func localized(_ key: String, _ language: String) -> String {
        String(localized: String.LocalizationValue(key), locale: Locale(identifier: language))
    }
    private static var rudolstadtEventTags: FestivalEventTagPresentation {
        RudolstadtContent.shared.eventTags()
    }
    private static var parkingPlaces: [FestivalSupplementaryPlace] {
        // SF Symbols are selected here; coordinates, text keys and categories are shared.
        RudolstadtContent.shared.parking(localize: localized).map { place in
            let category = place.category.map {
                ProgramCategory(
                    categoryID: $0.categoryID, titles: $0.titles,
                    descriptionTexts: $0.descriptionTexts,
                    systemImageName: "parkingsign.circle", tintHex: $0.tintHex,
                    darkTintHex: $0.darkTintHex)
            }
            return ProgramSupplementaryPlace(
                place: place.place, descriptions: place.descriptions,
                coordinate: place.coordinate, category: category, links: place.links)
        }
    }
    private static var travelPages: [FestivalInformationPage] {
        RudolstadtContent.shared.information(localize: localized).map { page in
            let content: FestivalInformationContent
            if let article = page.article {
                content = .article(article)
            } else if let value = page.webURL, let url = URL(string: value) {
                content = .webPage(url)
            } else {
                preconditionFailure("Invalid bundled information page")
            }
            return FestivalInformationPage(
                id: page.pageID, title: LocalizedText(core: page.titles), content: content,
                systemImageName: page.iconKind, links: page.links.compactMap(\.native),
                relatedPlaceIDs: page.relatedPlaces.map(FestivalPlaceID.init(coreID:)),
                sourceURL: nil,
                updatedAt: nil)
        }
    }

}

struct RudolstadtPublicLinks: FestivalPublicLinksProviding {
    let year: Int
    func url(for destination: FestivalDestination) -> URL? {
        if case .artist(let id, let eventID) = destination {
            return ArtistShareLink(year: year, artistID: id, eventID: eventID).url
        }
        return nil
    }
    func destination(for url: URL) -> FestivalDestination? {
        guard let link = ArtistShareLink(url: url), link.year == year else { return nil }
        return .artist(link.artistID, highlightedEventID: link.eventID)
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
    var supportsFirebaseFriends: Bool {
        usesLiveServices || (identity.festivalID == Self.current.identity.festivalID && isArchive)
    }
}
