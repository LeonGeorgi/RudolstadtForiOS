//
//  ScheduleView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct RecommendationScheduleView: View {
    
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings
    
    @State private var viewAsTable = true
    @State private var scheduleType = ScheduleType.all
    
    var storedEvents: [Int] {
        settings.savedEvents
    }
    
    var interestingArtists: [Int] {
        settings.ratings.filter { element in
            element.value > 0
        }.keys.map { a in Int(a)! }
    }
    
    func generateShownEvents(events: [Event]) -> [Event]? {
        switch scheduleType {
        case .saved:
            return events.filter { event in
                storedEvents.contains(event.id)
            }
        case .optimal:
            if let recommendations = dataStore.recommendedEvents {
                return events.filter { event in
                    storedEvents.contains(event.id) || recommendations.contains(event.id)
                }
            } else {
                return []
            }
        case .interesting:
            print(interestingArtists)
            return events.filter { event in
                storedEvents.contains(event.id) || interestingArtists.contains(event.artist.id)
            }
        case .all:
            return events
        }
    }
    
    var shownEvents: LoadingEntity<[Event]?> {
        dataStore.data.map { entities in
            switch scheduleType {
            case .saved:
                return entities.events.filter { event in
                    storedEvents.contains(event.id)
                }
            case .optimal:
                if let recommendations = dataStore.recommendedEvents {
                    return entities.events.filter { event in
                        storedEvents.contains(event.id) || recommendations.contains(event.id)
                    }
                } else {
                    return nil
                }
            case .interesting:
                print(interestingArtists)
                return entities.events.filter { event in
                    storedEvents.contains(event.id) || interestingArtists.contains(event.artist.id)
                }
            case .all:
                return entities.events
            }
        }
    }
    
    var body: some View {
        NavigationView {
            switch dataStore.data {
            case .loading:
                Text("events.loading")
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success(let entities):
                let shownEvents = generateShownEvents(events: entities.events)
                let eventDays = Set(entities.events.lazy.map { (event: Event) in
                    event.festivalDay
                }).sorted(by: <)
                
                if let events = shownEvents {
                    RecommendationScheduleContentView(events: events, viewAsTable: viewAsTable, eventDays: eventDays)
                        .navigationBarTitle("schedule.title", displayMode: .inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    viewAsTable.toggle()
                                } label: {
                                    if (viewAsTable) {
                                        Text("List")
                                    } else {
                                        Text("Table")
                                    }
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Picker("Test", selection: $scheduleType) {
                                    Text("schedule.type.saved")
                                        .tag(ScheduleType.saved)
                                    Text("schedule.type.optimal")
                                        .tag(ScheduleType.optimal)
                                    Text("schedule.type.interesting")
                                        .tag(ScheduleType.interesting)
                                    Text("schedule.type.all")
                                        .tag(ScheduleType.all)
                                    
                                }
                            }
                        }
                } else {
                    Text("recommendations.loading")
                }
                
            }
        }
    }
}

enum ScheduleType {
    case saved, optimal, interesting, all
}

struct RecommendationScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationScheduleView()
            .environmentObject(DataStore())
    }
}
