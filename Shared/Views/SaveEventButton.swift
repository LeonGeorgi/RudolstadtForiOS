//
//  SaveEventButton.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.03.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

struct SaveEventButton: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        Button(action: {
            if !settings.savedEvents.contains(event.id) {
                settings.savedEvents.append(event.id)
            } else {
                settings.savedEvents.remove(at: settings.savedEvents.firstIndex(of: event.id)!)
            }
        }) {
            if settings.savedEvents.contains(event.id) {
                Text("event.remove")
                //Image(systemName: "bookmark.fill")
            } else {
                Text("event.save")
                //Image(systemName: "bookmark")
            }
        }
    }
}
