import MapKit
import SwiftUI

#if os(iOS)

struct FestivalMapCanvas: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let stages: [Stage]
    let performancePlaceIDs: Set<FestivalPlaceID>
    let selectedPlaceID: FestivalPlaceID?
    let focusTrigger: Int
    let showsUserLocation: Bool
    let isPlaceSheetPresented: Bool
    let onSelectPlace: (FestivalPlaceID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let view = FestivalMapUIKitView()
        view.delegate = context.coordinator
        view.isRotateEnabled = false
        view.isPitchEnabled = false
        view.accessibilityIdentifier = "festival-map"
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        configuration.pointOfInterestFilter = MKPointOfInterestFilter.excludingAll
        view.preferredConfiguration = configuration
        view.tintColor = .tintColor
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
            coordinator.pendingFocus = selectedPlaceID.map { [$0] } ?? []
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
        var pendingFocus: [FestivalPlaceID]?
        private var lastStages: [Stage] = []
        private var lastColorScheme: ColorScheme?
        private var hasFocusedOverview = false

        init(_ parent: FestivalMapCanvas) { self.parent = parent }

        func updateAnnotations(in view: MKMapView) {
            if lastStages != parent.stages || lastColorScheme != parent.colorScheme {
                lastStages = parent.stages
                lastColorScheme = parent.colorScheme
                view.removeAnnotations(view.annotations.compactMap { $0 as? FestivalMapAnnotation })
                view.addAnnotations(parent.stages.map { FestivalMapAnnotation(stage: $0) })
            }
            // Keep the selected pin in sync with navigation inside the place sheet.
            for annotation in view.selectedAnnotations {
                if let place = annotation as? FestivalMapAnnotation,
                    place.stage.id != parent.selectedPlaceID {
                    view.deselectAnnotation(place, animated: false)
                }
            }
            if let selected = view.annotations.compactMap({ $0 as? FestivalMapAnnotation })
                .first(where: { $0.stage.id == parent.selectedPlaceID }),
                !view.selectedAnnotations.contains(where: { $0 === selected }) {
                view.selectAnnotation(selected, animated: false)
            }
        }

        func performPendingFocus(in view: MKMapView) {
            guard let ids = pendingFocus, view.bounds.width > 0, view.bounds.height > 120 else { return }
            pendingFocus = nil
            if !hasFocusedOverview {
                focus(on: parent.stages, in: view, animated: false)
                hasFocusedOverview = true
            }
            let targets = ids.isEmpty ? parent.stages
                : parent.stages.filter { ids.contains($0.id) }
            focus(on: targets, in: view, animated: lastFocusTrigger != 0)
        }

        private func focus(on stages: [Stage], in view: MKMapView, animated: Bool) {
            guard !stages.isEmpty else {
                return
            }
            if parent.isPlaceSheetPresented, stages.count == 1, let stage = stages.first {
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
            let usesReferenceBadge = parent.performancePlaceIDs.contains(place.stage.id) || place.stage.admissionCategory != nil
            marker.displayPriority = .required
            marker.canShowCallout = false
            marker.titleVisibility = .adaptive
            if usesReferenceBadge {
                marker.glyphImage = nil
                marker.selectedGlyphImage = nil
                marker.glyphText = stage.displayCode
            } else {
                marker.glyphText = nil
                let symbol = stage.mapCategory?.systemImageName ?? "mappin"
                // MapKit scales its normal and selected glyph slots differently.
                marker.glyphImage = glyphImage(systemName: symbol, canvasSize: 20, circleDiameter: 36,
                                              displayScale: mapView.traitCollection.displayScale)
                marker.selectedGlyphImage = glyphImage(systemName: symbol, canvasSize: 40, circleDiameter: 68,
                                                      displayScale: mapView.traitCollection.displayScale)
            }
            let scheme: ColorScheme = mapView.traitCollection.userInterfaceStyle == .dark ? .dark : .light
            marker.markerTintColor = UIColor(StageNumber.baseColor(for: stage, colorScheme: scheme))
            marker.accessibilityLabel = [stage.displayCode, stage.localizedName]
                .compactMap { $0 }.joined(separator: " · ")
            marker.accessibilityIdentifier = "festival-place-\(stage.id)"
            marker.isAccessibilityElement = true
            marker.accessibilityTraits = .button
            return marker
        }

        @MainActor
        private func glyphImage(systemName: String, canvasSize: CGFloat, circleDiameter: CGFloat,
                                displayScale: CGFloat) -> UIImage? {
            // Keep MapKit's glyph canvas while sharing the badge's symbol layout.
            let renderer = ImageRenderer(content:
                PlaceSymbol(systemName: systemName, circleDiameter: circleDiameter)
                    .foregroundStyle(.white)
                    .frame(width: canvasSize, height: canvasSize)
            )
            renderer.scale = displayScale
            return renderer.uiImage?.withRenderingMode(.alwaysTemplate)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let place = view.annotation as? FestivalMapAnnotation,
                parent.selectedPlaceID != place.stage.id else { return }
            DispatchQueue.main.async { [weak self] in
                self?.parent.onSelectPlace(place.stage.id)
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
#endif

struct MapStageSheet: View {
    let stage: Stage
    var highlightedEventId: Int? = nil
    @Binding var selectedDay: String
    let navigate: (AppNavigationRoute) -> Void

    var body: some View {
        NavigationStack {
            StageDetailView(
                stage: stage,
                highlightedEventId: highlightedEventId,
                showsMap: false,
                navigate: navigate,
                programDaySelection: $selectedDay
            )
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var didConfigureManager = false
    private var isUpdatingLocation = false
    private var isTrackingRequested = false

    override init() {
        super.init()
    }

    func startLocationTracking() {
        isTrackingRequested = true
        if !didConfigureManager {
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyBest
            didConfigureManager = true
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isUpdatingLocation else {
                return
            }
            isUpdatingLocation = true
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            return
        @unknown default:
            return
        }
    }

    func stopLocationTracking() {
        isTrackingRequested = false
        manager.stopUpdatingLocation()
        isUpdatingLocation = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isTrackingRequested { startLocationTracking() }
    }
}
