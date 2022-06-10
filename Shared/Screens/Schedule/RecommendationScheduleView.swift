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

    var shownEvents: LoadingEntity<[Event]> {
        dataStore.data.map { entities in
            let savedEvents = entities.events.filter { (event: Event) in
                storedEvents.contains(event.id)
            }
            if showingRecommendations {
                let recommendations = ScheduleGenerator2(
                        allEvents: entities.events,
                        storedEventIds: self.settings.savedEvents,
                        allArtists: entities.artists,
                        artistRatings: self.settings.ratings
                ).generate()
                return recommendations
            } else {
                return savedEvents
            }
        }
    }

    var body: some View {
        NavigationView {
            switch shownEvents {
                case .loading:
                    Text("events.loading") // TODO: translate
                case .failure(let reason):
                    Text("Failed to load: " + reason.rawValue)
                case .success(let events):
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
            }
        }
    }
}

struct RecommendationScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationScheduleView()
    }
}
