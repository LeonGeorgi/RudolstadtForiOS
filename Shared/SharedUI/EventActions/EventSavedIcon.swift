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
    var symbolAlignment: Alignment = .center
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
        Button {
            if isSaved {
                isAlertShown = true
            } else {
                onToggle()
            }
        } label: {
            Image(
                systemName: isSaved
                    ? "bookmark.fill" : "bookmark"
            )
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44, alignment: symbolAlignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(isSaved ? "event.saved.remove" : "event.saved.add")
        )
        .accessibilityValue(
            Text(isSaved ? "event.saved.value.saved" : "event.saved.value.not_saved")
        )
        .accessibilityAddTraits(isSaved ? .isSelected : [])
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
