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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var profile: FestivalProfileStore
    @EnvironmentObject private var settings: UserSettings

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
                            contextPreviewState: EventContextPreviewState(
                                event: event,
                                profile: profile,
                                settings: settings
                            ),
                            onToggleSaved: { profile.toggleSavedEvent(event) }
                        )
                    }
                    .listRowInsets(
                        .init(
                            top: dynamicTypeSize.isAccessibilitySize ? 12 : 6,
                            leading: 16,
                            bottom: dynamicTypeSize.isAccessibilitySize ? 12 : 6,
                            trailing: 16
                        )
                    )
                    .listRowBackground(
                        profile.isEventSaved(event.id)
                            ? savedEventBackground
                            : Color.clear
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
    }

    private var savedEventBackground: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.24 : 0.12)
    }
}

struct ScheduleListView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleListView(events: [Event.example])
            .environmentObject(DataStore())
            .environmentObject(FestivalProfileStore(cloudKitEnabled: false))
            .environmentObject(UserSettings())
    }
}
