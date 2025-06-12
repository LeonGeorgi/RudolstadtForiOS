//
//  StageMapView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 26.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation
import MapKit
import SwiftUI

struct StageMapView: UIViewRepresentable {
    let stage: Stage
    fileprivate let locationManager = CLLocationManager()

    func makeUIView(context: Context) -> MKMapView {
        let view = MKMapView()
        updateStage(from: view)
        let center = CLLocationCoordinate2D(
            latitude: 50.719877,
            longitude: 11.338449
        )
        let latDistance = abs(center.latitude - stage.latitude)
        let longDistance = abs(center.longitude - stage.longitude)

        let latDelta = max(0.01, latDistance * 2)
        let longDelta = max(0.01, longDistance * 2)

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: CLLocationDistance(exactly: latDelta)!,
                longitudeDelta: CLLocationDistance(exactly: longDelta)!
            )
        )
        view.setRegion(region, animated: false)

        // locationManager.requestWhenInUseAuthorization()
        // locationManager.startUpdatingLocation()

        // view.showsUserLocation = true
        // locationManager.stopUpdatingLocation()
        view.isZoomEnabled = false
        view.isScrollEnabled = false
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
    }

    private func updateStage(from mapView: MKMapView) {
        let annotation = StageAnnotation(stage: stage)
        mapView.addAnnotations([annotation])
    }

    static func openInMaps(stage: Stage) {

        let center = CLLocationCoordinate2D(
            latitude: 50.719877,
            longitude: 11.338449
        )
        let latDistance = abs(center.latitude - stage.latitude)
        let longDistance = abs(center.longitude - stage.longitude)

        let latDelta = max(0.01, latDistance * 2)
        let longDelta = max(0.01, longDistance * 2)

        let coordinates = CLLocationCoordinate2DMake(
            stage.latitude,
            stage.longitude
        )
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
        mapItem.name = "\(stage.localizedName)"
        mapItem.openInMaps(launchOptions: options)
    }
}

final class StageAnnotation: NSObject, MKAnnotation {
    let id: String
    let title: String?
    let coordinate: CLLocationCoordinate2D

    init(stage: Stage) {
        self.id = String(stage.id)
        self.title = stage.localizedName
        self.coordinate = CLLocationCoordinate2D(
            latitude: stage.latitude,
            longitude: stage.longitude
        )
    }
}
