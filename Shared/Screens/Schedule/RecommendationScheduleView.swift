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
    
    var storedEvents: [Int] {
        settings.savedEvents
    }
    
    var interestingArtists: [Int] {
        settings.ratings.filter { element in
            element.value > 0
        }.keys.map { a in Int(a)! }
    }
    
    func generateShownEvents(events: [Event]) -> [Event]? {
        switch settings.getScheduleFilterType(settings.scheduleFilterType) {
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
                    RecommendationScheduleContentView(events: events, viewAsTable: settings.scheduleViewType == 0, eventDays: eventDays)
                        .navigationBarTitle("schedule.title", displayMode: .inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    settings.toggleScheduleViewType()
                                } label: {
                                    if (settings.scheduleViewType == 0) {
                                        Text("schedule.list.button")
                                    } else {
                                        Text("schedule.table.button")
                                    }
                                }
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Picker("Test", selection: Binding<ScheduleType>(get: {
                                    settings.getScheduleFilterType(settings.scheduleFilterType)
                                }, set: { (type: ScheduleType) in
                                    settings.setScheduleFilterType(type: type)
                                })) {
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
