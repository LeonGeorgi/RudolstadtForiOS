//
//  RudolstadtForiOSApp.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import SwiftUI
import SDWebImage

@main
struct RudolstadtForiOSApp: App {
    let dataStore = DataStore()
    let userSettings = UserSettings()
    
    init() {
        configureCache()
    }
    
    func configureCache() {
        let cache = SDImageCache.shared
        let oneMonth: TimeInterval = 60 * 60 * 24 * 30 // 60 seconds * 60 minutes * 24 hours * 30 days
        cache.config.maxDiskAge = oneMonth
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                    .environmentObject(dataStore)
                    .environmentObject(userSettings)
                    .onAppear {
                        userSettings.onChange {
                            DispatchQueue.global(qos: .userInitiated).async {
                                dataStore.loadArtistLinks()
                                dataStore.estimateEventDurations()
                                dataStore.updateRecommentations(savedEventsIds: userSettings.savedEvents, ratings: userSettings.ratings)
                            }
                        }
                    }
        }
    }
}
