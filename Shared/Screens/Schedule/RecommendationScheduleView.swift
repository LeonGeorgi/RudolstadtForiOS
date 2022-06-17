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

    @State private var showingRecommendations = true

    var storedEvents: [Int] {
        settings.savedEvents
    }
    
    var shownEvents: LoadingEntity<[Event]?> {
        dataStore.data.map { entities in
            if showingRecommendations {
                if let recommendations = dataStore.recommendedEvents {
                    return entities.events.filter { event in
                        storedEvents.contains(event.id) || recommendations.contains(event.id)
                    }
                } else {
                    return nil
                }
            } else {
                return entities.events.filter { event in
                    storedEvents.contains(event.id)
                }
            }
        }
    }

    var body: some View {
        NavigationView {
            switch shownEvents {
                case .loading:
                    Text("events.loading")
                case .failure(let reason):
                    Text("Failed to load: " + reason.rawValue)
                case .success(let events):
                if let events = events {
                    ScheduleView(events: events)
                        .navigationBarTitle("schedule.title", displayMode: .inline)
                        .navigationBarItems(trailing: Button(action: {
                            self.showingRecommendations.toggle()
                        }) {
                            if showingRecommendations {
                                Text("schedule.recommendations.disable")
                            } else {
                                Text("schedule.recommendations.enable")
                            }
                        })
                } else {
                    Text("recommendations.loading")
                }
                    
            }
        }
    }
}

struct RecommendationScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationScheduleView()
    }
}
