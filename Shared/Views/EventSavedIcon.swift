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

    @State var isAlertShown = false

    func createAlert() -> Alert {
        Alert(
            title: Text(
                String(
                    format: NSLocalizedString(
                        "event.remove.alert.title",
                        comment: ""
                    ),
                    event.artist.formattedName,
                    event.shortWeekDay,
                    event.timeAsString
                )
            ),
            message: Text("event.remove.alert.message"),
            primaryButton: .default(Text("event.remove")) {
                if settings.savedEvents.contains(event.id) {
                    settings.toggleSavedEvent(event)
                }
            },
            secondaryButton: .cancel()
        )
    }

    var body: some View {
        Image(
            systemName: settings.savedEvents.contains(event.id)
                ? "bookmark.fill" : "bookmark"
        )
        .foregroundColor(.yellow)
        .onTapGesture {
            if settings.savedEvents.contains(event.id) {
                isAlertShown = true
            } else {
                settings.toggleSavedEvent(event)
            }
        }
        .alert(isPresented: $isAlertShown) {
            createAlert()
        }
    }
}

struct EventSavedIcon_Previews: PreviewProvider {
    static var previews: some View {
        EventSavedIcon(event: .example)
    }
}
