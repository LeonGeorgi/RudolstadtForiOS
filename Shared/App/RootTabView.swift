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

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var festivalProfileStore: FestivalProfileStore
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

    private func openNewsFromNotification(id: Int) {
        selectedTab = .more
        morePath = NavigationPath()
        morePath.append(AppNavigationRoute.news(id: id))
        newsNotificationNavigation.clearRequestedNewsItem(id: id)

        Task {
            await dataStore.refreshNewsIfNecessary()
        }
    }

    private func presentNewsSheet() {
        newsSheetPath = NavigationPath()
        retainsNewsAccessoryForPresentedSheet = true
        isShowingNewsSheet = true
    }

    private var unreadNewsItems: [NewsItem] {
        if case .success(let news) = dataStore.news {
            return news.filter { item in
                item.isInCurrentLanguage
                && !userSettings.readNews.contains(item.id)
            }
        } else {
            return []
        }
    }

    var unreadNewsCount: Int {
        unreadNewsItems.count
    }

    private var unreadNewsAccessoryContent: [UnreadNewsAccessoryContent] {
        unreadNewsItems.map { newsItem in
            UnreadNewsAccessoryContent(
                title: newsItem.formattedShortDescription,
                subtitle: newsItem.formattedLongDescription
            )
        }
    }

    private var shouldShowNewsAccessory: Bool {
        unreadNewsCount > 0 || retainsNewsAccessoryForPresentedSheet
    }

    @ViewBuilder
    private var appTabView: some View {
        TabView(selection: selectionBinding) {
            NavigationStack(path: $mapPath) {
                MapOverview()
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(
                            route: route,
                            navigate: { nestedRoute in
                                mapPath.append(nestedRoute)
                            }
                        )
                    }
            }
            .tabItem {
                VStack {
                    Image(systemName: "map.fill")
                    Text("locations.title")
                }
            }
            .tag(AppTab.map)

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
            .tabItem {
                VStack {
                    Image(systemName: "calendar")
                    Text("schedule.title")
                }
            }
            .tag(AppTab.schedule)
            
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
            .tabItem {
                VStack {
                    Image(systemName: "theatermasks.fill")
                    Text("artists.title")
                }
            }
            .tag(AppTab.artists)

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
            .tabItem {
                VStack {
                    Image(systemName: "person.2.fill")
                    Text("more.friends.title")
                }
            }
            .tag(AppTab.friends)

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
            .tabItem {
                VStack {
                    Image(systemName: "ellipsis")
                    Text("more.title")
                }
            }
            .tag(AppTab.more)
        }
    }

    @ViewBuilder
    private var tabViewWithNewsAccessory: some View {
        if #available(iOS 26.1, *) {
            if shouldShowNewsAccessory {
                appTabView
                    .tabBarMinimizeBehavior(.onScrollDown)
                    .tabViewBottomAccessory(isEnabled: true) {
                        UnreadNewsAccessory(
                            unreadCount: unreadNewsCount,
                            content: unreadNewsAccessoryContent,
                            appColorScheme: appColorScheme,
                            openNews: presentNewsSheet
                        )
                    }
            } else {
                appTabView
                    .tabBarMinimizeBehavior(.never)
            }
        } else if #available(iOS 26.0, *) {
            if shouldShowNewsAccessory {
                appTabView
                    .tabBarMinimizeBehavior(.onScrollDown)
                    .tabViewBottomAccessory {
                        UnreadNewsAccessory(
                            unreadCount: unreadNewsCount,
                            content: unreadNewsAccessoryContent,
                            appColorScheme: appColorScheme,
                            openNews: presentNewsSheet
                        )
                    }
            } else {
                appTabView
                    .tabBarMinimizeBehavior(.never)
            }
        } else {
            appTabView
        }
    }

    var body: some View {
        tabViewWithNewsAccessory
        .accentColor(.rudolstadt)
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
            guard scenePhase == .active, !isScreenshotMode else {
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
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(
            of: newsNotificationNavigation.requestedNewsItemID,
            initial: true
        ) { _, requestedNewsItemID in
            guard let requestedNewsItemID else {
                return
            }
            openNewsFromNotification(id: requestedNewsItemID)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    async let cloudRefresh: Void =
                        festivalProfileStore.refreshFromCloud(reason: "foreground")
                    async let appRefresh: Void =
                        dataStore.refreshOnAppActive()
                    _ = await (cloudRefresh, appRefresh)
                }
            } else if newPhase == .inactive {
                UNUserNotificationCenter.current().setBadgeCount(unreadNewsCount)
                NewsRefresher.scheduleNextBackgroundTask()
            }
        }
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
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @State private var headlineIndex = 0

    let unreadCount: Int
    let content: [UnreadNewsAccessoryContent]
    let appColorScheme: ColorScheme
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
        appColorScheme == .light ? .black : .white
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
                .foregroundStyle(.tint)
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
    let activate: () -> Void
    let `defer`: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
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
