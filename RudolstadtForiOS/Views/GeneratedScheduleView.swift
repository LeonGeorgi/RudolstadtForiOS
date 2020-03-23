//
//  ScheduleView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct GeneratedScheduleView: View {

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    @State private var showingSheet = false
    @State private var showingAlert = false
    @State var selectedDay: Int = -1
    @State var smartRecommendations = false
    @State var alertEvent: Event?

    var eventDays: [Int] {
        Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        }).sorted(by: <)
    }

    func eventsToShow() -> [Event] {
        if smartRecommendations {
            return ScheduleGenerator(
                            allEvents: self.dataStore.events,
                            storedEventIds: self.settings.savedEvents,
                            allArtists: self.dataStore.artists,
                            artistRatings: self.settings.ratings
                    ).generate()
        } else {
            let savedEvents = dataStore.events.filter { event in
                settings.savedEvents.contains(event.id)
            }
            return dataStore.events.filter { event in
                savedEvents.contains {
                    $0.id == event.id
                } || (
                        settings.ratings.keys.contains(String(event.artist.id)) &&
                                savedEvents.contains {
                                    $0.artist.id != event.artist.id
                                } && !intersects(events: savedEvents, current: event)
                )
            }
        }
    }

    func intersects(events: [Event], current: Event) -> Bool {
        return events.contains { event in
            let collides = intersect(first: event, second: current)
            return collides
        }
    }

    func intersect(first: Event, second: Event) -> Bool {
        first.festivalDay == second.festivalDay &&
                !(first.startTimeInMinutes > second.endTimeInMinutes || first.endTimeInMinutes < second.startTimeInMinutes)
    }

    func createAlert() -> Alert {
        if alertEvent != nil {
            return Alert(
                    title: Text("Save \(alertEvent!.artist.name) at \(alertEvent!.shortWeekDay) \(alertEvent!.timeAsString)?"),
                    message: Text("The event will be added to your schedule."),
                    primaryButton: .default(Text("Save")) {
                        if !self.settings.savedEvents.contains(self.alertEvent!.id) {
                            self.settings.savedEvents.append(self.alertEvent!.id)
                        }
                    }, secondaryButton: .cancel())
        } else {
            return Alert(title: Text("Something went wrong"))
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                Picker("Date", selection: $selectedDay) {
                    ForEach(eventDays) { (day: Int) in
                        Text(Util.shortWeekDay(day: day)).tag(day)
                    }
                }.padding(.leading, 10)
                        .padding(.trailing, 10)
                        .pickerStyle(SegmentedPickerStyle())

                List(eventsToShow().filter { (event: Event) in
                    event.festivalDay == selectedDay
                }) { event in
                    Button(action: {
                        self.alertEvent = event
                        self.showingAlert = true
                    }) {
                        TimeProgramEventCell(event: event)
                    }.buttonStyle(PlainButtonStyle())
                            .disabled(self.settings.savedEvents.contains(event.id))
                }
            }.navigationBarTitle("Generated events", displayMode: .inline)
                    .navigationBarItems(trailing: Button(action: {
                        self.smartRecommendations.toggle()
                    }) {
                        Text(self.smartRecommendations ? "All" : "Best")
                    })
                    .onAppear {
                        if self.selectedDay == -1 {
                            self.selectedDay = self.eventDays.first ?? -1
                        }
                    }
                    .alert(isPresented: self.$showingAlert) {
                        createAlert()
                    }
        }
    }
}

struct GeneratedScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView()
    }
}
