//
//  ContentView.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.scenePhase) var scenePhase
    
    @State private var goHome = UUID()
    @State var selectedIndex: Int = 0

    var selectionBinding: Binding<Int> { Binding(
        get: {
            self.selectedIndex
        },
        set: {
            if $0 == self.selectedIndex {
                goHome = UUID()
            }
            self.selectedIndex = $0
        }
    )}

        
    var unreadNewsCount: Int {
        if case .success(let entities) = dataStore.data {
            return entities.news.filter { item in item.isInCurrentLanguage && !userSettings.readNews.contains(item.id) }.count
        } else {
            return 0
        }
    }
    
    var body: some View {
        TabView(selection: selectionBinding) {
            
            MapOverview()
                .navigationViewStyle(.stack)
                .tabItem {
                    VStack {
                        Image(systemName: "map.fill")
                        Text("locations.title")
                    }
                }
                .tag(0)
            RecommendationScheduleView()
                .navigationViewStyle(.stack)
                .tabItem {
                    VStack {
                        Image(systemName: "calendar")
                        Text("schedule.title")
                    }
                }
                .tag(1)
            
            ArtistListView()
                .navigationViewStyle(.stack)
                .tabItem {
                    VStack {
                        Image(systemName: "person.crop.rectangle.stack")
                        Text("artists.title")
                    }
                }
                .tag(2)
            NewsListView()
                .navigationViewStyle(.stack)
                .tabItem {
                    Label("news.short", systemImage: "envelope.fill")
                }
                .badge(unreadNewsCount)
                .tag(3)
            MoreView()
                .navigationViewStyle(.stack)
                .tabItem {
                    VStack {
                        Image(systemName: "ellipsis")
                        Text("more.title")
                    }
                }
                .tag(4)
        }
        .id(goHome)
        .onAppear {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    print("Permission granted: \(granted), error: \(String(describing: error))")
                }
            dataStore.setupUpdateNewsTask()
            print("test")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("App is active")
                Task {
                    print("Trying to load new festival data")
                    await dataStore.loadData()
                    dataStore.estimateEventDurations()
                    dataStore.updateRecommentations(savedEventsIds: userSettings.savedEvents, ratings: userSettings.ratings)
                    
                }
            } else if newPhase == .inactive {
                UIApplication.shared.applicationIconBadgeNumber = unreadNewsCount
                print("App is inactive")
            }
        }
        .accentColor(Color(hue: 0/360, saturation: 0.7, brightness: 0.9))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
