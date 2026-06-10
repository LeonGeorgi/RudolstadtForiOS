import Foundation
import MapKit
import SwiftUI

struct StageMapView: UIViewRepresentable {
    let stage: Stage
    let isInteractive: Bool
    let recenterTrigger: Int

    init(stage: Stage, isInteractive: Bool = false, recenterTrigger: Int = 0) {
        self.stage = stage
        self.isInteractive = isInteractive
        self.recenterTrigger = recenterTrigger
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let view = MKMapView()
        updateStage(from: view)

        view.setRegion(initialRegion, animated: false)
        view.isZoomEnabled = isInteractive
        view.isScrollEnabled = isInteractive
        view.isRotateEnabled = isInteractive
        view.isPitchEnabled = isInteractive
        view.isUserInteractionEnabled = isInteractive

        view.pointOfInterestFilter = .excludingAll

        if isInteractive {
            view.showsCompass = true
            view.showsScale = true
            view.showsUserLocation = true

            context.coordinator.locationManager.requestWhenInUseAuthorization()
        }

        return view
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        guard isInteractive else {
            return
        }

        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            uiView.setUserTrackingMode(.follow, animated: true)
        }
    }

    private var initialRegion: MKCoordinateRegion {
        let center = CLLocationCoordinate2D(
            latitude: stage.latitude,
            longitude: stage.longitude
        )

        if isInteractive {
            return MKCoordinateRegion(
                center: center,
                latitudinalMeters: 700,
                longitudinalMeters: 700
            )
        }

        // Keep local context while clearly pinpointing the selected stage.
        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: 900,
            longitudinalMeters: 900
        )
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

extension StageMapView {
    final class Coordinator {
        let locationManager = CLLocationManager()
        var lastRecenterTrigger: Int = 0
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

#if DEBUG
@MainActor
private struct StageMapViewPreviewShowcase: View {
    private var stages: [Stage] {
        Array(PreviewMockData.festivalData.stages.prefix(2))
    }

    var body: some View {
        VStack(spacing: 16) {
            ForEach(stages) { stage in
                VStack(alignment: .leading, spacing: 6) {
                    Text(stage.localizedName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    StageMapView(stage: stage)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if let interactiveStage = stages.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Interactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    StageMapView(stage: interactiveStage, isInteractive: true)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding()
    }
}

struct StageMapView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        StageMapViewPreviewShowcase()
            .previewMockEnvironment(suiteName: "StageMapViewPreview")
            .previewLayout(.sizeThatFits)
    }
}
#endif
