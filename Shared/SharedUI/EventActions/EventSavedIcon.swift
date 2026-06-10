//
//  EventSavedIcon.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct EventSavedIcon: View {
    let event: Event
    let isSaved: Bool
    let onToggle: () -> Void

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
                if isSaved {
                    onToggle()
                }
            },
            secondaryButton: .cancel()
        )
    }

    var body: some View {
        Image(
            systemName: isSaved
                ? "bookmark.fill" : "bookmark"
        )
        .foregroundStyle(.primary)
        .onTapGesture {
            if isSaved {
                isAlertShown = true
            } else {
                onToggle()
            }
        }
        .alert(isPresented: $isAlertShown) {
            createAlert()
        }
    }
}

struct EventSavedIcon_Previews: PreviewProvider {
    static var previews: some View {
        EventSavedIcon(event: .example, isSaved: false, onToggle: {})
    }
}
