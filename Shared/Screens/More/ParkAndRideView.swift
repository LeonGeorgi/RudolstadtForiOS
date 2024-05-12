//
//  ParkAndRide.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI
import MapKit


struct ParkAndRideView: View {
    
    let campsites = [
        PRLocation(
            name: String(localized: "park_and_ride.campsite.große_wiese.title"),
            description: String(localized: "park_and_ride.campsite.große_wiese.description"),
            latitude: 50.709175, longitude: 11.326351
        ),
        PRLocation(
            name: String(localized: "park_and_ride.campsite.saalemax.title"),
            description: String(localized: "park_and_ride.campsite.saalemax.description"),
            latitude: 50.705561, longitude: 11.316845
        ),
        PRLocation(
            name: String(localized: "park_and_ride.campsite.caravan.title"),
            description: String(localized: "park_and_ride.campsite.caravan.description"),
            latitude: 50.717568, longitude: 11.345529
        )
    ]
    
    let parking = [
        PRLocation(
            name: String(localized: "park_and_ride.parking.oststraße.title"),
            description: String(localized: "park_and_ride.parking.oststraße.description"),
            latitude: 50.722715, longitude: 11.359555
        ),
        PRLocation(
            name: String(localized: "park_and_ride.parking.raiffeisenstraße.title"),
            description: String(localized: "park_and_ride.parking.raiffeisenstraße.description"),
            latitude: 50.723778, longitude: 11.364995
        ),
        PRLocation(
            name: String(localized: "park_and_ride.parking.erich-correns-ring.title"),
            description: String(localized: "park_and_ride.parking.erich-correns-ring.description"),
            latitude: 50.701339, longitude: 11.317835
        )
    ]
    var body: some View {
        List {
            Section(header: Text("park_and_ride.navi.title"), footer: Text("park_and_ride.click_hint")) {
                ForEach(campsites) { location in
                    Button(action: {
                        openInMaps(name: location.name, latitude: location.latitude, longitude: location.longitude)
                    }) {
                        VStack(alignment: .leading) {
                            Text(location.name)
                                .font(.headline)
                            Text(location.description)
                                .font(.subheadline)
                        }
                    }.buttonStyle(PlainButtonStyle())
                }
            }
            Section(header: Text("park_and_ride.shuttle.title"), footer: Text("park_and_ride.click_hint")) {
                ForEach(parking) { location in
                    Button(action: {
                        openInMaps(name: location.name, latitude: location.latitude, longitude: location.longitude)
                    }) {
                        VStack(alignment: .leading) {
                            Text(location.name)
                                .font(.headline)
                            Text(location.description)
                                .font(.subheadline)
                        }
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }.listStyle(GroupedListStyle())
            .navigationTitle("park_and_ride.title")
        
    }
    func openInMaps(name: String, latitude: Double, longitude: Double) {
        
            let center = CLLocationCoordinate2D(latitude: 50.719877, longitude: 11.338449)
            let latDistance = abs(center.latitude - latitude)
            let longDistance = abs(center.longitude - longitude)

            let latDelta = max(0.01, latDistance * 2)
            let longDelta = max(0.01, longDistance * 2)

            let coordinates = CLLocationCoordinate2DMake(latitude, longitude)
            let regionSpan = MKCoordinateRegion(center: center, latitudinalMeters: latDelta, longitudinalMeters: longDelta)
            let options = [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
                MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
            ]
            let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = name
            mapItem.openInMaps(launchOptions: options)
    }
}

struct PRLocation: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let latitude: Double
    let longitude: Double
}

struct ParkAndRideView_Previews: PreviewProvider {
    static var previews: some View {
        ParkAndRideView()
    }
}
