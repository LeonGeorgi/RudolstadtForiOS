//
//  ProgramView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct TimeProgramView: View {

    @EnvironmentObject var dataStore: DataStore
    @State private var showingSheet = false
    @State var selectedArtistTypes = Set(ArtistType.allCases)


    @State var selectedDay: Int = -1

    var eventDays: [Int] {
        return Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        }).sorted(by: <)
    }

    func filteredEvents() -> [Event] {
        return dataStore.events.filter { event in
            selectedArtistTypes.contains(event.artist.artistType)
        }
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
            List(filteredEvents().filter {
                $0.festivalDay == selectedDay
            }) { (event: Event) in
                NavigationLink(destination: EventDetailView(
                        event: event
                )) {
                    TimeProgramEventCell(event: event)
                }
            }
        }.navigationBarTitle("Program", displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    self.showingSheet = true
                }) {
                    Text("Filter")
                })
                .sheet(isPresented: $showingSheet) {
                    NavigationView {
                        ArtistTypeFilterView(selectedArtistTypes: self.$selectedArtistTypes)
                                .navigationBarItems(trailing: Button(action: { self.showingSheet = false }) {
                                    Text("Done")
                                })
                    }
                }

        .onAppear {
            if self.selectedDay == -1 {
                self.selectedDay = self.eventDays.first ?? -1
            }
        }

    }
}

struct TimeProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}
