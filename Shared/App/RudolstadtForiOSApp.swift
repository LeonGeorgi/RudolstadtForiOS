//
//  RudolstadtForiOSApp.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import BackgroundTasks
import SDWebImage
import SwiftUI

@MainActor
@main
struct RudolstadtForiOSApp: App {
    let dataStore: DataStore
    let userSettings: UserSettings
    let iapManager: IAPManager
    let newsRefresher: NewsRefresher

    private var screenshotColorScheme: ColorScheme? {
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

    init() {
        let userSettings = UserSettings()
        let newsService = NewsService(userSettings: userSettings)
        let recommendationService = RecommendationService()
        let dataStore = DataStore(
            userSettings: userSettings,
            newsService: newsService,
            recommendationService: recommendationService
        )
        self.userSettings = userSettings
        self.dataStore = dataStore
        self.iapManager = IAPManager()
        self.newsRefresher = NewsRefresher(newsService: newsService)
        userSettings.onChange(of: .recommendationInputs) {
            Task {
                await dataStore.refreshRecommendations()
            }
        }
        configureCache()
    }

    func configureCache() {
        let cache = SDImageCache.shared
        let fiveYears: TimeInterval = 60 * 60 * 24 * 365 * 5
        cache.config.maxDiskAge = fiveYears
        cache.config.maxMemoryCost = 150 * 1024 * 1024
        cache.config.maxDiskSize = 1024 * 1024 * 1024
        cache.config.shouldCacheImagesInMemory = true
        cache.config.shouldUseWeakMemoryCache = true
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dataStore)
                .environmentObject(userSettings)
                .environmentObject(iapManager)
                .preferredColorScheme(screenshotColorScheme)
        }
        .backgroundTask(.appRefresh("updateNews")) {
            print("Background task started")
            await newsRefresher.handle()  // your handler
        }
    }
}
