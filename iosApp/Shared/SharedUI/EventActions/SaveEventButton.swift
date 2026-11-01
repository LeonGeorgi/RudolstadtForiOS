//
//  SaveEventButton.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.03.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct SaveEventButton: View {
    @EnvironmentObject private var profile: FestivalProfileStore
    @Environment(\.festivalEdition) private var edition
    let event: Event
    let isSaved: Bool
    let onToggle: () -> Void

    var body: some View {
        if profile.userDataPolicy.savedEvents == .editable {
            Button(action: onToggle) {
                Label {
                    Text(LocalizedStringKey(isSaved ? "event.remove" : "event.save"))
                } icon: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.default, value: isSaved)
                }
            }
        }
    }
}
