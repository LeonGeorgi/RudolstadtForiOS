//
//  ActualMapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 14.06.22.
//

import SwiftUI
import MapKit

struct MapView: View {
    var locations: [MapLocation]
    
    @State private var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 50.719877, longitude: 11.338449), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
    
    @StateObject private var manager = LocationManager()

    
    var body: some View {
        Map(coordinateRegion: $mapRegion, showsUserLocation: true, annotationItems: locations) { annotation in
            MapAnnotation(coordinate: annotation.coordinate) {
                NavigationLink(destination: StageDetailView(stage: annotation.stage)) {
                    Text(annotation.stage.stageNumber.map(String.init) ?? "")
                        .font(.system(size: 15))
                        .frame(width: 25, height: 25)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 1)
                                .brightness(-0.1)
                        )
                }.accentColor(.red)
            }
        }.accentColor(.blue)
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
