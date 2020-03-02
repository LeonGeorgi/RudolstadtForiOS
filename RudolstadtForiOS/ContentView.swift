//
//  ContentView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State private var selection = 0
    @ObservedObject var dataProvider = DataProvider()

    var body: some View {
        TabView(selection: $selection) {
            ProgramView(data: dataProvider.data)
                    .tabItem {
                        VStack {
                            Image(systemName: "music.note.list")
                            Text("Program")
                        }
                    }.tag(0)
            ScheduleView()
                    .tabItem {
                        VStack {
                            Image(systemName: "calendar")
                            Text("Schedule")
                        }
                    }.tag(1)
            NewsListView(data: dataProvider.data)
                    .tabItem {
                        VStack {
                            Image(systemName: "envelope.fill")
                            Text("News")
                        }
                    }.tag(2)
            MoreView()
                    .tabItem {
                        VStack {
                            Image(systemName: "ellipsis")
                            Text("More")
                        }
                    }.tag(3)
        }.onAppear {
                    self.dataProvider.loadData()
                }
                .accentColor(.green)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
