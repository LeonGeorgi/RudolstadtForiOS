//
//  ScheduleView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ScheduleView: View {
    let events: [Event]

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    var eventDays: LoadingEntity<[Int]> {
        dataStore.data.map { entities in
            Set(entities.events.lazy.map { (event: Event) in
                event.festivalDay
            }).sorted(by: <)
        }
    }

    var body: some View {
        VStack {
            if events.isEmpty {
                Text("schedule.empty.description")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
            } else {
                List(events) { event in
                    NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                        ScheduleEventCell(event: event)
                    }.listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 16))
                }.listStyle(.plain)
                    
            }
        }

    }
}

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView(events: [Event.example])
            .environmentObject(DataStore())
    }
}
