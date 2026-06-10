//
//  ScheduleListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ScheduleListView: View {
    let events: [Event]

    @EnvironmentObject var profile: FestivalProfileStore

    var body: some View {
        Group {
            if events.isEmpty {
                VStack {
                    Spacer()

                    Text("schedule.empty.description")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    Spacer()
                }
            } else {
                List(events) { event in
                    NavigationLink(
                        value: AppNavigationRoute.artist(
                            id: event.artist.id,
                            highlightedEventId: event.id,
                            transitionSourceID: nil
                        )
                    ) {
                        ScheduleEventCell(
                            event: event,
                            isSaved: profile.isEventSaved(event.id),
                            artistRating: profile.rating(for: event.artist.id),
                            artistIconName: profile.iconName(forArtistID: event.artist.id),
                            friendProfilesWhoSavedEvent: profile.friendProfilesSavingEvent(event.id),
                            onToggleSaved: { profile.toggleSavedEvent(event) }
                        )
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                    .listRowBackground(
                        profile.isEventSaved(event.id)
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
    }
}

struct ScheduleListView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleListView(events: [Event.example])
            .environmentObject(DataStore())
            .environmentObject(FestivalProfileStore(cloudKitEnabled: false))
    }
}
