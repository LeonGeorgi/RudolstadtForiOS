//
//  MapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 13.06.22.
//

import SwiftUI

struct MapOverview: View {

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject var settings: UserSettings
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.locationsScreen
    )

    var body: some View {
        VStack {
            if settings.mapType == 0 {
                MapView(
                    stages: festivalData.stages,
                    currentTipID: tipSequencer.currentTipID
                )
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
        }
        .toolbarBackground(
            settings.mapType == 0 ? .hidden : .visible,
            for: .navigationBar
        )
    }
}

struct MapOverview_Previews: PreviewProvider {
    static var previews: some View {
        MapOverview()
    }
}
