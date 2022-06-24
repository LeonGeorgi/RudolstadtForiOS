//
//  MapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 13.06.22.
//

import SwiftUI
import MapKit

struct MapOverview: View {

    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var settings: UserSettings

    @State var mode: Mode = .map


    func annotationItems(entities: Entities) -> [MapLocation] {
        entities.stages.filter { stage in
                    stage.getAdjustedStageNumber(stageNumberType: settings.stageNumberType) != nil
                }
                .map { stage in
                    MapLocation(
                            stage: stage,
                            stageNumber: stage.getAdjustedStageNumber(stageNumberType: settings.stageNumberType),
                            coordinate: CLLocationCoordinate2D(latitude: stage.latitude, longitude: stage.longitude)
                    )
                }

    }

    var body: some View {
        NavigationView {
            switch dataStore.data {
            case .loading:
                Text("map.loading")
            case .failure(let reason):
                Text("Failed to load: " + reason.rawValue)
            case .success(let entites):
                VStack {

                    if mode == .map {
                        MapView(locations: annotationItems(entities: entites))
                    } else {
                        LocationListView()
                    }

                }
                        .navigationBarTitle("locations.title", displayMode: .inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(mode == .map ? "list.title" : "map.title") {
                                    if mode == .map {
                                        mode = .list
                                    } else {
                                        mode = .map
                                    }
                                }
                            }
                        }

            }


        }
    }
}

enum Mode {
    case map, list
}

struct MapLocation: Identifiable {
    let id = UUID()
    let stage: Stage
    let stageNumber: Int?
    let coordinate: CLLocationCoordinate2D
}

struct MapOverview_Previews: PreviewProvider {
    static var previews: some View {
        MapOverview()
    }
}
