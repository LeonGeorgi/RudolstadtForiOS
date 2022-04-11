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

    @State var selectedDay: Int = -1

    var eventDays: [Int] {
        Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        })
                .sorted(by: <)
    }

    var body: some View {
        VStack {
            Picker("Date", selection: $selectedDay) {
                ForEach(eventDays) { (day: Int) in
                    Text(Util.shortWeekDay(day: day)).tag(day)
                }
            }
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
                    .pickerStyle(SegmentedPickerStyle())

            List(events.filter { event in
                event.festivalDay == selectedDay
            }) { event in
                NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                    ScheduleEventCell(event: event)
                }
            }
        }
                .onAppear {
                    if selectedDay == -1 {
                        self.selectedDay = eventDays.first ?? -1
                    }
                }

    }
}

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView(events: [Event.example])
    }
}
