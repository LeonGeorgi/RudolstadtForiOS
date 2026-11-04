#if os(iOS)
import MapKit
import SwiftUI
import simd

/// Draws local country geometry on MapKit’s flat map and globe.
struct ArtistMapKitWorldMap: UIViewRepresentable {
    let artistCountsByCountryCode: [String: Int]
    let loadedMap: LoadedWorldCountryMap?
    let selectedCountryCode: String?
    let showsGlobe: Bool
    var focusTrigger = 0
    let onCountrySelected: (String) -> Void

    @Environment(\.self) private var environment

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.showsCompass = false
        map.showsScale = true
        map.showsUserLocation = false
        map.isAccessibilityElement = true
        map.accessibilityLabel = NSLocalizedString("artists.view.world_map", comment: "")
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 2_500_000)
        context.coordinator.configureProjection(in: map)
        map.camera = MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: 18, longitude: 8),
            fromDistance: 44_000_000, pitch: 0, heading: 0
        )
        // An opaque overlay replaces the Apple imagery, without raster tiles.
        map.addOverlay(context.coordinator.background, level: .aboveRoads)
        context.coordinator.updateCountries(in: map)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.selectCountry(_:)))
        for recognizer in map.gestureRecognizers ?? [] {
            if let doubleTap = recognizer as? UITapGestureRecognizer, doubleTap.numberOfTapsRequired == 2 {
                tap.require(toFail: doubleTap)
            }
        }
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configureProjection(in: map)
        context.coordinator.updateCountries(in: map)
        context.coordinator.updateAppearance(in: map)
        context.coordinator.updateSelectionFocus()
        updateAccessibility(in: map)
        // As on the festival map, wait until SwiftUI has applied the map's layout.
        DispatchQueue.main.async { [weak map, weak coordinator = context.coordinator] in
            guard let map, let coordinator else { return }
            coordinator.performPendingFocus(in: map)
        }
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        map.delegate = nil
    }

    private var oceanColor: UIColor {
        // "Mehr Kontrast / Eisblau" from the world-map color study.
        environment.colorScheme == .dark
            ? UIColor(red: 16.0 / 255, green: 45.0 / 255, blue: 66.0 / 255, alpha: 1)
            : UIColor(red: 214.0 / 255, green: 232.0 / 255, blue: 242.0 / 255, alpha: 1)
    }

    private var borderColor: UIColor {
        environment.colorScheme == .dark
            ? UIColor(red: 78.0 / 255, green: 96.0 / 255, blue: 113.0 / 255, alpha: 1)
            : UIColor(red: 156.0 / 255, green: 168.0 / 255, blue: 182.0 / 255, alpha: 1)
    }

    private var accentColor: Color.Resolved {
        environment.festivalAccentColor.resolve(in: environment)
    }

    private func selectionColor(accent: Color.Resolved) -> UIColor {
        guard environment.colorScheme != .dark else { return .white }
        return UIColor(
            red: CGFloat(accent.red) * 0.6,
            green: CGFloat(accent.green) * 0.6,
            blue: CGFloat(accent.blue) * 0.6, alpha: 1
        )
    }

    private func fillColor(for count: Int, accent: Color.Resolved) -> UIColor {
        let land = environment.colorScheme == .dark ? (31.0, 40.0, 51.0) : (245.0, 246.0, 248.0)
        let red = land.0 / 255
        let green = land.1 / 255
        let blue = land.2 / 255
        let relativeCount = log(Double(count) + 1)
            / log(Double(max(artistCountsByCountryCode.values.max() ?? 1, 1)) + 1)
        // Keep countries with few artists legible without changing the accent endpoint.
        let strength = pow(relativeCount, 0.55)
        return UIColor(
            red: red + strength * (Double(accent.red) - red),
            green: green + strength * (Double(accent.green) - green),
            blue: blue + strength * (Double(accent.blue) - blue), alpha: 1
        )
    }

    private func updateAccessibility(in map: MKMapView) {
        let codes = artistCountsByCountryCode.keys.sorted {
            localizedCountryName(forRegionCode: $0).localizedCaseInsensitiveCompare(
                localizedCountryName(forRegionCode: $1)
            ) == .orderedAscending
        }
        map.accessibilityCustomActions = codes.map { code in
            let count = artistCountsByCountryCode[code] ?? 0
            let key = count == 1 ? "artists.map.accessibility.artist_count.one" : "artists.map.accessibility.artist_count.other"
            let label = String(format: NSLocalizedString(key, comment: ""), locale: Locale.current, count)
            return UIAccessibilityCustomAction(name: "\(localizedCountryName(forRegionCode: code)), \(label)") { _ in
                onCountrySelected(code)
                return true
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ArtistMapKitWorldMap
        let background = WorldMapBackgroundOverlay()
        private var appliedGlobe: Bool?
        private var appliedGeometry: ObjectIdentifier?
        private var lastSelectedCountryCode: String?
        private var lastFocusTrigger: Int?
        private var pendingFocus: String?

        init(parent: ArtistMapKitWorldMap) { self.parent = parent }

        func updateSelectionFocus() {
            if lastSelectedCountryCode != parent.selectedCountryCode
                || lastFocusTrigger != parent.focusTrigger {
                lastSelectedCountryCode = parent.selectedCountryCode
                lastFocusTrigger = parent.focusTrigger
                pendingFocus = parent.selectedCountryCode
            }
        }

        func performPendingFocus(in map: MKMapView) {
            guard let country = pendingFocus,
                map.bounds.width > 0, map.bounds.height > 120,
                let coordinate = parent.loadedMap?.focusCoordinate(for: country)
            else { return }
            let visibleTop = map.safeAreaInsets.top + 80
            let visibleBottom = map.bounds.height / 2
            guard visibleBottom > visibleTop else { return }
            pendingFocus = nil
            let camera = focusedCamera(
                on: coordinate, at: (visibleTop + visibleBottom) / 2, in: map
            )
            map.setCamera(camera, animated: !parent.environment.accessibilityReduceMotion)
        }

        private func focusedCamera(
            on coordinate: CLLocationCoordinate2D, at targetY: CGFloat, in map: MKMapView
        ) -> MKMapCamera {
            let original = map.camera
            let camera = MKMapCamera(
                lookingAtCenter: coordinate,
                fromDistance: original.centerCoordinateDistance, pitch: 0, heading: 0
            )
            // Resolve the screen offset with MapKit's current projection at a fixed
            // camera distance. Restore the starting camera before the single animation;
            // these synchronous probes do not commit an intermediate display frame.
            defer { map.setCamera(original, animated: false) }
            for _ in 0..<5 {
                map.setCamera(camera, animated: false)
                let point = map.convert(coordinate, toPointTo: map)
                let error = point.y - targetY
                if abs(error) < 0.5 { break }
                let north = map.convert(CLLocationCoordinate2D(
                    latitude: min(coordinate.latitude + 0.25, 85), longitude: coordinate.longitude
                ), toPointTo: map)
                let south = map.convert(CLLocationCoordinate2D(
                    latitude: max(coordinate.latitude - 0.25, -85), longitude: coordinate.longitude
                ), toPointTo: map)
                let pixelsPerDegree = (north.y - south.y) / 0.5
                guard pixelsPerDegree.isFinite, abs(pixelsPerDegree) > 0.01 else { break }
                let step = max(-15, min(15, error / pixelsPerDegree))
                // At globe scale the desired screen point can lie beyond the horizon.
                // Keep the country on the visible hemisphere rather than zooming out.
                let latitude = max(
                    max(-85, coordinate.latitude - 60),
                    min(85, camera.centerCoordinate.latitude + step)
                )
                if abs(latitude - camera.centerCoordinate.latitude) < 0.001 { break }
                camera.centerCoordinate = CLLocationCoordinate2D(
                    latitude: latitude, longitude: coordinate.longitude
                )
            }
            return camera
        }

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            performPendingFocus(in: mapView)
        }

        func configureProjection(in map: MKMapView) {
            guard appliedGlobe != parent.showsGlobe else { return }
            appliedGlobe = parent.showsGlobe
            // Imagery supplies the native globe camera without Apple's map labels above our vectors.
            let configuration = MKImageryMapConfiguration(elevationStyle: parent.showsGlobe ? .realistic : .flat)
            map.preferredConfiguration = configuration
        }

        func updateCountries(in map: MKMapView) {
            guard let loadedMap = parent.loadedMap else { return }
            let geometry = loadedMap.overlays.first.map(ObjectIdentifier.init)
            guard geometry != appliedGeometry else { return }
            map.removeOverlays(map.overlays.filter { $0 is MKPolygon })
            // Above-label overlays can force MapKit back to a flat projection.
            map.addOverlays(loadedMap.overlays, level: .aboveRoads)
            appliedGeometry = geometry
        }

        func updateAppearance(in map: MKMapView) {
            if map.backgroundColor != parent.oceanColor {
                map.backgroundColor = parent.oceanColor
            }
            let accent = parent.accentColor
            for overlay in map.overlays {
                guard let renderer = map.renderer(for: overlay) else { continue }
                // MapKit rasterizes globe overlays into textures. Unchanged SwiftUI updates
                // must not invalidate every country, especially during navigation transitions.
                if configure(renderer, for: overlay, accent: accent) {
                    renderer.setNeedsDisplay()
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer: MKOverlayRenderer
            if let polygon = overlay as? MKPolygon {
                renderer = MKPolygonRenderer(polygon: polygon)
            } else {
                renderer = WorldMapBackgroundRenderer(overlay: overlay)
            }
            configure(renderer, for: overlay, accent: parent.accentColor)
            return renderer
        }

        @discardableResult
        private func configure(
            _ renderer: MKOverlayRenderer, for overlay: MKOverlay, accent: Color.Resolved
        ) -> Bool {
            if let background = renderer as? WorldMapBackgroundRenderer {
                guard background.fillColor != parent.oceanColor else { return false }
                background.fillColor = parent.oceanColor
                return true
            }
            if let polygon = overlay as? MKPolygon, let renderer = renderer as? MKPolygonRenderer {
                let code = parent.loadedMap?.overlayMetadataByID[ObjectIdentifier(polygon)]?.code
                let count = code.flatMap { parent.artistCountsByCountryCode[$0] } ?? 0
                let selected = code != nil && code == parent.selectedCountryCode
                let fillColor = parent.fillColor(for: count, accent: accent)
                let strokeColor = selected ? parent.selectionColor(accent: accent) : parent.borderColor
                let lineWidth = selected ? 1.8 : 0.65
                guard renderer.fillColor != fillColor
                    || renderer.strokeColor != strokeColor
                    || renderer.lineWidth != lineWidth
                else { return false }
                renderer.fillColor = fillColor
                renderer.strokeColor = strokeColor
                renderer.lineWidth = lineWidth
                return true
            }
            return false
        }

        @objc func selectCountry(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView,
                let code = countryCode(at: gesture.location(in: map), in: map)
            else { return }
            parent.onCountrySelected(code)
        }

        func countryCode(at screenPoint: CGPoint, in map: MKMapView) -> String? {
            guard let loadedMap = parent.loadedMap, map.bounds.contains(screenPoint) else { return nil }
            let coordinate: CLLocationCoordinate2D
            if parent.showsGlobe {
                guard let hit = WorldGlobeProjection(map: map)?.coordinate(at: screenPoint) else { return nil }
                coordinate = hit
            } else {
                coordinate = map.convert(screenPoint, toCoordinateFrom: map)
            }
            guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            let point = MKMapPoint(coordinate)
            for polygon in loadedMap.overlays.reversed() {
                let id = ObjectIdentifier(polygon)
                guard
                    let code = loadedMap.overlayMetadataByID[id]?.code,
                    parent.artistCountsByCountryCode[code] != nil,
                    let path = loadedMap.hitPathsByOverlayID[id],
                    path.contains(CGPoint(x: point.x, y: point.y), using: .evenOdd)
                else { continue }
                return code
            }
            return nil
        }
    }
}

/// MapKit's UIKit point conversion remains Mercator-based while the imagery is a globe.
/// Calibrate the camera's focal length locally, then intersect screen rays with the sphere.
struct WorldGlobeProjection {
    static let earthRadius = 6_378_137.0
    private let center: SIMD3<Double>
    private let east: SIMD3<Double>
    private let north: SIMD3<Double>
    private let eyeDistance: Double
    private let centerPoint: CGPoint
    private let focalLength: CGSize

    init(center coordinate: CLLocationCoordinate2D, distance: Double,
         centerPoint: CGPoint, focalLength: CGSize) {
        let latitude = coordinate.latitude * .pi / 180
        let longitude = coordinate.longitude * .pi / 180
        center = Self.position(coordinate)
        east = SIMD3(-sin(longitude), cos(longitude), 0)
        north = SIMD3(-sin(latitude) * cos(longitude), -sin(latitude) * sin(longitude), cos(latitude))
        eyeDistance = 1 + distance / Self.earthRadius
        self.centerPoint = centerPoint
        self.focalLength = focalLength
    }

    @MainActor
    init?(map: MKMapView) {
        let camera = map.camera
        let coordinate = camera.centerCoordinate
        let step = 0.01
        let longitudeStep = coordinate.longitude > 179 ? -step : step
        let latitudeStep = coordinate.latitude > 84 ? -step : step
        let origin = map.convert(coordinate, toPointTo: map)
        let eastPoint = map.convert(CLLocationCoordinate2D(
            latitude: coordinate.latitude, longitude: coordinate.longitude + longitudeStep
        ), toPointTo: map)
        let northPoint = map.convert(CLLocationCoordinate2D(
            latitude: coordinate.latitude + latitudeStep, longitude: coordinate.longitude
        ), toPointTo: map)
        let distance = camera.centerCoordinateDistance
        let cosine = cos(coordinate.latitude * .pi / 180)
        let fx = abs((eastPoint.x - origin.x) / (longitudeStep * .pi / 180 * cosine))
            * distance / Self.earthRadius
        let fy = abs((northPoint.y - origin.y) / (latitudeStep * .pi / 180))
            * distance / Self.earthRadius
        guard distance > 0, fx.isFinite, fy.isFinite, fx > 0, fy > 0 else { return nil }
        self.init(center: coordinate, distance: distance, centerPoint: origin,
                  focalLength: CGSize(width: fx, height: fy))
    }

    func coordinate(at point: CGPoint) -> CLLocationCoordinate2D? {
        let x = (point.x - centerPoint.x) / focalLength.width
        let y = (centerPoint.y - point.y) / focalLength.height
        let ray = -center + x * east + y * north
        let eye = eyeDistance * center
        let a = simd_dot(ray, ray)
        let b = simd_dot(eye, ray)
        let discriminant = b * b - a * (eyeDistance * eyeDistance - 1)
        guard discriminant.isFinite, discriminant >= 0 else { return nil }
        let distance = (-b - sqrt(discriminant)) / a
        guard distance >= 0 else { return nil }
        let hit = simd_normalize(eye + distance * ray)
        return CLLocationCoordinate2D(
            latitude: asin(max(-1, min(1, hit.z))) * 180 / .pi,
            longitude: atan2(hit.y, hit.x) * 180 / .pi
        )
    }

    func screenPoint(for coordinate: CLLocationCoordinate2D) -> CGPoint? {
        let position = Self.position(coordinate)
        let eye = eyeDistance * center
        guard simd_dot(position, eye - position) > 0 else { return nil }
        let depth = eyeDistance - simd_dot(position, center)
        return CGPoint(
            x: centerPoint.x + focalLength.width * simd_dot(position, east) / depth,
            y: centerPoint.y - focalLength.height * simd_dot(position, north) / depth
        )
    }

    private static func position(_ coordinate: CLLocationCoordinate2D) -> SIMD3<Double> {
        let latitude = coordinate.latitude * .pi / 180
        let longitude = coordinate.longitude * .pi / 180
        return SIMD3(cos(latitude) * cos(longitude), cos(latitude) * sin(longitude), sin(latitude))
    }
}

final class WorldMapBackgroundOverlay: NSObject, MKOverlay {
    let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    // The normal Mercator world ends near 85 degrees. Extend the background toward both poles.
    let boundingMapRect = MKMapRect(
        x: 0, y: -MKMapRect.world.height,
        width: MKMapRect.world.width, height: MKMapRect.world.height * 3
    )

    func canReplaceMapContent() -> Bool { true }
}

final class WorldMapBackgroundRenderer: MKOverlayPathRenderer {
    override func createPath() {
        path = CGPath(rect: rect(for: overlay.boundingMapRect), transform: nil)
    }
}
#endif
