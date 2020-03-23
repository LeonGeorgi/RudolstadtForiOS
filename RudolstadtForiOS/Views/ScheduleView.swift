//
//  ScheduleView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ScheduleView: View {

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    @State private var showingSheet = false
    @State var selectedDay: Int = -1
    @State var generatedEvents: [Event] = []

    var eventDays: [Int] {
        Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        }).sorted(by: <)
    }

    var storedEvents: [Int] {
        settings.savedEvents
    }

    var body: some View {
        NavigationView {
            VStack {
                Picker("Date", selection: $selectedDay) {
                    ForEach(eventDays) { (day: Int) in
                        Text(Util.shortWeekDay(day: day)).tag(day)
                    }
                }
                        .padding(.leading, 10)
                        .padding(.trailing, 10)
                        .pickerStyle(SegmentedPickerStyle())

                List(dataStore.events.filter { (event: Event) in
                    event.festivalDay == selectedDay && storedEvents.contains(event.id)
                }) { event in
                    TimeProgramEventCell(event: event)
                }
            }
                    .navigationBarTitle("Schedule")
                    .navigationBarItems(trailing: Button(action: {
                        self.generatedEvents = ScheduleGenerator(
                                allEvents: self.dataStore.events,
                                storedEventIds: self.settings.savedEvents,
                                allArtists: self.dataStore.artists,
                                artistRatings: self.settings.ratings
                        ).generate()
                        self.showingSheet = true
                    }) {
                        Text("Generate")
                    })
                    .onAppear {
                        if self.selectedDay == -1 {
                            self.selectedDay = self.eventDays.first ?? -1
                        }
                    }
                    .sheet(isPresented: $showingSheet) {
                        GeneratedScheduleView(generatedEvents: self.$generatedEvents)
                                .environmentObject(self.dataStore)
                                .environmentObject(self.settings)
                    }
        }
    }
}

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView()
    }
}
