import SwiftUI

@MainActor
final class AppServices {
    let dataStore: DataStore
    let userSettings: UserSettings
    let festivalProfileStore: FestivalProfileStore
    let iapManager: IAPManager
    let newsRefresher: NewsRefresher

    init() {
        let userSettings = UserSettings()
        if ScreenshotRuntime.isEnabled {
            ScreenshotRuntime.configure(userSettings: userSettings)
        }

        let festivalProfileStore: FestivalProfileStore
        if ScreenshotRuntime.isEnabled {
            let suiteName = "AppStoreScreenshots"
            let screenshotDefaults =
                UserDefaults(suiteName: suiteName) ?? .standard
            screenshotDefaults.removePersistentDomain(forName: suiteName)
            festivalProfileStore = FestivalProfileStore(
                userDefaults: screenshotDefaults,
                cloudKitEnabled: false
            )
        } else {
            festivalProfileStore = FestivalProfileStore()
        }
        let newsService = NewsService(userSettings: userSettings)
        let recommendationService = RecommendationService()
        let dataStore = DataStore(
            festivalProfileStore: festivalProfileStore,
            userSettings: userSettings,
            newsService: newsService,
            recommendationService: recommendationService
        )
        if ScreenshotRuntime.isEnabled {
            ScreenshotRuntime.configure(
                profile: festivalProfileStore,
                dataStore: dataStore
            )
        }

        self.userSettings = userSettings
        self.festivalProfileStore = festivalProfileStore
        self.dataStore = dataStore
        self.iapManager = IAPManager()
        self.newsRefresher = NewsRefresher(newsService: newsService)

        festivalProfileStore.onChange(of: .recommendationInputs) {
            dataStore.scheduleRecommendationRefresh()
        }

#if os(iOS)
        CloudKitShareAcceptanceController.shared.profileStore = festivalProfileStore
#endif
    }
}

enum ScreenshotRuntime {
    static let launchArgument = "-screenshotMode"

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
        ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_APPEARANCE"]
    }

    @MainActor
    static func configure(userSettings: UserSettings) {
        userSettings.mapType = 0
        userSettings.scheduleDisplayMode = .timeline
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

        if let featuredArtist = festivalData.artists.first(where: {
            $0.id == 216
        }) {
            profile.setArtistRating(for: featuredArtist, rating: 3)
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

        let firstEventID = firstDayEvents.first?.id
        let secondEventID = firstDayEvents.dropFirst().first?.id
        profile.syncStore.acceptedFriendProfiles = [
            SharedFestivalProfile(
                id: "screenshot-friend-aya",
                title: "Aya's Festival",
                ownerName: "Aya",
                badgeName: "Aya",
                badgeColorHex: "#3D78E0",
                festivalYear: DataStore.year,
                savedEventIDs: [firstEventID, secondEventID].compactMap { $0 },
                artistPreferences: []
            ),
            SharedFestivalProfile(
                id: "screenshot-friend-mika",
                title: "Mika's Festival",
                ownerName: "Mika",
                badgeName: "Mika",
                badgeColorHex: "#B54E9B",
                festivalYear: DataStore.year,
                savedEventIDs: [firstEventID].compactMap { $0 },
                artistPreferences: []
            )
        ]
    }
}

extension View {
    @MainActor
    func appEnvironment(_ services: AppServices) -> some View {
        environmentObject(services.dataStore)
            .environmentObject(services.userSettings)
            .environmentObject(services.festivalProfileStore)
            .environmentObject(services.festivalProfileStore.syncStore)
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
