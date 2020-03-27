//
//  StageProgramView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct SavedArtistProgramView: View {

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    func filteredEvents() -> [Event] {
        let ratedArtistIds = settings.ratings.filter { entry in
            entry.value > 0
        }.map { (entry) in
            Int(entry.key)!
        }
        return dataStore.events.filter { event in
            ratedArtistIds.contains(event.artist.id)
        }
    }

    @State var selectedDay: Int = -1

    var eventDays: [Int] {
        return Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        }).sorted(by: <)
    }

    var body: some View {
        VStack {
            Picker("Date", selection: $selectedDay) {
                ForEach(eventDays) { (day: Int) in
                    Text(Util.shortWeekDay(day: day)).tag(day)

                }
            }.padding(.leading, 10)
                    .padding(.trailing, 10)
                    .pickerStyle(SegmentedPickerStyle())
            List(filteredEvents().filter {
                $0.festivalDay == selectedDay
            }) { (event: Event) in
                NavigationLink(destination: EventDetailView(
                        event: event
                )) {
                    SavedArtistEventCell(event: event)
                }
            }
        }.onAppear {
            if self.selectedDay == -1 {
                self.selectedDay = self.eventDays.first ?? -1
            }
        }

    }
}

struct SavedArtistProgramView_Previews: PreviewProvider {
    static var previews: some View {
        StageProgramView()
    }
}
