import SwiftUI

@MainActor
final class AppServices {
    let dataStore: DataStore
    private var editionDataStores: [FestivalEdition: DataStore] = [:]
    let userSettings: UserSettings
    let festivalProfileStore: FestivalProfileStore
    let iapManager: IAPManager
    let newsRefresher: NewsRefresher
#if os(iOS)
    let watchSnapshotCoordinator: WatchSnapshotCoordinator?
#endif

    init(
        userSettings: UserSettings? = nil,
        festivalProfileStore: FestivalProfileStore? = nil,
        festivalAdapter: (any FestivalAdapter)? = nil
    ) {
        let userSettings = userSettings ?? UserSettings()
        if ScreenshotRuntime.isEnabled {
            ScreenshotRuntime.configure(userSettings: userSettings)
        }

        let resolvedProfileStore: FestivalProfileStore
        if ScreenshotRuntime.isEnabled {
            let suiteName = "AppStoreScreenshots"
            let screenshotDefaults =
                UserDefaults(suiteName: suiteName) ?? .standard
            screenshotDefaults.removePersistentDomain(forName: suiteName)
            resolvedProfileStore = FestivalProfileStore(
                userDefaults: screenshotDefaults,
                cloudKitEnabled: false
            )
        } else {
            resolvedProfileStore = festivalProfileStore ?? FestivalProfileStore(userDefaults: userSettings.userDefaults)
        }
        let newsService = NewsService(userSettings: userSettings)
        let recommendationService = RecommendationService()
        let base = festivalAdapter ?? FestivalRegistry.catalog.adapter(for: FestivalEdition.current.identity)
        let currentAdapter: (any FestivalAdapter)?
        if festivalAdapter == nil, var programAdapter = base as? FestivalSourceAdapter {
            programAdapter.services = FestivalServices(news: .available(RudolstadtNewsAdapter(service: newsService,
                loader: DataStore.makeDefaultDataLoader(), identity: programAdapter.metadata.identity)),
                publicLinks: programAdapter.services.publicLinks)
            currentAdapter = programAdapter
        } else { currentAdapter = base }
        let dataStore = DataStore(
            festivalProfileStore: resolvedProfileStore,
            userSettings: userSettings,
            recommendationService: recommendationService,
            festivalAdapter: currentAdapter
        )
        if ScreenshotRuntime.isEnabled {
            ScreenshotRuntime.configure(
                profile: resolvedProfileStore,
                dataStore: dataStore
            )
        }

        self.userSettings = userSettings
        self.festivalProfileStore = resolvedProfileStore
        self.dataStore = dataStore
        self.iapManager = IAPManager()
        self.newsRefresher = NewsRefresher(newsService: newsService)
#if os(iOS)
        self.watchSnapshotCoordinator = WatchSnapshotTransportRuntime.isEnabled
            ? WatchSnapshotCoordinator(
                dataStore: dataStore,
                profileStore: resolvedProfileStore
            )
            : nil
#endif

        resolvedProfileStore.onChange(of: .recommendationInputs) { [weak dataStore] in
            dataStore?.scheduleRecommendationRefresh()
        }

#if os(iOS)
        CloudKitShareAcceptanceController.shared.profileStore = resolvedProfileStore
#endif
    }

    func dataStore(for edition: FestivalEdition) -> DataStore {
        guard !edition.usesLiveServices else { return dataStore }
        if let store = editionDataStores[edition] { return store }
        let store = DataStore(userSettings: userSettings, edition: edition, loadInitialData: false)
        store.festivalProfileStore.onChange(of: .recommendationInputs) { [weak store] in
            store?.scheduleRecommendationRefresh()
        }
        editionDataStores[edition] = store
        return store
    }

    func refreshOnForeground() async {
        async let cloudRefresh: Void =
            festivalProfileStore.refreshFromCloud(reason: "foreground")
        async let appRefresh: Void = dataStore(for: userSettings.festivalEdition).refreshOnAppActive()
        _ = await (cloudRefresh, appRefresh)
    }
}

enum ScreenshotRuntime {
    static let launchArgument = "-screenshotMode"
    static let appearanceLaunchArgument = "-screenshotAppearance"

    static let referenceDate: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar.date(
            from: DateComponents(
                year: DataStore.year,
                month: 7,
                day: 4,
                hour: 12
            )
        )!
    }()

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static var appearance: String? {
        let arguments = ProcessInfo.processInfo.arguments
        if let argumentIndex = arguments.firstIndex(of: appearanceLaunchArgument) {
            let valueIndex = arguments.index(after: argumentIndex)
            if valueIndex < arguments.endIndex {
                return arguments[valueIndex]
            }
        }

        return ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_APPEARANCE"]
    }

    @MainActor
    static func configure(userSettings: UserSettings) {
        userSettings.festivalEdition = .current
        userSettings.scheduleDisplayMode = .timeline
        userSettings.scheduleDaySelectionStyle = .toolbarMenu
        userSettings.artistViewType = 1
        userSettings.artistGridColumnCount = ArtistGridDensity.comfortable.rawValue
        userSettings.scheduleFilterType = 0
        userSettings.readNews = []
        userSettings.oldNews = []
    }

    @MainActor
    static func configure(
        profile: FestivalProfileStore,
        dataStore: DataStore
    ) {
        guard case .success(let festivalData) = dataStore.festivalData else {
            return
        }

        func preferredEvent(forArtistNamed artistName: String) -> Event? {
            festivalData.events
                .filter { $0.artist.name == artistName }
                .min { first, second in
                    let firstDayPriority = first.festivalDay == 5 ? 0 : 1
                    let secondDayPriority = second.festivalDay == 5 ? 0 : 1
                    if firstDayPriority != secondDayPriority {
                        return firstDayPriority < secondDayPriority
                    }
                    return Event.precedes(first, second)
                }
        }

        let savedScheduleEvents = [
            "Dota Kehr",
            "Throes + The Shine"
        ].compactMap(preferredEvent(forArtistNamed:))

        let likedScheduleArtists = [
            "AltBadSeer Musi",
            "Adaya",
            "La Niña"
        ].compactMap { artistName in
            festivalData.artists.first { $0.name == artistName }
        }

        let friendScheduleEvents = [
            "Zgarda",
            "Joce Reyome",
            "Baba Yaga"
        ].compactMap(preferredEvent(forArtistNamed:))

        if let featuredArtist = festivalData.artists.first(where: {
            $0.name == "Duo Ruut"
        }) {
            profile.setArtistRating(for: featuredArtist, rating: 3)
        }

        for likedScheduleArtist in likedScheduleArtists {
            profile.setArtistRating(for: likedScheduleArtist, rating: 3)
        }

        for savedScheduleEvent in savedScheduleEvents {
            profile.toggleSavedEvent(savedScheduleEvent)
        }

        let accessoryArtistIDs = Set([302, 336, 194])
        let firstDayEvents = festivalData.events.filter { event in
            event.festivalDay == 2 && accessoryArtistIDs.contains(event.artist.id)
        }

        for event in firstDayEvents {
            profile.toggleSavedEvent(event)
        }

        if let firstEvent = firstDayEvents.first {
            profile.setArtistRating(for: firstEvent.artist, rating: 3)
        }
        if firstDayEvents.count > 1 {
            profile.setArtistRating(for: firstDayEvents[1].artist, rating: 1)
        }

        profile.updateBadge(name: "Leon", colorHex: "#8E3A9C")
        profile.syncStore.iCloudStatus = .available
        profile.syncStore.acceptedShareParticipantCount = 2

        func firstEventIDs(for artistNames: [String]) -> [Int] {
            artistNames.compactMap { artistName in
                festivalData.events
                    .filter { $0.artist.name == artistName }
                    .min(by: Event.precedes)?
                    .id
            }
        }

        func friendRatings(for artistNames: [String], rating: Int) -> [FestivalArtistPreference] {
            artistNames.compactMap { name in
                festivalData.artists.first { $0.name == name }.map {
                    FestivalArtistPreference(artistID: $0.id, rating: rating, iconName: nil)
                }
            }
        }

        profile.friendProfilesStore.viewModel.restore(profiles: [
            SharedFestivalProfile(
                id: "screenshot-friend-aya",
                title: "Aya's Festival",
                ownerName: "Aya",
                badgeName: "Aya",
                badgeColorHex: "#3D78E0",
                festivalYear: DataStore.year,
                savedEventIDs: firstEventIDs(
                    for: ["Kitty, Daisy & Lewis", "RIAN", "Raquel Martins"]
                ) + friendScheduleEvents.map(\.id),
                artistPreferences: friendRatings(for: ["Duo Ruut", "Adaya"], rating: 2)
            ),
            SharedFestivalProfile(
                id: "screenshot-friend-mika",
                title: "Mika's Festival",
                ownerName: "Mika",
                badgeName: "Mika",
                badgeColorHex: "#B54E9B",
                festivalYear: DataStore.year,
                savedEventIDs: firstEventIDs(
                    for: ["RIAN", "Sara Curruchich", "Raquel Martins"]
                ),
                artistPreferences: friendRatings(for: ["Adaya"], rating: 3)
            )
        ])
    }
}

extension View {
    @MainActor
    func appEnvironment(_ services: AppServices, edition: FestivalEdition = .current) -> some View {
        let dataStore = services.dataStore(for: edition)
        let profile = dataStore.festivalProfileStore
        return environmentObject(dataStore)
            .environmentObject(services.userSettings)
            .environmentObject(profile)
            .environmentObject(profile.syncStore)
            .environmentObject(profile.friendProfilesStore)
            .environmentObject(dataStore.newsStore)
            .environmentObject(dataStore.recommendationStore)
            .environmentObject(services.iapManager)
    }
}

enum ScreenshotAppearance {
    static var colorScheme: ColorScheme? {
        guard ScreenshotRuntime.isEnabled else {
            return nil
        }

        switch ScreenshotRuntime.appearance {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil
        }
    }
}
