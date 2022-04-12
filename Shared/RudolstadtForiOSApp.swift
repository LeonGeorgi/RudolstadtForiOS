//
//  RudolstadtForiOSApp.swift
//  Shared
//
//  Created by Leon Georgi on 11.04.22.
//

import SwiftUI

@main
struct RudolstadtForiOSApp: App {
    let dataStore = DataStore()
    let userSettings = UserSettings()
    var body: some Scene {
        WindowGroup {
            ContentView()
                    .environmentObject(dataStore)
                    .environmentObject(userSettings)
        }
    }
}