#if os(iOS)
import MapKit
import SwiftUI
import XCTest
@testable import Rudolstadt

@MainActor
final class ArtistMapKitWorldMapTests: XCTestCase {
    func testHitTestingAtProjectedCountryPositions() async throws {
        let geometry = try WorldCountryOverlayStore.buildLoadedMap(resourceNames: ["world_countries"])
        let samples: [(String, Double, Double)] = [
            ("FRA", 46.5, 2.5), ("DEU", 51, 10), ("SWE", 63, 15),
            ("NOR", 66, 14), ("BRA", -15, -47), ("IND", 22, 78),
            ("CAN", 56, -65), ("NER", 17, 8), ("IRN", 32, 54), ("UKR", 49, 32),
        ]
        let counts = Dictionary(uniqueKeysWithValues: samples.map { ($0.0, 1) })
        func content(globe: Bool = true, selected: String? = nil, trigger: Int = 0) -> ArtistMapKitWorldMap {
            ArtistMapKitWorldMap(
                artistCountsByCountryCode: counts, loadedMap: geometry,
                selectedCountryCode: selected, showsGlobe: globe, focusTrigger: trigger,
                onCountrySelected: { _ in }
            )
        }
        let host = UIHostingController(rootView: content())
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await waitUntil { (self.findMap(in: host.view)?.bounds.height ?? 0) > 120 }
        let map = try XCTUnwrap(findMap(in: host.view))
        let coordinator = try XCTUnwrap(map.delegate as? ArtistMapKitWorldMap.Coordinator)
        try await Task.sleep(for: .seconds(1))
        let projection = try XCTUnwrap(WorldGlobeProjection(map: map))
        for (code, latitude, longitude) in samples {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let projected = try XCTUnwrap(projection.screenPoint(for: coordinate))
            XCTAssertEqual(coordinator.countryCode(at: projected, in: map), code,
                "country at \(coordinate), screen=\(projected)")
        }

        host.rootView = content(selected: "IRN", trigger: 1)
        try await Task.sleep(for: .seconds(1))
        let afterIran = try XCTUnwrap(WorldGlobeProjection(map: map))
        let sweden = CLLocationCoordinate2D(latitude: 63, longitude: 15)
        let swedenPoint = try XCTUnwrap(afterIran.screenPoint(for: sweden))
        XCTAssertEqual(coordinator.countryCode(at: swedenPoint, in: map), "SWE")
        XCTAssertNil(coordinator.countryCode(at: CGPoint(x: 5, y: 5), in: map))
        let egyptPoint = try XCTUnwrap(afterIran.screenPoint(for: CLLocationCoordinate2D(latitude: 26, longitude: 30)))
        XCTAssertNil(coordinator.countryCode(at: egyptPoint, in: map), "Countries without artists stay unselectable")

        host.rootView = content(globe: false)
        try await Task.sleep(for: .seconds(1))
        var testedFlatPositions = 0
        for (code, latitude, longitude) in samples {
            let point = map.convert(CLLocationCoordinate2D(latitude: latitude, longitude: longitude), toPointTo: map)
            guard map.bounds.contains(point) else { continue }
            XCTAssertEqual(coordinator.countryCode(at: point, in: map), code)
            testedFlatPositions += 1
        }
        XCTAssertGreaterThan(testedFlatPositions, 0)
    }

    func testGlobeRayIntersection() throws {
        let projection = WorldGlobeProjection(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            distance: WorldGlobeProjection.earthRadius,
            centerPoint: CGPoint(x: 200, y: 400), focalLength: CGSize(width: 100, height: 100)
        )
        let equator = try XCTUnwrap(projection.coordinate(at: CGPoint(x: 244.09269852, y: 400)))
        XCTAssertEqual(equator.latitude, 0, accuracy: 0.000001)
        XCTAssertEqual(equator.longitude, 30, accuracy: 0.000001)
        let north = try XCTUnwrap(projection.coordinate(at: CGPoint(x: 200, y: 355.90730148)))
        XCTAssertEqual(north.latitude, 30, accuracy: 0.000001)
        XCTAssertEqual(north.longitude, 0, accuracy: 0.000001)
        XCTAssertNil(projection.coordinate(at: CGPoint(x: 260, y: 400)))
        XCTAssertNil(projection.screenPoint(for: CLLocationCoordinate2D(latitude: 0, longitude: 180)))
    }

    func testCountryFocusUsesMainLandmass() throws {
        let geometry = try WorldCountryOverlayStore.buildLoadedMap(resourceNames: ["world_countries"])
        for (code, latitudes, longitudes) in [
            ("SWE", 55.0...70.0, 11.0...24.0),
            ("USA", 25.0...50.0, -125.0 ... -66.0),
            ("FRA", 42.0...52.0, -5.0...9.0),
            ("FJI", -19.0 ... -17.0, 177.0...180.0),
        ] {
            let center = try XCTUnwrap(geometry.focusCoordinate(for: code))
            XCTAssertTrue(latitudes.contains(center.latitude), "\(code): \(center)")
            XCTAssertTrue(longitudes.contains(center.longitude), "\(code): \(center)")
        }
        XCTAssertNil(geometry.focusCoordinate(for: "UNKNOWN"))
    }

    func testCountrySelectionCentersAboveSheetInBothProjections() async throws {
        let geometry = try WorldCountryOverlayStore.buildLoadedMap(resourceNames: ["world_countries"])
        for (globe, initialDistance) in [(true, 8_000_000.0), (false, 8_000_000.0), (true, 44_000_000.0)] {
            let host = UIHostingController(rootView: worldMap(geometry, globe: globe, selected: nil))
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            try await waitUntil { (self.findMap(in: host.view)?.bounds.height ?? 0) > 120 }
            let map = try XCTUnwrap(findMap(in: host.view))
            map.setCamera(MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 40, longitude: 8),
                fromDistance: initialDistance, pitch: 0, heading: 0
            ), animated: false)
            try await Task.sleep(for: .milliseconds(250))
            let distance = map.camera.centerCoordinateDistance
            let originalMargins = map.layoutMargins
            // MapKit clamps a world-scale camera with small projection rounding differences.
            let distanceTolerance = initialDistance == 8_000_000 ? 10 : distance * 0.001
            func isFocused(on coordinate: CLLocationCoordinate2D) -> Bool {
                let point = map.convert(coordinate, toPointTo: map)
                let top = map.safeAreaInsets.top + 80
                let bottom = map.bounds.height / 2
                guard abs(point.x - map.bounds.midX) < 3 else { return false }
                if initialDistance == 8_000_000 {
                    return abs(point.y - (top + bottom) / 2) < 3
                }
                // At world scale, keep the country above the sheet within the globe's horizon.
                return point.y > top && point.y < bottom - 20
            }
            // No camera reset between selections: a fitting operation can accumulate zoom changes.
            for (index, code) in ["SWE", "FRA", "DEU", "SWE", "SWE"].enumerated() {
                let country = try XCTUnwrap(geometry.focusCoordinate(for: code))
                host.rootView = worldMap(geometry, globe: globe, selected: code, focusTrigger: index + 1)
                // Let SwiftUI consume even a repeat selection before checking the camera.
                try await Task.sleep(for: .milliseconds(100))
                try await waitUntil {
                    isFocused(on: country) && abs(map.camera.centerCoordinateDistance - distance) < distanceTolerance
                }
                XCTAssertEqual(map.camera.centerCoordinateDistance, distance, accuracy: distanceTolerance,
                    "globe=\(globe), initialDistance=\(initialDistance), selection=\(index): \(code)")
                XCTAssertEqual(map.layoutMargins, originalMargins)
                XCTAssertEqual(map.camera.heading, 0, accuracy: 0.01)
                XCTAssertEqual(map.camera.pitch, 0, accuracy: 0.01)
            }

            // An ordinary SwiftUI update must leave a manually panned map alone.
            map.setCamera(MKMapCamera(
                lookingAtCenter: CLLocationCoordinate2D(latitude: 40, longitude: -20),
                fromDistance: distance, pitch: 0, heading: 0
            ), animated: false)
            try await Task.sleep(for: .milliseconds(250))
            let pannedCenter = map.camera.centerCoordinate
            host.rootView = worldMap(geometry, globe: globe, selected: "SWE", focusTrigger: 5)
            try await Task.sleep(for: .milliseconds(250))
            XCTAssertEqual(map.camera.centerCoordinate.latitude, pannedCenter.latitude, accuracy: 0.01)
            XCTAssertEqual(map.camera.centerCoordinate.longitude, pannedCenter.longitude, accuracy: 0.01)
        }
    }

    func testMapColorsFollowAccentAndColorSchemeChanges() async throws {
        let geometry = try WorldCountryOverlayStore.buildLoadedMap(resourceNames: ["world_countries"])
        let host = UIHostingController(rootView: worldMap(
            geometry, globe: true, colorScheme: .light,
            accent: Color(red: 0.1, green: 0.7, blue: 0.2)
        ))
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let mostArtists = try XCTUnwrap(geometry.overlays.first {
            geometry.overlayMetadataByID[ObjectIdentifier($0)]?.code == "DEU"
        })
        let noArtists = try XCTUnwrap(geometry.overlays.first {
            geometry.overlayMetadataByID[ObjectIdentifier($0)]?.code == "EGY"
        })
        try await waitUntil {
            self.findMap(in: host.view)?.renderer(for: mostArtists) != nil
                && self.findMap(in: host.view)?.renderer(for: noArtists) != nil
        }
        let map = try XCTUnwrap(findMap(in: host.view))
        let selected = try XCTUnwrap(map.renderer(for: mostArtists) as? MKPolygonRenderer)
        let neutral = try XCTUnwrap(map.renderer(for: noArtists) as? MKPolygonRenderer)
        let background = try XCTUnwrap(map.overlays.first as? WorldMapBackgroundOverlay)
        let ocean = try XCTUnwrap(map.renderer(for: background) as? WorldMapBackgroundRenderer)

        try assertColor(selected.fillColor, red: 0.1, green: 0.7, blue: 0.2)
        try assertColor(selected.strokeColor, red: 0.06, green: 0.42, blue: 0.12)
        try assertColor(neutral.fillColor, red: 245.0 / 255, green: 246.0 / 255, blue: 248.0 / 255)
        try assertColor(ocean.fillColor, red: 214.0 / 255, green: 232.0 / 255, blue: 242.0 / 255)

        host.rootView = worldMap(
            geometry, globe: true, colorScheme: .dark,
            accent: Color(red: 0.8, green: 0.2, blue: 0.4)
        )
        try await waitUntil { selected.strokeColor == .white }
        XCTAssertTrue(findMap(in: host.view) === map)
        try assertColor(selected.fillColor, red: 0.8, green: 0.2, blue: 0.4)
        try assertColor(neutral.fillColor, red: 31.0 / 255, green: 40.0 / 255, blue: 51.0 / 255)
        try assertColor(ocean.fillColor, red: 16.0 / 255, green: 45.0 / 255, blue: 66.0 / 255)

        // Changing only the accent must update the existing renderer in the same appearance.
        let previousFill = selected.fillColor
        host.rootView = worldMap(
            geometry, globe: true, colorScheme: .dark,
            accent: Color(red: 0.1, green: 0.7, blue: 0.2)
        )
        try await waitUntil { selected.fillColor != previousFill }
        try assertColor(selected.fillColor, red: 0.1, green: 0.7, blue: 0.2)
        try assertColor(ocean.fillColor, red: 16.0 / 255, green: 45.0 / 255, blue: 66.0 / 255)
    }

    func testRepeatedUpdatesDoNotRedrawUnchangedCountries() {
        let (coordinator, map, renderers) = appearanceFixture()
        coordinator.updateAppearance(in: map)
        renderers.values.forEach { $0.redrawCount = 0 }

        // Sheet dismissal and navigation can update the map without changing its appearance.
        for _ in 0..<20 {
            coordinator.updateAppearance(in: map)
        }

        XCTAssertTrue(renderers.values.allSatisfy { $0.redrawCount == 0 })
    }

    func testSelectionAndCountChangesOnlyRedrawAffectedCountries() throws {
        let (coordinator, map, renderers) = appearanceFixture()
        coordinator.updateAppearance(in: map)
        renderers.values.forEach { $0.redrawCount = 0 }

        coordinator.parent = appearanceMap(coordinator.parent.loadedMap, selected: "SWE")
        coordinator.updateAppearance(in: map)
        let sweden = try XCTUnwrap(renderers["SWE"])
        XCTAssertGreaterThan(sweden.redrawCount, 0)
        XCTAssertEqual(sweden.lineWidth, 1.8)
        XCTAssertEqual(renderers["DEU"]?.redrawCount, 0)
        XCTAssertEqual(renderers["FRA"]?.redrawCount, 0)

        renderers.values.forEach { $0.redrawCount = 0 }
        coordinator.parent = appearanceMap(coordinator.parent.loadedMap, selected: "DEU")
        coordinator.updateAppearance(in: map)
        XCTAssertGreaterThan(sweden.redrawCount, 0)
        XCTAssertEqual(sweden.lineWidth, 0.65)
        XCTAssertGreaterThan(try XCTUnwrap(renderers["DEU"]).redrawCount, 0)
        XCTAssertEqual(renderers["FRA"]?.redrawCount, 0)

        renderers.values.forEach { $0.redrawCount = 0 }
        let originalFill = renderers["FRA"]?.fillColor
        coordinator.parent = appearanceMap(
            coordinator.parent.loadedMap, selected: "DEU",
            counts: ["DEU": 20, "SWE": 3, "FRA": 8]
        )
        coordinator.updateAppearance(in: map)
        XCTAssertNotEqual(renderers["FRA"]?.fillColor, originalFill)
        XCTAssertGreaterThan(try XCTUnwrap(renderers["FRA"]).redrawCount, 0)
        XCTAssertEqual(sweden.redrawCount, 0)
        XCTAssertEqual(renderers["DEU"]?.redrawCount, 0)
    }

    private func appearanceFixture() -> (
        ArtistMapKitWorldMap.Coordinator, RendererMap, [String: RecordingPolygonRenderer]
    ) {
        let map = RendererMap(frame: .zero)
        var polygons: [MKPolygon] = []
        var metadata: [ObjectIdentifier: CountryOverlayMetadata] = [:]
        var renderers: [String: RecordingPolygonRenderer] = [:]
        for (index, code) in ["DEU", "SWE", "FRA"].enumerated() {
            let longitude = Double(index) * 10
            let coordinates = [
                CLLocationCoordinate2D(latitude: 50, longitude: longitude),
                CLLocationCoordinate2D(latitude: 51, longitude: longitude),
                CLLocationCoordinate2D(latitude: 50, longitude: longitude + 1),
            ]
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            let renderer = RecordingPolygonRenderer(polygon: polygon)
            polygons.append(polygon)
            metadata[ObjectIdentifier(polygon)] = CountryOverlayMetadata(code: code)
            map.renderers[ObjectIdentifier(polygon)] = renderer
            renderers[code] = renderer
        }
        map.addOverlays(polygons, level: .aboveRoads)
        let geometry = LoadedWorldCountryMap(
            overlays: polygons, overlayMetadataByID: metadata, hitPathsByOverlayID: [:]
        )
        return (appearanceMap(geometry).makeCoordinator(), map, renderers)
    }

    private func appearanceMap(
        _ geometry: LoadedWorldCountryMap?, selected: String? = nil,
        counts: [String: Int] = ["DEU": 20, "SWE": 3, "FRA": 5]
    ) -> ArtistMapKitWorldMap {
        ArtistMapKitWorldMap(
            artistCountsByCountryCode: counts, loadedMap: geometry,
            selectedCountryCode: selected, showsGlobe: true, onCountrySelected: { _ in }
        )
    }

    func testLocalPolygonsInBothProjections() async throws {
        let geometry = try WorldCountryOverlayStore.buildLoadedMap(resourceNames: ["world_countries"])
        let host = UIHostingController(rootView: worldMap(geometry, globe: true))
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        }
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.layoutIfNeeded()
        try await waitUntil { self.findMap(in: host.view)?.overlays.count == geometry.overlays.count + 1 }
        let map = try XCTUnwrap(findMap(in: host.view))
        let background = try XCTUnwrap(map.overlays.first as? WorldMapBackgroundOverlay)
        XCTAssertTrue(background.canReplaceMapContent())
        XCTAssertFalse(map.overlays.contains { $0 is MKTileOverlay })
        XCTAssertFalse(map.isRotateEnabled)

        for (index, globe) in [true, false, true].enumerated() {
            host.rootView = worldMap(
                geometry, globe: globe, colorScheme: index == 2 ? .dark : .light
            )
            host.view.layoutIfNeeded()
            try await waitUntil { map.renderer(for: background) != nil }
            try await Task.sleep(for: .seconds(2))
            XCTAssertTrue(findMap(in: host.view) === map)
            XCTAssertEqual(map.overlays.count, geometry.overlays.count + 1)
            XCTAssertTrue(map.overlays(in: .aboveLabels).isEmpty)
            let renderer = try XCTUnwrap(map.renderer(for: background) as? WorldMapBackgroundRenderer)
            XCTAssertEqual(renderer.fillColor?.cgColor.alpha, 1)
            let country = try XCTUnwrap(geometry.overlays.first {
                geometry.overlayMetadataByID[ObjectIdentifier($0)]?.code == "DEU"
            })
            XCTAssertNotNil(map.renderer(for: country))

            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "mapkit-vectors-\(index)-\(globe ? "globe" : "flat")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func worldMap(
        _ geometry: LoadedWorldCountryMap, globe: Bool,
        colorScheme: ColorScheme = .light, accent: Color? = nil,
        selected: String? = "DEU", focusTrigger: Int = 0
    ) -> some View {
        ArtistMapKitWorldMap(
            artistCountsByCountryCode: ["DEU": 20, "FRA": 5, "USA": 3, "JPN": 2, "BRA": 1],
            loadedMap: geometry, selectedCountryCode: selected, showsGlobe: globe,
            focusTrigger: focusTrigger,
            onCountrySelected: { _ in }
        )
        .environment(\.colorScheme, colorScheme)
        .tint(accent ?? .rudolstadt)
        .environment(\.festivalAccentColor, accent ?? .rudolstadt)
    }

    private func assertColor(
        _ color: UIColor?, red: CGFloat, green: CGFloat, blue: CGFloat,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let color = try XCTUnwrap(color, file: file, line: line)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(color.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &alpha), file: file, line: line)
        XCTAssertEqual(actualRed, red, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualGreen, green, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualBlue, blue, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(alpha, 1, accuracy: 0.001, file: file, line: line)
    }

    private func findMap(in view: UIView) -> MKMapView? {
        if let map = view as? MKMapView { return map }
        return view.subviews.lazy.compactMap { self.findMap(in: $0) }.first
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition())
    }
}

@MainActor
private final class RendererMap: MKMapView {
    var renderers: [ObjectIdentifier: MKOverlayRenderer] = [:]

    override func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        renderers[ObjectIdentifier(overlay)]
    }
}

private final class RecordingPolygonRenderer: MKPolygonRenderer {
    var redrawCount = 0

    override func setNeedsDisplay() {
        redrawCount += 1
    }
}
#endif
