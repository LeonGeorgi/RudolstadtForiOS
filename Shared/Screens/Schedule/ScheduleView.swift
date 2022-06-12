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
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
            } else {
                if case .success(let days) = eventDays {
                    Picker("Date", selection: $selectedDay) {
                        ForEach(days) { (day: Int) in
                            Text(Util.shortWeekDay(day: day)).tag(day)
                        }
                    }
                            .padding(.leading, 10)
                            .padding(.trailing, 10)
                            .pickerStyle(SegmentedPickerStyle())
                }

                List(events.filter { event in
                    event.festivalDay == selectedDay
                }) { event in
                    NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                        ScheduleEventCell(event: event)
                    }
                }.listStyle(.plain)
            }
        }
                .onAppear {
                    if case .success(let days) = eventDays {
                        if selectedDay == -1 {
                            self.selectedDay = Util.getCurrentFestivalDay(eventDays: days) ?? days.first ?? -1
                        }
                    }
                }

    }
}

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView(events: [Event.example])
    }
}
