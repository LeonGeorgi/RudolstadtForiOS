import MapKit
import SwiftUI

struct FestivalMapCanvas: UIViewRepresentable {
    let stages: [Stage]
    let overviewStages: [Stage]
    let selectedStageID: Int?
    let focusStageIDs: [Int]
    let focusTrigger: Int
    let showsUserLocation: Bool
    let isStageSheetPresented: Bool
    let onSelectStage: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let view = FestivalMapUIKitView()
        view.delegate = context.coordinator
        view.isRotateEnabled = false
        view.isPitchEnabled = false
        view.accessibilityIdentifier = "festival-map"
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        configuration.emphasisStyle = .muted
        configuration.pointOfInterestFilter = MKPointOfInterestFilter(including: [.atm])
        view.preferredConfiguration = configuration
        view.tintColor = UIColor(Color.rudolstadt)
        view.didLayout = { [weak view, weak coordinator = context.coordinator] in
            guard let view, let coordinator else { return }
            coordinator.performPendingFocus(in: view)
        }
        return view
    }

    func updateUIView(_ view: MKMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        view.showsUserLocation = showsUserLocation
        coordinator.updateAnnotations(in: view)
        if coordinator.lastFocusTrigger != focusTrigger {
            coordinator.lastFocusTrigger = focusTrigger
            coordinator.pendingFocus = focusStageIDs
        }
        // Apply camera changes after SwiftUI has finished updating the map layout.
        DispatchQueue.main.async { [weak view, weak coordinator] in
            guard let view, let coordinator else { return }
            coordinator.performPendingFocus(in: view)
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FestivalMapCanvas
        var lastFocusTrigger: Int?
        var pendingFocus: [Int]?
        private var lastStages: [Stage] = []

        init(_ parent: FestivalMapCanvas) { self.parent = parent }

        func updateAnnotations(in view: MKMapView) {
            if lastStages != parent.stages {
                lastStages = parent.stages
                view.removeAnnotations(view.annotations.compactMap { $0 as? FestivalMapAnnotation })
                view.addAnnotations(parent.stages.map { FestivalMapAnnotation(stage: $0) })
            }
            // Keep MapKit's selection in sync with the number picker without rebuilding pins.
            for annotation in view.selectedAnnotations {
                if let place = annotation as? FestivalMapAnnotation,
                    place.stage.id != parent.selectedStageID {
                    view.deselectAnnotation(place, animated: false)
                }
            }
            if let selected = view.annotations.compactMap({ $0 as? FestivalMapAnnotation })
                .first(where: { $0.stage.id == parent.selectedStageID }),
                !view.selectedAnnotations.contains(where: { $0 === selected }) {
                view.selectAnnotation(selected, animated: false)
            }
        }

        func performPendingFocus(in view: MKMapView) {
            guard let ids = pendingFocus, view.bounds.width > 0, view.bounds.height > 120 else { return }
            pendingFocus = nil
            let targets = ids.isEmpty ? parent.overviewStages
                : parent.overviewStages.filter { ids.contains($0.id) }
            focus(on: targets, in: view, animated: lastFocusTrigger != 0)
        }

        private func focus(on stages: [Stage], in view: MKMapView, animated: Bool) {
            guard !stages.isEmpty else {
                view.setRegion(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 50.719877, longitude: 11.338449),
                    latitudinalMeters: 1_500, longitudinalMeters: 1_500
                ), animated: animated)
                return
            }
            if parent.isStageSheetPresented, stages.count == 1, let stage = stages.first {
                let point = MKMapPoint(CLLocationCoordinate2D(
                    latitude: stage.latitude, longitude: stage.longitude
                ))
                let visibleTop = view.safeAreaInsets.top + 80
                let visibleBottom = view.bounds.height / 2
                let targetY = (visibleTop + visibleBottom) / 2
                let mapPointsPerPoint = view.visibleMapRect.height / view.bounds.height
                let center = MKMapPoint(
                    x: point.x,
                    y: point.y + (view.bounds.midY - targetY) * mapPointsPerPoint
                )
                // Pan within the current map scale; selecting a pin must never change the zoom.
                view.setCenter(center.coordinate, animated: animated)
                return
            }
            var rect = MKMapRect.null
            for stage in stages {
                let point = MKMapPoint(CLLocationCoordinate2D(latitude: stage.latitude, longitude: stage.longitude))
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
            }
            let minimum = MKMapPointsPerMeterAtLatitude(stages[0].latitude) * 350
            rect = MKMapRect(x: rect.midX - max(rect.width, minimum) / 2,
                             y: rect.midY - max(rect.height, minimum) / 2,
                             width: max(rect.width, minimum), height: max(rect.height, minimum))
            view.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(
                top: view.safeAreaInsets.top + 80, left: 32,
                bottom: view.safeAreaInsets.bottom + 36, right: 32
            ), animated: animated)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let place = annotation as? FestivalMapAnnotation else { return nil }
            let marker = mapView.dequeueReusableAnnotationView(withIdentifier: "festival-place")
                as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "festival-place")
            let stage = place.stage
            marker.annotation = annotation
            marker.clusteringIdentifier = nil
            marker.displayPriority = .required
            marker.canShowCallout = false
            marker.titleVisibility = .adaptive
            marker.glyphImage = nil
            marker.glyphText = stage.stageNumber.map(String.init)
            marker.markerTintColor = UIColor(StageNumber.baseColor(for: stage.stageType))
            marker.accessibilityLabel = [stage.stageNumber.map(String.init), stage.localizedName]
                .compactMap { $0 }.joined(separator: " · ")
            marker.accessibilityIdentifier = "festival-stage-\(stage.id)"
            marker.isAccessibilityElement = true
            marker.accessibilityTraits = .button
            return marker
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let place = view.annotation as? FestivalMapAnnotation,
                parent.selectedStageID != place.stage.id else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.onSelectStage(place.stage.id)
            }
        }
    }
}

private final class FestivalMapUIKitView: MKMapView {
    var didLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        didLayout?()
    }
}

private final class FestivalMapAnnotation: NSObject, MKAnnotation {
    let stage: Stage
    let coordinate: CLLocationCoordinate2D
    var title: String? { stage.localizedName }

    init(stage: Stage) {
        self.stage = stage
        coordinate = CLLocationCoordinate2D(latitude: stage.latitude, longitude: stage.longitude)
    }
}
