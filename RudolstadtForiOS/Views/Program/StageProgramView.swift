//
//  StageProgramView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct StageProgramView: View {

    @EnvironmentObject var dataStore: DataStore

    @State var selectedDay: Int = -1

    var events: Dictionary<Int, [StageEvents]> {
        var result: Dictionary<Int, Dictionary<Stage, [Event]>> = Dictionary()
        for event in dataStore.events {
            if !result.keys.contains(event.festivalDay) {
                result[event.festivalDay] = Dictionary()
            }
            if !result[event.festivalDay]!.keys.contains(event.stage) {
                result[event.festivalDay]![event.stage] = []
            }
            result[event.festivalDay]![event.stage]!.append(event)
        }
        return result.mapValues { dictionary in
            sortStages(Array(dictionary.map { stage, events in
                StageEvents(stage: stage, events: events)
            }))
        }
    }

    var eventDays: [Int] {
        events.keys.sorted()
    }

    func sortStages(_ stages: [StageEvents]) -> [StageEvents] {
        return stages.sorted { (first: StageEvents, second: StageEvents) in
                    first.stage.id < second.stage.id
                }
                .sorted { (first: StageEvents, second: StageEvents) in
                    first.stage.area.id < second.stage.area.id
                }
    }

    var body: some View {
        VStack {
            Picker("Date", selection: $selectedDay) {
                ForEach(eventDays) { (day: Int) in
                    Text(self.shortWeekDay(day: day)).tag(day)

                }
            }.padding(.leading, 10)
                    .padding(.trailing, 10)
                    .pickerStyle(SegmentedPickerStyle())
            List {
                ForEach(events[selectedDay] ?? []) { (item: StageEvents) in
                    Section(header: Text("\(item.stage.germanName)")) {
                        ForEach(item.events) { (event: Event) in
                            NavigationLink(destination: EventDetailView(
                                    event: event
                            )) {
                                ProgramEventItem(event: event)
                            }
                        }
                    }
                }
            }
        }.navigationBarTitle("Program", displayMode: .inline)
                .navigationBarItems(trailing: Button(action: {
                    // TODO
                }) {
                    Text("Filter")
                })
                .onAppear {
                    if self.selectedDay == -1 {
                        self.selectedDay = self.eventDays.first ?? -1
                    }
                }

    }

    func shortWeekDay(day: Int) -> String {
        var dateComponents = DateComponents()
        dateComponents.year = 2018
        dateComponents.month = 7
        dateComponents.day = day
        dateComponents.timeZone = TimeZone(abbreviation: "CEST")

        let userCalendar = Calendar.current // user calendar
        let date = userCalendar.date(from: dateComponents)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EE"
        return dateFormatter.string(from: date)
    }
}

struct StageEvents: Identifiable {
    var id: Int {
        stage.id // TODO
    }

    let stage: Stage
    let events: [Event]
}

extension Date: Identifiable {
    public var id: Int {
        self.hashValue
    }
}

struct StageProgramView_Previews: PreviewProvider {
    static var previews: some View {
        StageProgramView()
    }
}
