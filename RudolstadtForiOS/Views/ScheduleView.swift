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

    @State private var showingRecommendations = true
    @State var selectedDay: Int = -1

    var eventDays: [Int] {
        Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        }).sorted(by: <)
    }

    var storedEvents: [Int] {
        settings.savedEvents
    }

    var shownEvents: [Event] {
        let savedEvents = dataStore.events.filter { (event: Event) in
            storedEvents.contains(event.id)
        }
        if showingRecommendations {
            var recommendations = ScheduleGenerator(
                    allEvents: self.dataStore.events,
                    storedEventIds: self.settings.savedEvents,
                    allArtists: self.dataStore.artists,
                    artistRatings: self.settings.ratings
            ).generate()
            recommendations.append(contentsOf: savedEvents)
            recommendations.sort { event, event2 in
                event.festivalDay < event2.festivalDay || event.startTimeInMinutes < event2.startTimeInMinutes
            }
            return recommendations
        } else {
            return savedEvents
        }
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

                List(shownEvents.filter { event in
                    event.festivalDay == selectedDay
                }) { event in
                    NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                        ScheduleEventCell(event: event)
                    }
                }
            }.navigationBarTitle("schedule.title", displayMode: .inline)
                    .navigationBarItems(trailing: Button(action: {
                        self.showingRecommendations.toggle()
                    }) {
                        if showingRecommendations {
                            Text("schedule.recommendations.disable")
                        } else {
                            Text("schedule.recommendations.enable")
                        }
                    })
                    .onAppear {
                        if self.selectedDay == -1 {
                            self.selectedDay = self.eventDays.first ?? -1
                        }
                    }
        }
    }
}

struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView()
    }
}
