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
    @State var showStoredEvents = true
    @State var alertEvent: Event?

    var eventDays: [Int] {
        Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        }).sorted(by: <)
    }

    func eventsToShow() -> [Event] {
        var recommendations: [Event]
        if smartRecommendations {
            recommendations = ScheduleGenerator(
                    allEvents: self.dataStore.events,
                    storedEventIds: self.settings.savedEvents,
                    allArtists: self.dataStore.artists,
                    artistRatings: self.settings.ratings
            ).generate()
        } else {
            let savedEvents = dataStore.events.filter { event in
                settings.savedEvents.contains(event.id)
            }
            recommendations = dataStore.events.filter { event in
                settings.ratings.keys.contains(String(event.artist.id)) &&
                        savedEvents.allSatisfy {
                            $0.artist.id != event.artist.id
                        } && !intersects(events: savedEvents, current: event)

            }
        }
        if !showStoredEvents {
            return recommendations
        }
        let savedEvents = dataStore.events.filter { event in
            settings.savedEvents.contains(event.id)
        }
        recommendations.append(contentsOf: savedEvents)
        recommendations.sort { event, event2 in
            event.festivalDay < event2.festivalDay || event.startTimeInMinutes < event2.startTimeInMinutes
        }
        return recommendations
    }

    func intersects(events: [Event], current: Event) -> Bool {
        return events.contains { event in
            let collides = intersect(first: event, second: current)
            return collides
        }
    }

    func intersect(first: Event, second: Event) -> Bool {
        first.festivalDay == second.festivalDay &&
                !(first.startTimeInMinutes >= second.endTimeInMinutes || first.endTimeInMinutes <= second.startTimeInMinutes)
    }

    func createAlert() -> Alert {
        if alertEvent != nil {
            return Alert(
                    title: Text("Save \"\(alertEvent!.artist.name)\" at \(alertEvent!.shortWeekDay) \(alertEvent!.timeAsString)?"),
                    message: Text("event.save.alert.message"),
                    primaryButton: .default(Text("event.save")) {
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
            }.navigationBarTitle(Text(""), displayMode: .inline).navigationBarItems(leading: Button(action: {
                        self.showStoredEvents.toggle()
                    }) {
                        self.showStoredEvents ? Text("recommendations.hide_saved") : Text("recommendations.show_saved")
                    }, trailing: Button(action: {
                        self.smartRecommendations.toggle()
                    }) {
                        self.smartRecommendations ? Text("recommendations.all") : Text("recommendations.smart")
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
