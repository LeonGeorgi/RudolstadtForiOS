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

    @State var selectedDay: Int = 0

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
            List(dataStore.events.filter {
                $0.festivalDay == selectedDay + 5
            }) { (event: Event) in
                NavigationLink(destination: EventDetailView(
                        event: event
                )) {
                    ProgramEventItem(event: event)
                }
            }
        }

                .navigationBarTitle("Program", displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    // TODO
                }) {
                    Text("Filter")
                })

    }
}

struct TimeProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}
