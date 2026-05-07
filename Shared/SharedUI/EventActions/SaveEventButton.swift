//
//  SaveEventButton.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.03.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct SaveEventButton: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        Button(action: {
            settings.toggleSavedEvent(self.event)
        }) {
            if settings.savedEvents.contains(event.id) {
                Text("event.remove")
                Image(systemName: "bookmark.fill")
            } else {
                Text("event.save")
                Image(systemName: "bookmark")
            }
        }
    }
}
