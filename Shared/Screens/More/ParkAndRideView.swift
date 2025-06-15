//
//  ParkAndRide.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import MapKit
import SwiftUI

struct ParkAndRideView: View {

    let parking = [
        PRLocation(
            name: String(
                localized: "park_and_ride.parking.raiffeisenstraße.title"
            ),
            description: String(
                localized: "park_and_ride.parking.raiffeisenstraße.description"
            ),
            latitude: 50.723778,
            longitude: 11.364995,
            iconName: "mappin.and.ellipse"
        ),
        PRLocation(
            name: String(
                localized: "park_and_ride.parking.erich-correns-ring.title"
            ),
            description: String(
                localized:
                    "park_and_ride.parking.erich-correns-ring.description"
            ),
            latitude: 50.701339,
            longitude: 11.317835,
            iconName: "mappin.and.ellipse"
        ),
    ]

    var body: some View {
        List {
            Section(
                header: Text("park_and_ride.navi.title")
            ) {
               Text("park_and_ride.navi.description")
                
            }
            Section(
                header: Text("park_and_ride.shuttle.title"),
                footer: Text("park_and_ride.click_hint")
            ) {
                ForEach(parking) { location in
                    Button(action: {
                        openInMaps(
                            name: location.name,
                            latitude: location.latitude,
                            longitude: location.longitude
                        )
                    }) {
                        HStack(alignment: .top) {
                            Image(systemName: location.iconName)
                                .foregroundColor(.accentColor)
                                .frame(width: 35, alignment: .center)
                                .font(.system(size: 20))
                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                Text(location.description)
                                    .font(.subheadline)
                            }
                        }
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }.listStyle(GroupedListStyle())
            .navigationTitle("park_and_ride.title")

    }
    func openInMaps(name: String, latitude: Double, longitude: Double) {

        let center = CLLocationCoordinate2D(
            latitude: 50.719877,
            longitude: 11.338449
        )
        let latDistance = abs(center.latitude - latitude)
        let longDistance = abs(center.longitude - longitude)

        let latDelta = max(0.01, latDistance * 2)
        let longDelta = max(0.01, longDistance * 2)

        let coordinates = CLLocationCoordinate2DMake(latitude, longitude)
        let regionSpan = MKCoordinateRegion(
            center: center,
            latitudinalMeters: latDelta,
            longitudinalMeters: longDelta
        )
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(
                mkCoordinate: regionSpan.center
            ),
            MKLaunchOptionsMapSpanKey: NSValue(
                mkCoordinateSpan: regionSpan.span
            ),
        ]
        let placemark = MKPlacemark(
            coordinate: coordinates,
            addressDictionary: nil
        )
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
    let iconName: String
}

struct ParkAndRideView_Previews: PreviewProvider {
    static var previews: some View {
        ParkAndRideView()
    }
}
