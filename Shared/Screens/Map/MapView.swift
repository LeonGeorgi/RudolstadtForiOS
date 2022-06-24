//
//  ActualMapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 14.06.22.
//

import SwiftUI
import MapKit

struct MapView: View, Equatable {
    static func ==(lhs: MapView, rhs: MapView) -> Bool {
        lhs.locations.map { location in
            location.stage.id
        } == rhs.locations.map { location in
            location.stage.id
        }
    }

    var locations: [MapLocation]

    @State private var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 50.719877, longitude: 11.338449), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))

    @StateObject private var manager = LocationManager()


    var body: some View {
        Map(coordinateRegion: $mapRegion, showsUserLocation: true, annotationItems: locations) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                NavigationLink(destination: StageDetailView(stage: annotation.stage)) {
                    VStack {
                        StageNumber(stage: annotation.stage, size: 25, font: .system(size: 15))
                    }
                }
            }
        }
                .accentColor(.blue)
                .onAppear {
                    manager.startLocationTracking()
                }

    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
    }

    func startLocationTracking() {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(locations: [])
    }
}
