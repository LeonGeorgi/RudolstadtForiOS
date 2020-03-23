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

    @State private var showingSheet = false
    @State var selectedDay: Int = -1
    @Binding var generatedEvents: [Event]

    var eventDays: [Int] {
        Set(dataStore.events.lazy.map { (event: Event) in
            event.festivalDay
        }).sorted(by: <)
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

                List(generatedEvents.filter { (event: Event) in
                    event.festivalDay == selectedDay
                }) { event in
                    TimeProgramEventCell(event: event)
                }
            }.navigationBarTitle("Generated events", displayMode: .inline)
                    .onAppear {
                        if self.selectedDay == -1 {
                            self.selectedDay = self.eventDays.first ?? -1
                        }
                    }
        }
    }
}

struct GeneratedScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView()
    }
}
