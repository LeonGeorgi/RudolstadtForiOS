//
//  ContentView.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var selection = 0
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        TabView(selection: $selection) {
            ProgramView()
                    .tabItem {
                        VStack {
                            Image(systemName: "music.note.list")
                            Text("program.title")
                        }
                    }
                    .tag(0)
            RecommendationScheduleView()
                    .tabItem {
                        VStack {
                            Image(systemName: "calendar")
                            Text("schedule.title")
                        }
                    }
                    .tag(1)
            NewsListView()
                    .tabItem {
                        VStack {
                            Image(systemName: "envelope.fill")
                            Text("news.short")
                        }
                    }
                    .tag(2)
            MapOverview()
                    .tabItem {
                        VStack {
                            Image(systemName: "map.fill")
                            Text("locations.title")
                        }
                    }
            MoreView()
                    .tabItem {
                        VStack {
                            Image(systemName: "ellipsis")
                            Text("more.title")
                        }
                    }
                    .tag(3)
        }
                .task {
                    await dataStore.loadData()
                }
                .onAppear {
                    dataStore.setupUpdateNewsTask()
                    //1
                    UNUserNotificationCenter.current()
                      //2
                      .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                          //3
                          print("Permission granted: \(granted) \(error)")
                      }
                    
                    let content = UNMutableNotificationContent()
                    content.title = "Feed the cat"
                    content.subtitle = "It looks hungry"
                    content.sound = UNNotificationSound.default

                    // show this notification five seconds from now
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

                    // choose a random identifier
                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

                    // add our notification request
                    UNUserNotificationCenter.current().add(request)
                }
                .accentColor(.red)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
