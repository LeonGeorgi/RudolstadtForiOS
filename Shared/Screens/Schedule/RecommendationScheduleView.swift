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

    var shownEvents: [Event] {
        let savedEvents = dataStore.events.filter { (event: Event) in
            storedEvents.contains(event.id)
        }
        if showingRecommendations {
            let recommendations = ScheduleGenerator2(
                    allEvents: self.dataStore.events,
                    storedEventIds: self.settings.savedEvents,
                    allArtists: self.dataStore.artists,
                    artistRatings: self.settings.ratings
            ).generate()
            return recommendations
        } else {
            return savedEvents
        }
    }

    var body: some View {
        NavigationView {
            ScheduleView(events: shownEvents)
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

struct RecommendationScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationScheduleView()
    }
}