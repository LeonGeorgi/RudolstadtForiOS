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
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var festivalProfileStore: FestivalProfileStore
    @Environment(\.scenePhase) var scenePhase

    @ObservedObject private var newsNotificationNavigation =
        NewsNotificationNavigationController.shared
    @Namespace private var artistImageTransition
    @State private var selectedTab: AppTab = .schedule
    @State private var mapPath = NavigationPath()
    @State private var schedulePath = NavigationPath()
    @State private var artistsPath = NavigationPath()
    @State private var friendsPath = NavigationPath()
    @State private var morePath = NavigationPath()

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

    var unreadNewsCount: Int {
        if case .success(let news) = dataStore.news {
            return news.filter { item in
                item.isInCurrentLanguage
                && !userSettings.readNews.contains(item.id)
            }.count
        } else {
            return 0
        }
    }

    @ViewBuilder
    private var appTabView: some View {
        TabView(selection: selectionBinding) {
            NavigationStack(path: $mapPath) {
                MapOverview()
                    .newsToolbarContext(unreadNewsCount: unreadNewsCount) {
                        mapPath.append(AppNavigationRoute.newsList)
                    }
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
                    .newsToolbarContext(unreadNewsCount: unreadNewsCount) {
                        schedulePath.append(AppNavigationRoute.newsList)
                    }
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
                .newsToolbarContext(unreadNewsCount: unreadNewsCount) {
                    artistsPath.append(AppNavigationRoute.newsList)
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
                    .newsToolbarContext(unreadNewsCount: unreadNewsCount) {
                        friendsPath.append(AppNavigationRoute.newsList)
                    }
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(
                            route: route,
                            navigate: { nestedRoute in
                                friendsPath.append(nestedRoute)
                            }
                        )
                    }
                    .toolbar {
                        NewsToolbarItem(
                            context: NewsToolbarContext(
                                unreadNewsCount: unreadNewsCount,
                                openNews: {
                                    friendsPath.append(AppNavigationRoute.newsList)
                                }
                            )
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
                    .newsToolbarContext(unreadNewsCount: unreadNewsCount) {
                        morePath.append(AppNavigationRoute.newsList)
                    }
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(
                            route: route,
                            navigate: { nestedRoute in
                                morePath.append(nestedRoute)
                            }
                        )
                }
                .toolbar {
                    NewsToolbarItem(
                        context: NewsToolbarContext(
                            unreadNewsCount: unreadNewsCount,
                            openNews: {
                                morePath.append(AppNavigationRoute.newsList)
                            }
                        )
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

    var body: some View {
        appTabView
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

            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) {
                    granted,
                    error in
                    print(
                        "Permission granted: \(granted), error: \(String(describing: error))"
                    )
                }
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
}

struct NewsToolbarContext {
    let unreadNewsCount: Int
    let openNews: () -> Void
}

private struct NewsToolbarContextKey: EnvironmentKey {
    static let defaultValue: NewsToolbarContext? = nil
}

extension EnvironmentValues {
    var newsToolbarContext: NewsToolbarContext? {
        get { self[NewsToolbarContextKey.self] }
        set { self[NewsToolbarContextKey.self] = newValue }
    }
}

extension View {
    func newsToolbarContext(
        unreadNewsCount: Int,
        openNews: @escaping () -> Void
    ) -> some View {
        environment(
            \.newsToolbarContext,
            NewsToolbarContext(
                unreadNewsCount: unreadNewsCount,
                openNews: openNews
            )
        )
    }
}

struct NewsToolbarItem: ToolbarContent {
    @Environment(\.newsToolbarContext) private var environmentContext

    private let explicitContext: NewsToolbarContext?

    init(context: NewsToolbarContext? = nil) {
        self.explicitContext = context
    }

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        let context = explicitContext ?? environmentContext

        if let context {
            if #available(iOS 26.0, *) {
                ToolbarItemGroup(placement: .topBarLeading) {
                    NewsToolbarButton(context: context)
                }
                ToolbarSpacer(.fixed, placement: .topBarLeading)
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    NewsToolbarButton(context: context)
                }
            }
        }
    }
}

private struct NewsToolbarButton: View {
    let context: NewsToolbarContext

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            newsButton {
                Image(systemName: "megaphone.fill")
            }
            .badge(context.unreadNewsCount)
        } else {
            newsButton {
                Image(systemName: "megaphone.fill")
                    .overlay(alignment: .topTrailing) {
                        if context.unreadNewsCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
            }
        }
    }

    private func newsButton<Label: View>(
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            context.openNews()
        } label: {
            label()
        }
        .accessibilityLabel("news.long")
        .accessibilityValue(
            context.unreadNewsCount > 0
                ? "\(context.unreadNewsCount)"
                : ""
        )
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
