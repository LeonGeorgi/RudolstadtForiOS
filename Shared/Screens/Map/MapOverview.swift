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
    
    var annotationItems: LoadingEntity<[MapLocation]> {
        dataStore.data.map { entities in
            entities.stages.filter { stage in
                stage.stageNumber != nil
            }.map { stage in
                MapLocation(stage: stage, coordinate: CLLocationCoordinate2D(latitude: stage.latitude, longitude: stage.longitude))
            }
        }
    }

    var body: some View {
        NavigationView {
            switch annotationItems {
                case .loading:
                    Text("map.loading")
                case .failure(let reason):
                    Text("Failed to load: " + reason.rawValue)
                case .success(let locations):
                VStack {
                    
                    if settings.mapType == 0 {
                        MapView(locations: locations).equatable()
                    } else {
                        LocationListView()
                    }
                    
                }.navigationBarTitle("locations.title", displayMode: .inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(settings.mapType == 0 ? "list.title" : "map.title") {
                                settings.toggleMapType()
                            }
                        }
                    }

            }
            
                
        }
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
