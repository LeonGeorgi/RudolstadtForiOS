//
//  EventSavedIcon.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct EventSavedIcon: View {
    @EnvironmentObject private var profile: FestivalProfileStore
    @Environment(\.festivalEdition) private var edition
    let event: Event
    let isSaved: Bool
    var symbolAlignment: Alignment = .center
    var foregroundColor: Color = .primary
    let onToggle: () -> Void

    @State var isAlertShown = false

    private var removalAlertTitle: String {
        String(
            format: NSLocalizedString("event.remove.alert.title", comment: ""),
            event.artist.formattedName,
            event.shortWeekDay,
            event.timeAsString
        )
    }

    var body: some View {
        if profile.userDataPolicy.savedEvents != .editable {
            if isSaved {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(foregroundColor)
                    .frame(width: 44, height: 44, alignment: symbolAlignment)
                    .accessibilityLabel(Text("event.saved.value.saved"))
            }
        } else {
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
                .contentTransition(.symbolEffect(.replace))
                .animation(.default, value: isSaved)
                .foregroundStyle(foregroundColor)
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
            .alert(removalAlertTitle, isPresented: $isAlertShown) {
                Button("event.remove") {
                    if isSaved {
                        onToggle()
                    }
                }
                Button("event.remove.alert.cancel", role: .cancel) {}
            } message: {
                Text("event.remove.alert.message")
            }
        }
    }
}

struct EventSavedIcon_Previews: PreviewProvider {
    static var previews: some View {
        EventSavedIcon(event: .example, isSaved: false, onToggle: {})
    }
}
