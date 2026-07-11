//
//  MapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 13.06.22.
//

import MapKit
import SwiftUI

struct MapOverview: View {

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject var settings: UserSettings
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.locationsScreen
    )

    var annotationItems: [MapLocation] {
        festivalData.stages.filter { stage in
            stage.stageNumber != nil
        }.map { stage in
            MapLocation(
                stage: stage,
                coordinate: CLLocationCoordinate2D(
                    latitude: stage.latitude,
                    longitude: stage.longitude
                )
            )
        }
    }

    var body: some View {
        VStack {
            if settings.mapType == 0 {
                MapView(
                    locations: annotationItems,
                    currentTipID: tipSequencer.currentTipID
                )
                .equatable()
            } else {
                LocationListView()
            }
        }
        .navigationBarTitle("locations.title", displayMode: .inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    settings.toggleMapType()
                } label: {
                    Image(systemName: settings.mapType == 0 ? "list.bullet" : "map")
                }
                .accessibilityLabel(settings.mapType == 0 ? "list.title" : "map.title")
                .accessibilityIdentifier("locations-view-mode-toggle")
                .appPopoverTip(
                    DiscoverabilityTips.locationsViewMode,
                    currentTipID: tipSequencer.currentTipID,
                    arrowEdge: .top
                )
            }

            NewsToolbarItem()
        }
        .toolbarBackground(
            settings.mapType == 0 ? .hidden : .visible,
            for: .navigationBar
        )
    }
}

struct MapLocation: Identifiable {
    let id = UUID()
    let stage: Stage
    let coordinate: CLLocationCoordinate2D
}

struct MapOverview_Previews: PreviewProvider {
    static var previews: some View {
        MapOverview()
    }
}
