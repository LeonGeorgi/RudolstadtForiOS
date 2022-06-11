//
//  EventSavedIcon.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct EventSavedIcon: View {
    let event: Event
    
    @EnvironmentObject var settings: UserSettings
    
    func createAlert() -> Alert {
        Alert(
                title: Text("Save \"\(event.artist.name)\" at \(event.shortWeekDay) \(event.timeAsString)?"),
                message: Text("event.save.alert.message"),
                primaryButton: .default(Text("event.save")) {
                    if !settings.savedEvents.contains(event.id) {
                        settings.savedEvents.append(event.id)
                    }
                }, secondaryButton: .cancel())
    }

    var body: some View {
        Image(systemName: settings.savedEvents.contains(self.event.id) ? "bookmark.fill" : "bookmark")
            .foregroundColor(.yellow)
            .onTapGesture {
                settings.toggleSavedEvent(self.event)
            }
    }
}

struct EventSavedIcon_Previews: PreviewProvider {
    static var previews: some View {
        EventSavedIcon(event: .example)
    }
}
