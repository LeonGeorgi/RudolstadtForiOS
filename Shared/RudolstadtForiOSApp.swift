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

    init() {
        configureCache()
    }

    func configureCache() {
        let cache = SDImageCache.shared
        let oneMonth: TimeInterval = 60 * 60 * 24 * 30  // 60 seconds * 60 minutes * 24 hours * 30 days
        cache.config.maxDiskAge = oneMonth
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(userSettings)
                .environmentObject(iapManager)
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
