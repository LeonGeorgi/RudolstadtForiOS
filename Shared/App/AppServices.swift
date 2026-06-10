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
        let festivalProfileStore = FestivalProfileStore()
        let newsService = NewsService(userSettings: userSettings)
        let recommendationService = RecommendationService()
        let dataStore = DataStore(
            festivalProfileStore: festivalProfileStore,
            userSettings: userSettings,
            newsService: newsService,
            recommendationService: recommendationService
        )

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
        guard ProcessInfo.processInfo.arguments.contains("-screenshotMode") else {
            return nil
        }

        switch ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_APPEARANCE"] {
        case "dark":
            return .dark
        case "light":
            return .light
        default:
            return nil
        }
    }
}
