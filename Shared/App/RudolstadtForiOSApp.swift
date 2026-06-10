//
//  RudolstadtForiOSApp.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import BackgroundTasks
import SwiftUI

@MainActor
@main
struct RudolstadtForiOSApp: App {
    private let services: AppServices

#if os(iOS)
    @UIApplicationDelegateAdaptor(CloudKitShareAppDelegate.self)
    private var cloudKitShareAppDelegate
#endif

    init() {
        services = AppServices()
        configureDiscoverabilityTips()
        AppLog.app.info("App initialized for festival year \(DataStore.year)")
    }

    var body: some Scene {
        WindowGroup {
            FestivalDataGate {
                RootTabView()
            }
            .appEnvironment(services)
            .preferredColorScheme(ScreenshotAppearance.colorScheme)
        }
        .backgroundTask(.appRefresh("updateNews")) {
            AppLog.news.info("Background news refresh task started")
            await services.newsRefresher.handle()
        }
    }
}
