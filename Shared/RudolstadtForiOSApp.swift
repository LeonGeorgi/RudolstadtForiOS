//
//  RudolstadtForiOSApp.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import BackgroundTasks
import SDWebImage
import SwiftUI

@main
struct RudolstadtForiOSApp: App {
    let dataStore = DataStore()
    let userSettings = UserSettings()
    let iapManager = IAPManager()
    let newsRefresher = NewsRefresher()

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
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(userSettings)
                .environmentObject(iapManager)
                .preferredColorScheme(screenshotColorScheme)
                .onAppear {
                    userSettings.onChange {
                        DispatchQueue.global(qos: .userInitiated).async {
                            dataStore.loadArtistLinks()
                            dataStore.estimateEventDurations()
                            dataStore.updateRecommentations(
                                savedEventsIds: userSettings.savedEvents,
                                ratings: userSettings.ratings
                            )
                        }
                    }
                }
        }
        .backgroundTask(.appRefresh("updateNews")) {
            print("Background task started")
            await newsRefresher.handle()  // your handler
        }
    }
}
