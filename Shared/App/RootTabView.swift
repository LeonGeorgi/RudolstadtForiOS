import SwiftUI
import UserNotifications
import BackgroundTasks

private enum AppTab: Int, Hashable {
    case map
    case schedule
    case artists
    case news
    case more
}

struct RootTabView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.scenePhase) var scenePhase

    @State private var selectedTab: AppTab = .schedule
    @State private var mapPath = NavigationPath()
    @State private var schedulePath = NavigationPath()
    @State private var artistsPath = NavigationPath()
    @State private var newsPath = NavigationPath()
    @State private var morePath = NavigationPath()

    private var isScreenshotMode: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMode")
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
        case .news:
            newsPath = NavigationPath()
        case .more:
            morePath = NavigationPath()
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
                RecommendationScheduleView()
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
                ArtistListView { route in
                    artistsPath.append(route)
                }
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(
                            route: route,
                            navigate: { nestedRoute in
                                artistsPath.append(nestedRoute)
                            }
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
            NavigationStack(path: $newsPath) {
                NewsListView()
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(
                            route: route,
                            navigate: { nestedRoute in
                                newsPath.append(nestedRoute)
                            }
                        )
                    }
            }
            .tabItem {
                Label("news.short", systemImage: "megaphone.fill")
            }
            .badge(unreadNewsCount)
            .tag(AppTab.news)
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
    
    var body: some View {
        appTabView
        .onAppear {
            if !isScreenshotMode {
                UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge]) {
                        granted,
                        error in
                        print(
                            "Permission granted: \(granted), error: \(String(describing: error))"
                        )
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                print("App is active")
                Task {
                    await dataStore.refreshOnAppActive()
                }
            } else if newPhase == .inactive {
                UNUserNotificationCenter.current().setBadgeCount(unreadNewsCount)
                print("App is inactive")
                NewsRefresher.scheduleNextBackgroundTask()
            }
        }
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
