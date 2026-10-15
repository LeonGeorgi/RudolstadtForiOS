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
            FestivalRootView()
            .appEnvironment(services)
            .preferredColorScheme(ScreenshotAppearance.colorScheme)
        }
        .backgroundTask(.appRefresh("updateNews")) {
            AppLog.news.info("Background news refresh task started")
            await services.newsRefresher.handle()
        }
    }
}

private struct FestivalRootView: View {
    // Keep incoming links while the data gate is loading or showing a retry.
    @State private var pendingArtistLink: ArtistShareLink?

    var body: some View {
        FestivalDataGate {
            RootTabView(pendingArtistLink: $pendingArtistLink)
        }
        .onOpenURL { url in
            receiveArtistLink(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                receiveArtistLink(url)
            }
        }
    }

    private func receiveArtistLink(_ url: URL) {
        if let link = ArtistShareLink(url: url) {
            pendingArtistLink = link
        }
    }
}
