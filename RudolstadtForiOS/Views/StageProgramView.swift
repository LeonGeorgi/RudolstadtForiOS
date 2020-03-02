//
//  StageProgramView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct StageProgramView: View {

    let data: FestivalData

    @State var selectedDay: Int = 0

    func eventsByStage(day: Int) -> Dictionary<Stage, [Event]> {
        return Dictionary(grouping: data.events.filter { event in
            event.festivalDay == day + 5 // TODO
        }) { (event: Event) in
            event.stage
        }
    }

    func sortStages(_ stages: [Stage]) -> [Stage] {
        return stages.sorted { (first: Stage, second: Stage) in
                    first.id < second.id
                }
                .sorted { (first: Stage, second: Stage) in
                    first.area.id < second.area.id
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
            List {
                ForEach(sortStages(Array(eventsByStage(day: selectedDay).keys))) { (stage: Stage) in
                    Section(header: Text("\(stage.germanName)")) {
                        ForEach(self.eventsByStage(day: self.selectedDay)[stage] ?? []) { (event: Event) in
                            NavigationLink(destination: EventDetailView(
                                    event: event,
                                    data: self.data
                            )) {
                                ProgramEventItem(event: event)
                            }
                        }
                    }
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

struct StageProgramView_Previews: PreviewProvider {
    static var previews: some View {
        StageProgramView(data: .example)
    }
}
