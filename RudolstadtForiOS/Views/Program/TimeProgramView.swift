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


    @State var selectedDay: Int = 0

    func filteredEvents() -> [Event] {
        return dataStore.events.filter { event in
            selectedArtistTypes.contains(event.artist.artistType)
        }
    }

    var body: some View {
        VStack {
            Picker("Date", selection: $selectedDay) {
                ForEach(0..<4) { day in
                    Text("\(day)").tag(day)

                }
            }
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
                    .pickerStyle(SegmentedPickerStyle())
            List(filteredEvents().filter {
                $0.festivalDay == selectedDay + 5
            }) { (event: Event) in
                NavigationLink(destination: EventDetailView(
                        event: event
                )) {
                    ProgramEventCell(event: event)
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

    }
}

struct TimeProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}
