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

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.scenePhase) var scenePhase
    
    let newsRefresher = NewsRefresher()

    @State private var selectedTab: AppTab = .schedule
    @State private var mapPath = NavigationPath()
    @State private var schedulePath = NavigationPath()
    @State private var artistsPath = NavigationPath()
    @State private var newsPath = NavigationPath()
    @State private var morePath = NavigationPath()

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

    var body: some View {
        TabView(selection: selectionBinding) {

            NavigationStack(path: $mapPath) {
                MapOverview()
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(route: route)
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
                        AppNavigationDestination(route: route)
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
                ArtistListView()
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(route: route)
                    }
            }
                .tabItem {
                    VStack {
                        Image(systemName: "person.crop.rectangle.stack")
                        Text("artists.title")
                    }
                }
                .tag(AppTab.artists)
            NavigationStack(path: $newsPath) {
                NewsListView()
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(route: route)
                    }
            }
                .tabItem {
                    Label("news.short", systemImage: "envelope.fill")
                }
                .badge(unreadNewsCount)
                .tag(AppTab.news)
            NavigationStack(path: $morePath) {
                MoreView()
                    .navigationDestination(for: AppNavigationRoute.self) { route in
                        AppNavigationDestination(route: route)
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
        .onAppear {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) {
                    granted,
                    error in
                    print(
                        "Permission granted: \(granted), error: \(String(describing: error))"
                    )
                }
            // dataStore.setupUpdateNewsTask()
            print("test")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("App is active")
                Task {
                    print("Trying to load new festival data")
                    await dataStore.loadData()
                    await dataStore.loadNews()
                    dataStore.estimateEventDurations()
                    dataStore.updateRecommentations(
                        savedEventsIds: userSettings.savedEvents,
                        ratings: userSettings.ratings
                    )

                }
            } else if newPhase == .inactive {
                UIApplication.shared.applicationIconBadgeNumber =
                    unreadNewsCount
                print("App is inactive")
                NewsRefresher.scheduleNextBackgroundTask()
            }
        }
        .accentColor(.rudolstadt)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
