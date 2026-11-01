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
            FestivalRootView(services: services)
            .environmentObject(services.userSettings)
            .preferredColorScheme(ScreenshotAppearance.colorScheme)
        }
        .backgroundTask(.appRefresh("updateNews")) {
            AppLog.news.info("Background news refresh task started")
            await services.newsRefresher.handle()
        }
    }
}

private struct FestivalRootView: View {
    let services: AppServices
    @EnvironmentObject private var settings: UserSettings
    @ObservedObject private var newsNavigation = NewsNotificationNavigationController.shared

    // Keep incoming links while the data gate is loading or showing a retry.
    @State private var pendingFestivalRoute: FestivalRoute?

    private var edition: FestivalEdition {
        settings.festivalEdition
    }

    var body: some View {
        FestivalDataGate {
            RootTabView(
                refreshOnForeground: services.refreshOnForeground,
                pendingFestivalRoute: pendingFestivalRoute,
                onFestivalRouteHandled: { pendingFestivalRoute = nil; newsNavigation.clearRequestedRoute() }
            )
        }
        .appEnvironment(services, edition: edition)
        .id(edition)
        .onChange(of: newsNavigation.requestedRoute, initial: true) { _, route in
            guard let route, let adapter = FestivalRegistry.catalog.adapter(for: route.identity) else { return }
            settings.festivalEdition = FestivalEdition(metadata: adapter.metadata)
            pendingFestivalRoute = route
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
        for adapter in FestivalRegistry.catalog.adapters {
            if let destination = adapter.services.publicLinks.value?.destination(for: url) {
                let metadata = adapter.metadata
                settings.festivalEdition = FestivalEdition(metadata: metadata)
                pendingFestivalRoute = FestivalRoute(identity: metadata.identity, destination: destination)
                return
            }
        }
    }
}
