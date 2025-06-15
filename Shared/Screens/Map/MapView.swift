//
//  ActualMapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 14.06.22.
//

import MapKit
import SwiftUI

struct MapView: View, Equatable {
    static func == (lhs: MapView, rhs: MapView) -> Bool {
        lhs.locations.map { location in
            location.stage.id
        }
            == rhs.locations.map { location in
                location.stage.id
            }
    }

    var locations: [MapLocation]

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 50.719877,
            longitude: 11.338449
        ),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )

    @StateObject private var manager = LocationManager()

    var body: some View {
        VStack(alignment: .leading) {

            ZStack(alignment: .top) {

                Map(
                    coordinateRegion: $mapRegion,
                    showsUserLocation: true,
                    annotationItems: locations
                ) { annotation in
                    MapAnnotation(coordinate: annotation.coordinate) {
                        NavigationLink(
                            destination: StageDetailView(
                                stage: annotation.stage,
                                highlightedEventId: nil
                            )
                        ) {
                            VStack {
                                StageNumber(
                                    stage: annotation.stage,
                                    size: 25,
                                    font: .system(size: 15)
                                )
                            }
                        }
                    }
                }
                .mapStyle(
                    .standard(
                        elevation: .realistic,
                        pointsOfInterest: .including([.atm]),
                    )
                )
                .accentColor(.blue)
                .onAppear {
                    manager.startLocationTracking()
                }

                HStack(alignment: .center, spacing: 20) {
                    HStack(alignment: .center) {
                        renderCircle(
                            Color(
                                hue: 24 / 360,
                                saturation: 0.6,
                                brightness: 0.9
                            )
                        )
                        Text("ticket.type.festival")
                    }

                    HStack(alignment: .center) {
                        renderCircle(
                            Color(
                                hue: 116 / 360,
                                saturation: 0.2,
                                brightness: 0.7
                            )
                        )
                        Text("ticket.type.day-and-festival")
                    }

                    HStack(alignment: .center) {
                        renderCircle(
                            Color(
                                hue: 35 / 360,
                                saturation: 0.4,
                                brightness: 0.8
                            )
                        )
                        Text("ticket.type.other")
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal)
                .background(.thinMaterial)
                .cornerRadius(10)
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.top, 10)
                .padding(.horizontal)
            }

            Text("map.warning.stage-numbers")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.horizontal)
                .padding(.bottom, 10)

        }

    }

    private func renderCircle(_ color: Color) -> some View {
        Circle().frame(width: 15, height: 15)
            .foregroundColor(color)
            .overlay(
                Circle()
                    .stroke(Color.gray, lineWidth: 1)
                    .opacity(0.3)
            )
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
