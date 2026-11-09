import SwiftUI
import UserNotifications
import BackgroundTasks

private enum AppTab: Int, Hashable {
    case map
    case schedule
    case artists
    case friends
    case more
}

struct RootTabView: View {
    private static let notificationPromptDelay: Duration = .seconds(5)

    var refreshOnForeground: () async -> Void = {}
    var pendingFestivalRoute: FestivalRoute? = nil
    var onFestivalRouteHandled: () -> Void = {}
    var pendingFriendsLink = false
    var onFriendsLinkHandled: () -> Void = {}

    @Environment(\.festivalEdition) private var edition
    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var dataStore: DataStore
    @EnvironmentObject var newsStore: NewsStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) private var appColorScheme

    @ObservedObject private var newsNotificationNavigation =
        NewsNotificationNavigationController.shared
    @StateObject private var notificationPermissionController =
        NotificationPermissionController.shared
    @Namespace private var artistImageTransition
    @State private var selectedTab: AppTab = .schedule
    @State private var mapPath = NavigationPath()
    @State private var schedulePath = NavigationPath()
    @State private var artistsPath = NavigationPath()
    @State private var friendsPath = NavigationPath()
    @State private var morePath = NavigationPath()
    @State private var newsSheetPath = NavigationPath()
    @State private var isShowingNewsSheet = false
    @State private var retainsNewsAccessoryForPresentedSheet = false
    @State private var isShowingNotificationPrompt = false
    @State private var isShowingArtistLinkUnavailable = false

    private var isScreenshotMode: Bool {
        ScreenshotRuntime.isEnabled
    }

    private var selectionBinding: Binding<AppTab> {
        Binding(
            get: {
                selectedTab
            },
            set: { newTab in
                if newTab == selectedTab {
                    resetNavigation(for: newTab)
                } else {
                    selectedTab = newTab
                }
            }
        )
    }

    private func resetNavigation(for tab: AppTab) {
        switch tab {
        case .map:
            mapPath = NavigationPath()
        case .schedule:
            schedulePath = NavigationPath()
        case .artists:
            artistsPath = NavigationPath()
        case .friends:
            friendsPath = NavigationPath()
        case .more:
            morePath = NavigationPath()
        }
    }

    private func presentNewsSheet() {
        newsSheetPath = NavigationPath()
        retainsNewsAccessoryForPresentedSheet = true
        isShowingNewsSheet = true
    }

    private var unreadNewsItems: [NewsItem] {
        if dataStore.hasNews, newsStore.state.phase == .ready {
            let news = newsStore.state.items
            return news.filter { item in
                item.isInCurrentLanguage
                && !userSettings.readNews.contains(item.id)
            }
        } else {
            return []
        }
    }

    private var unreadFestivalNews: [FestivalNewsItem] {
        guard !newsStore.usesLegacyPresentation, let snapshot = newsStore.snapshot else { return [] }
        return snapshot.items.filter { !userSettings.isFestivalNewsRead($0.id, identity: snapshot.identity) }
    }

    var unreadNewsCount: Int {
        newsStore.usesLegacyPresentation ? unreadNewsItems.count : unreadFestivalNews.count
    }

    private var unreadNewsAccessoryContent: [UnreadNewsAccessoryContent] {
        if !newsStore.usesLegacyPresentation {
            return unreadFestivalNews.map { UnreadNewsAccessoryContent(title: $0.title.resolved(), subtitle: $0.summary?.resolved() ?? "") }
        }
        return unreadNewsItems.map { newsItem in
            UnreadNewsAccessoryContent(
                title: newsItem.formattedShortDescription,
                subtitle: newsItem.formattedLongDescription
            )
        }
    }

    private var festivalAccentColor: Color {
        dataStore.metadata.presentation.accentColorHex.flatMap { Color(festivalProfileHex: $0) }
            ?? .rudolstadt
    }

    private var shouldShowNewsAccessory: Bool {
        unreadNewsCount > 0 || retainsNewsAccessoryForPresentedSheet
    }

    private var appTabView: some View {
        #if os(iOS)
            return modernTabView
        #else
            if #available(macOS 15.0, *) {
                return AnyView(modernTabView)
            } else {
                return AnyView(legacyTabView)
            }
        #endif
    }

    #if os(macOS)
    // The Tab API is unavailable on older supported macOS versions.
    private var legacyTabView: some View {
        TabView(selection: selectionBinding) {
            mapTabContent
                .tabItem { Label("locations.title", systemImage: "map.fill") }
                .tag(AppTab.map)
            scheduleTabContent
                .tabItem { Label("schedule.title", systemImage: "calendar") }
                .tag(AppTab.schedule)
            artistsTabContent
                .tabItem { Label("artists.title", systemImage: "theatermasks.fill") }
                .tag(AppTab.artists)
            friendsTabContent
                .tabItem { Label("more.friends.title", systemImage: "person.2.fill") }
                .tag(AppTab.friends)
            moreTabContent
                .tabItem { Label("more.title", systemImage: "ellipsis") }
                .tag(AppTab.more)
        }
    }
    #endif

    @available(iOS 18.0, macOS 15.0, *)
    private var modernTabView: some View {
        TabView(selection: selectionBinding) {
            Tab("locations.title", systemImage: "map.fill", value: AppTab.map) {
                mapTabContent
            }
            Tab("schedule.title", systemImage: "calendar", value: AppTab.schedule) {
                scheduleTabContent
            }
            Tab("artists.title", systemImage: "theatermasks.fill", value: AppTab.artists) {
                artistsTabContent
            }
            Tab("more.friends.title", systemImage: "person.2.fill", value: AppTab.friends) {
                friendsTabContent
            }
            Tab("more.title", systemImage: "ellipsis", value: AppTab.more) {
                moreTabContent
            }
        }
    }

    private var mapTabContent: some View {
        NavigationStack(path: $mapPath) {
            MapOverview(presentsPlaceSheets: true, navigate: { mapPath.append($0) })
                .navigationDestination(for: AppNavigationRoute.self) { route in
                    AppNavigationDestination(
                        route: route,
                        navigate: { nestedRoute in
                            mapPath.append(nestedRoute)
                        }
                    )
                }
        }
    }

    private var scheduleTabContent: some View {
        NavigationStack(path: $schedulePath) {
            ScheduleScreen()
                .navigationDestination(for: AppNavigationRoute.self) { route in
                    AppNavigationDestination(
                        route: route,
                        navigate: { nestedRoute in
                            schedulePath.append(nestedRoute)
                        }
                    )
                }
        }
    }

    private var artistsTabContent: some View {
        NavigationStack(path: $artistsPath) {
            ArtistListView(
                imageTransitionNamespace: artistImageTransition
            ) { route in
                artistsPath.append(route)
            }
            .navigationDestination(for: AppNavigationRoute.self) { route in
                AppNavigationDestination(
                    route: route,
                    navigate: { nestedRoute in
                        artistsPath.append(nestedRoute)
                    },
                    imageTransitionNamespace: artistImageTransition
                )
            }
        }
    }

    private var friendsTabContent: some View {
        NavigationStack(path: $friendsPath) {
            FriendsView()
                .navigationDestination(for: AppNavigationRoute.self) { route in
                    AppNavigationDestination(
                        route: route,
                        navigate: { nestedRoute in
                            friendsPath.append(nestedRoute)
                        }
                    )
                }
        }
    }

    private var moreTabContent: some View {
        NavigationStack(path: $morePath) {
            MoreView()
                .navigationDestination(for: AppNavigationRoute.self) { route in
                    AppNavigationDestination(
                        route: route,
                        navigate: { nestedRoute in
                            morePath.append(nestedRoute)
                        }
                    )
                }
        }
    }

    @ViewBuilder
    private var tabViewWithNewsAccessory: some View {
        if #available(iOS 26.1, *) {
            appTabView
                .tabBarMinimizeBehavior(shouldShowNewsAccessory ? .onScrollDown : .never)
                .tabViewBottomAccessory(isEnabled: shouldShowNewsAccessory) {
                    UnreadNewsAccessory(
                        unreadCount: unreadNewsCount,
                        content: unreadNewsAccessoryContent,
                        foregroundColorScheme: appColorScheme,
                        openNews: presentNewsSheet
                    )
                }
        } else if #available(iOS 26.0, *) {
            appTabView
                .tabBarMinimizeBehavior(shouldShowNewsAccessory ? .onScrollDown : .never)
                .tabViewBottomAccessory {
                    // Keep the tab hierarchy stable; only the accessory content changes.
                    if shouldShowNewsAccessory {
                        UnreadNewsAccessory(
                            unreadCount: unreadNewsCount,
                            content: unreadNewsAccessoryContent,
                            foregroundColorScheme: appColorScheme,
                            openNews: presentNewsSheet
                        )
                    }
                }
        } else {
            appTabView
        }
    }

    var body: some View {
        tabViewWithNewsAccessory
        .onAppear {
            if isScreenshotMode {
                selectedTab = .schedule
                mapPath = NavigationPath()
                schedulePath = NavigationPath()
                artistsPath = NavigationPath()
                friendsPath = NavigationPath()
                morePath = NavigationPath()
                return
            }

        }
        .sheet(
            isPresented: $isShowingNewsSheet,
            onDismiss: {
                newsSheetPath = NavigationPath()
                retainsNewsAccessoryForPresentedSheet = false
            }
        ) {
            NavigationStack(path: $newsSheetPath) {
                NewsListView(allowsPullToRefresh: false)
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(
                            route: route,
                            navigate: { nestedRoute in
                                newsSheetPath.append(nestedRoute)
                            }
                        )
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, !isScreenshotMode, dataStore.hasNews else {
                return
            }

            await notificationPermissionController.refreshAuthorizationStatus()
            guard NotificationPermissionController.shouldPresentPrePrompt(
                authorizationStatus: notificationPermissionController.authorizationStatus,
                promptState: userSettings.notificationPromptState
            ) else {
                return
            }

            try? await Task.sleep(for: Self.notificationPromptDelay)
            guard
                !Task.isCancelled,
                scenePhase == .active,
                !isShowingNewsSheet
            else {
                return
            }
            isShowingNotificationPrompt = true
        }
        .sheet(
            isPresented: $isShowingNotificationPrompt,
            onDismiss: {
                if userSettings.notificationPromptState == .notPresented {
                    userSettings.notificationPromptState = .deferred
                }
            }
        ) {
            NotificationPermissionPromptView(
                activate: activateNewsNotifications,
                defer: deferNewsNotifications
            )
            .tint(festivalAccentColor)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "artist.share.unavailable.title",
            isPresented: $isShowingArtistLinkUnavailable
        ) {
            Button("artist.share.unavailable.ok", role: .cancel) {}
        } message: {
            Text("artist.share.unavailable.message")
        }
        .onChange(of: pendingFriendsLink, initial: true) { _, pending in
            guard pending else { return }
            selectedTab = .friends
            friendsPath = NavigationPath()
            onFriendsLinkHandled()
        }
        .onChange(of: pendingFestivalRoute, initial: true) { _, route in
            guard let route, route.identity == dataStore.metadata.identity else { return }
            switch route.destination {
            case .artist, .event:
                selectedTab = .artists
                artistsPath = NavigationPath()
                artistsPath.append(AppNavigationRoute.festival(route.destination))
            case .place:
                selectedTab = .map
                mapPath = NavigationPath()
                mapPath.append(AppNavigationRoute.festival(route.destination))
            case .overview: selectedTab = .schedule
            case .news, .information:
                selectedTab = .more
                morePath = NavigationPath()
                morePath.append(AppNavigationRoute.festival(route.destination))
            }
            onFestivalRouteHandled()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await refreshOnForeground()
                }
            } else if newPhase == .inactive && dataStore.hasNews {
                UNUserNotificationCenter.current().setBadgeCount(unreadNewsCount)
                NewsRefresher.scheduleNextBackgroundTask()
            }
        }
        .environment(\.festivalAccentColor, festivalAccentColor)
    }

    private func activateNewsNotifications() {
        isShowingNotificationPrompt = false
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            userSettings.notificationPromptState = .systemPromptRequested
            await notificationPermissionController.requestAuthorization()
            if notificationPermissionController.authorizationStatus == .notDetermined {
                userSettings.notificationPromptState = .deferred
            }
        }
    }

    private func deferNewsNotifications() {
        userSettings.notificationPromptState = .deferred
        isShowingNotificationPrompt = false
    }
}

private struct UnreadNewsAccessoryContent: Equatable {
    let title: String
    let subtitle: String
}

private struct UnreadNewsAccessoryRotationConfiguration: Equatable {
    let content: [UnreadNewsAccessoryContent]
    let isEnabled: Bool
}

@available(iOS 26.0, *)
private struct UnreadNewsAccessory: View {
    @Environment(\.festivalAccentColor) private var festivalAccentColor
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var headlineIndex = 0

    let unreadCount: Int
    let content: [UnreadNewsAccessoryContent]
    let foregroundColorScheme: ColorScheme
    let openNews: () -> Void

    private var localizedUnreadCount: String {
        let key = unreadCount == 1
            ? "news.unread.count.one"
            : "news.unread.count.other"
        return String.localizedStringWithFormat(
            NSLocalizedString(key, comment: ""),
            Int64(unreadCount)
        )
    }

    private var accessibilityLabel: String {
        String(
            format: NSLocalizedString(
                "news.unread.accessibility",
                comment: ""
            ),
            localizedUnreadCount
        )
    }

    private var currentContent: UnreadNewsAccessoryContent? {
        guard !content.isEmpty else {
            return nil
        }
        return content[headlineIndex % content.count]
    }

    private var headlineTransition: AnyTransition {
        guard !reduceMotion else {
            return .opacity
        }

        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    private var rotationConfiguration: UnreadNewsAccessoryRotationConfiguration {
        UnreadNewsAccessoryRotationConfiguration(
            content: content,
            isEnabled: !reduceMotion && !voiceOverEnabled
        )
    }

    private var primaryTextColor: Color {
        foregroundColorScheme == .light ? .black : .white
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.6)
    }

    private var tertiaryTextColor: Color {
        primaryTextColor.opacity(0.3)
    }

    var body: some View {
        Button(action: openNews) {
            accessoryLabel
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text("news.unread.open"))
        .accessibilityIdentifier("unread-news-accessory")
        .task(id: rotationConfiguration) {
            headlineIndex = 0
            guard rotationConfiguration.isEnabled, content.count > 1 else {
                return
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(6))
                } catch {
                    return
                }

                withAnimation(.easeInOut(duration: 0.4)) {
                    headlineIndex = (headlineIndex + 1) % content.count
                }
            }
        }
    }

    private var accessoryLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "megaphone.fill")
                .font(.body)
                .foregroundStyle(festivalAccentColor)
                .frame(width: 28, height: 28)
                .overlay(alignment: .topTrailing) {
                    Text("\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Capsule())
                        .offset(x: 6, y: -4)
                }

            ZStack(alignment: .leading) {
                if let currentContent {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(currentContent.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)

                        if !currentContent.subtitle.isEmpty {
                            Text(currentContent.subtitle)
                                .font(.caption)
                                .foregroundStyle(secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                    .id(headlineIndex)
                    .transition(headlineTransition)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()

            Spacer(minLength: 8)

            if placement != .inline {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(tertiaryTextColor)
            }
        }
        .padding(.horizontal, placement == .inline ? 10 : 14)
    }
}

private struct NotificationPermissionPromptView: View {
    @Environment(\.festivalAccentColor) private var festivalAccentColor
    let activate: () -> Void
    let `defer`: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.largeTitle)
                .foregroundStyle(festivalAccentColor)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("notifications.prompt.title")
                    .font(.title2.bold())
                Text("notifications.prompt.message")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            Button("notifications.prompt.activate", action: activate)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Button("notifications.prompt.later", action: `defer`)
        }
        .padding(24)
    }
}

#if DEBUG
struct RootTabView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        RootTabView()
            .previewMockEnvironment(suiteName: "RootTabViewPreview")
    }
}
#endif
