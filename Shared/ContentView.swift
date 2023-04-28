//
//  ContentView.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var selection = 1
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        TabView(selection: $selection) {
            
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
            
            /*ProgramView()
             .navigationViewStyle(.stack)
             .tabItem {
             VStack {
             Image(systemName: "music.note.list")
             Text("program.title")
             }
             }
             .tag(2)*/
            /*RecommendationScheduleView()
             .navigationViewStyle(.stack)
             .tabItem {
             VStack {
             Image(systemName: "calendar")
             Text("schedule.title")
             }
             }
             .tag(2)*/
            NewsListView()
                .navigationViewStyle(.stack)
                .tabItem {
                    VStack {
                        Image(systemName: "envelope.fill")
                        Text("news.short")
                    }
                }
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
        .background(.ultraThinMaterial)
        .onAppear {
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    print("Permission granted: \(granted), error: \(String(describing: error))")
                }
            dataStore.setupUpdateNewsTask()
        }
        .accentColor(.orange)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
