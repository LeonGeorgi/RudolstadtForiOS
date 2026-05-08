import MapKit
import SwiftUI

#if os(iOS)
typealias PlatformColor = UIColor
#elseif os(macOS)
typealias PlatformColor = NSColor
#endif

private let worldMapMinimumZoomDistance: CLLocationDistance = 2_500_000
private let worldMapMaximumZoomDistance: CLLocationDistance = 80_000_000

enum ArtistPresentationMode: Int, CaseIterable {
    case list = 0
    case grid = 1

    var systemImageName: String {
        switch self {
        case .list:
            return "list.bullet"
        case .grid:
            return "square.grid.3x3"
        }
    }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .list:
            return "list.title"
        case .grid:
            return "grid.title"
        }
    }
}

struct ArtistCountryGroup: Identifiable {
    let code: String
    let artists: [Artist]

    var id: String {
        code
    }

    var localizedName: String {
        localizedCountryName(forRegionCode: code)
    }

    var englishName: String {
        englishCountryName(forRegionCode: code)
    }

    var count: Int {
        artists.count
    }
}

struct ArtistWorldMapView: View {
    private static let useSwiftUIMapExperiment = true

    let groups: [ArtistCountryGroup]
    @Binding var selectedCountryCode: String?
    let navigate: (AppNavigationRoute) -> Void
    @StateObject private var overlayLoader = GeoJSONCountryOverlayLoader.worldMapShared

    static func preloadResources() {
        let preloadStart = Date()
        debugWorldMapLog("preloadResources start")
        let overlayLoader = GeoJSONCountryOverlayLoader.worldMapShared
        overlayLoader.loadIfNeeded()
        guard !useSwiftUIMapExperiment else {
            debugWorldMapLog(
                "preloadResources finished for SwiftUI path in \(debugWorldMapDurationSince(preloadStart))"
            )
            return
        }
        Task { @MainActor in
            guard let loadedMap = await overlayLoader.ensureLoadedMap() else {
                debugWorldMapLog(
                    "preloadResources failed after \(debugWorldMapDurationSince(preloadStart))"
                )
                return
            }
            WorldMapViewStore.shared.prepareMapViewIfNeeded(with: loadedMap)
            debugWorldMapLog(
                "preloadResources prepared MKMapView in \(debugWorldMapDurationSince(preloadStart))"
            )
        }
    }

    var body: some View {
        Group {
            if groups.isEmpty {
                VStack {
                    Spacer()
                    Text("artists.map.empty")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                    Spacer()
                }
            } else {
                ZStack {
                    Group {
                        if Self.useSwiftUIMapExperiment {
                            ArtistWorldMapSwiftUIMap(
                                groups: groups,
                                loadedMap: overlayLoader.loadedMap,
                                selectedCountryCode: selectedCountryCode
                            ) { countryCode in
                                selectedCountryCode = countryCode
                            }
                        } else {
                            ArtistWorldMapRepresentable(
                                groups: groups,
                                loadedMap: overlayLoader.loadedMap,
                                selectedCountryCode: selectedCountryCode
                            ) { countryCode in
                                selectedCountryCode = countryCode
                            }
                        }
                    }
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if overlayLoader.isLoading {
                        loadingOverlay
                    } else if overlayLoader.hasFailed {
                        loadingFailureOverlay
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            debugWorldMapLog("ArtistWorldMapView.task loadIfNeeded")
            overlayLoader.loadIfNeeded()
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.regular)
            Text("artists.map.loading")
                .font(.subheadline.weight(.semibold))
            Text("artists.map.loading.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var loadingFailureOverlay: some View {
        Text("artists.map.loading.failed")
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private func debugWorldMapLog(_ message: String) {
    print("[ArtistWorldMap] \(message)")
}

private func debugWorldMapDurationSince(_ startDate: Date) -> String {
    String(format: "%.3fs", Date().timeIntervalSince(startDate))
}

private struct ArtistWorldMapSwiftUIMap: View {
    let groups: [ArtistCountryGroup]
    let loadedMap: LoadedWorldCountryMap?
    let selectedCountryCode: String?
    let onCountrySelected: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var mapScope
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: 18,
                longitude: 8
            ),
            distance: 44_000_000,
            heading: 0,
            pitch: 48
        )
    )

    private var groupsByCountryCode: [String: ArtistCountryGroup] {
        Dictionary(uniqueKeysWithValues: groups.map { ($0.code, $0) })
    }

    private var style: ArtistWorldMapStyle {
        ArtistWorldMapStyle(
            colorScheme: colorScheme,
            maximumArtistCount: max(1, groups.map(\.count).max() ?? 1),
            selectedCountryCode: selectedCountryCode
        )
    }

    private var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            minimumDistance: worldMapMinimumZoomDistance,
            maximumDistance: worldMapMaximumZoomDistance
        )
    }

    var body: some View {
        MapReader { proxy in
            Map(
                position: $cameraPosition,
                bounds: cameraBounds,
                interactionModes: [.pan, .zoom, .pitch],
                scope: mapScope
            ) {
                if let loadedMap {
                    ForEach(loadedMap.overlays, id: \.self) { overlay in
                        let appearance = appearance(for: overlay)
                        MapPolygon(overlay)
                            .foregroundStyle(appearance.fillColor)
                            .stroke(appearance.strokeColor, lineWidth: appearance.lineWidth)
                    }
                }
            }
            .mapStyle(
                .hybrid(
                    elevation: .realistic,
                    pointsOfInterest: .excludingAll,
                    showsTraffic: false
                )
            )
            .mapControls {
                MapScaleView()
            }
            .mapScope(mapScope)
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    selectCountry(at: value.location, using: proxy)
                }
            )
            .onAppear {
                debugWorldMapLog(
                    "SwiftUI Map appeared with \(loadedMap?.overlays.count ?? 0) overlays"
                )
            }
        }
    }

    private func appearance(for overlay: MKPolygon) -> WorldMapOverlayAppearance {
        let overlayID = ObjectIdentifier(overlay)
        let count = loadedMap?.overlayMetadataByID[ObjectIdentifier(overlay)].flatMap {
            groupsByCountryCode[$0.code]?.count
        } ?? 0
        let isSelected = loadedMap?.overlayMetadataByID[overlayID]?.code
            == selectedCountryCode
        return style.appearance(
            forArtistCount: count,
            isSelected: isSelected
        )
    }

    private func selectCountry(at point: CGPoint, using proxy: MapProxy) {
        guard
            let loadedMap,
            let coordinate = proxy.convert(point, from: .local)
        else {
            return
        }

        let mapPoint = MKMapPoint(coordinate)
        let cgPoint = CGPoint(x: mapPoint.x, y: mapPoint.y)

        for overlay in loadedMap.overlays.reversed() {
            let overlayID = ObjectIdentifier(overlay)
            guard
                let metadata = loadedMap.overlayMetadataByID[overlayID],
                groupsByCountryCode[metadata.code] != nil,
                let path = loadedMap.hitPathsByOverlayID[overlayID]
            else {
                continue
            }

            if path.contains(cgPoint, using: .evenOdd, transform: .identity) {
                onCountrySelected(metadata.code)
                return
            }
        }
    }
}

private struct ArtistWorldMapRepresentable {
    let groups: [ArtistCountryGroup]
    let loadedMap: LoadedWorldCountryMap?
    let selectedCountryCode: String?
    let onCountrySelected: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var style: ArtistWorldMapStyle {
        ArtistWorldMapStyle(
            colorScheme: colorScheme,
            maximumArtistCount: max(1, groups.map(\.count).max() ?? 1),
            selectedCountryCode: selectedCountryCode
        )
    }
}

#if os(iOS)
extension ArtistWorldMapRepresentable: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(onCountrySelected: onCountrySelected)
    }

    func makeUIView(context: Context) -> WorldMapMKMapView {
        let mapView = makeConfiguredMapView(coordinator: context.coordinator)
        context.coordinator.configure(mapView: mapView)
        return mapView
    }

    func updateUIView(_ mapView: WorldMapMKMapView, context: Context) {
        context.coordinator.onCountrySelected = onCountrySelected
        context.coordinator.update(
            mapView: mapView,
            groups: groups,
            style: style,
            loadedMap: loadedMap
        )
    }

    static func dismantleUIView(
        _ mapView: WorldMapMKMapView,
        coordinator: Coordinator
    ) {
        if let delegate = mapView.delegate as AnyObject?, delegate === coordinator {
            mapView.delegate = nil
        }
        mapView.countrySelectionHandler = nil
    }
}
#elseif os(macOS)
extension ArtistWorldMapRepresentable: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(onCountrySelected: onCountrySelected)
    }

    func makeNSView(context: Context) -> WorldMapMKMapView {
        let mapView = makeConfiguredMapView(coordinator: context.coordinator)
        context.coordinator.configure(mapView: mapView)
        return mapView
    }

    func updateNSView(_ mapView: WorldMapMKMapView, context: Context) {
        context.coordinator.onCountrySelected = onCountrySelected
        context.coordinator.update(
            mapView: mapView,
            groups: groups,
            style: style,
            loadedMap: loadedMap
        )
    }

    static func dismantleNSView(
        _ mapView: WorldMapMKMapView,
        coordinator: Coordinator
    ) {
        if let delegate = mapView.delegate as AnyObject?, delegate === coordinator {
            mapView.delegate = nil
        }
        mapView.countrySelectionHandler = nil
    }
}
#endif

private extension ArtistWorldMapRepresentable {
    @MainActor
    func makeConfiguredMapView(coordinator: Coordinator) -> WorldMapMKMapView {
        let mapView = WorldMapViewStore.shared.makeMapViewIfNeeded()
        mapView.delegate = coordinator
        return mapView
    }
}

private extension ArtistWorldMapRepresentable {
    final class Coordinator: NSObject, MKMapViewDelegate {
        var onCountrySelected: (String) -> Void

        private weak var mapView: MKMapView?
        private var style = ArtistWorldMapStyle(
            colorScheme: .light,
            maximumArtistCount: 1,
            selectedCountryCode: nil
        )
        private var groupsByCountryCode: [String: ArtistCountryGroup] = [:]
        private var overlayMetadataByID: [ObjectIdentifier: CountryOverlayMetadata] = [:]
        private var lastAppearanceSignature: Int? = nil

        init(onCountrySelected: @escaping (String) -> Void) {
            self.onCountrySelected = onCountrySelected
        }

        func configure(mapView: WorldMapMKMapView) {
            self.mapView = mapView
            mapView.countrySelectionHandler = { [weak self, weak mapView] point in
                guard let self, let mapView else {
                    return
                }

                self.selectCountry(at: point, in: mapView)
            }
        }

        func update(
            mapView: WorldMapMKMapView,
            groups: [ArtistCountryGroup],
            style: ArtistWorldMapStyle,
            loadedMap: LoadedWorldCountryMap?
        ) {
            self.mapView = mapView
            self.style = style
            groupsByCountryCode = Dictionary(
                uniqueKeysWithValues: groups.map { ($0.code, $0) }
            )

            if let loadedMap {
                installOverlaysIfNeeded(loadedMap, into: mapView)
            }

            refreshOverlayAppearance(in: mapView)
        }

        func mapView(
            _ mapView: MKMapView,
            rendererFor overlay: MKOverlay
        ) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            applyAppearance(to: renderer, overlay: overlay)
            return renderer
        }

        private func installOverlaysIfNeeded(
            _ loadedMap: LoadedWorldCountryMap,
            into mapView: WorldMapMKMapView
        ) {
            overlayMetadataByID = loadedMap.overlayMetadataByID
            if !mapView.hasInstalledWorldCountryOverlays {
                mapView.addOverlays(loadedMap.overlays)
                mapView.hasInstalledWorldCountryOverlays = true
            }
            applyInitialCameraIfNeeded(in: mapView)
        }

        private func applyInitialCameraIfNeeded(in mapView: WorldMapMKMapView) {
            guard !mapView.hasAppliedInitialWorldCamera else {
                return
            }

            mapView.setCameraZoomRange(
                MKMapView.CameraZoomRange(
                    minCenterCoordinateDistance: worldMapMinimumZoomDistance,
                    maxCenterCoordinateDistance: worldMapMaximumZoomDistance
                ),
                animated: false
            )
            mapView.setCameraBoundary(nil, animated: false)
            mapView.setCamera(
                MKMapCamera(
                    lookingAtCenter: CLLocationCoordinate2D(
                        latitude: 18,
                        longitude: 8
                    ),
                    fromDistance: 44_000_000,
                    pitch: 48,
                    heading: 0
                ),
                animated: false
            )
            mapView.hasAppliedInitialWorldCamera = true
        }

        private func refreshOverlayAppearance(in mapView: MKMapView) {
            let appearanceSignature = makeAppearanceSignature()
            guard appearanceSignature != lastAppearanceSignature else {
                return
            }
            lastAppearanceSignature = appearanceSignature

            for overlay in mapView.overlays {
                guard
                    let renderer = mapView.renderer(for: overlay)
                        as? MKPolygonRenderer
                else {
                    continue
                }

                applyAppearance(to: renderer, overlay: overlay)
            }
        }

        private func makeAppearanceSignature() -> Int {
            var hasher = Hasher()
            hasher.combine(style.colorSchemeHash)
            hasher.combine(style.maximumArtistCount)
            hasher.combine(style.selectedCountryCode)

            for countryCode in groupsByCountryCode.keys.sorted() {
                hasher.combine(countryCode)
                hasher.combine(groupsByCountryCode[countryCode]?.count ?? 0)
            }

            return hasher.finalize()
        }

        private func applyAppearance(
            to renderer: MKPolygonRenderer,
            overlay: MKOverlay
        ) {
            let overlayID = ObjectIdentifier(overlay as AnyObject)
            let countryCode = overlayMetadataByID[overlayID]?.code
            let count = overlayMetadataByID[overlayID].flatMap {
                groupsByCountryCode[$0.code]?.count
            } ?? 0
            let appearance = style.appearance(
                forArtistCount: count,
                isSelected: countryCode == style.selectedCountryCode
            )

            renderer.fillColor = appearance.fillPlatformColor
            renderer.strokeColor = appearance.strokePlatformColor
            renderer.lineWidth = appearance.lineWidth
        }

        private func selectCountry(at point: CGPoint, in mapView: MKMapView) {
            for overlay in mapView.overlays.reversed() {
                guard
                    let renderer = mapView.renderer(for: overlay)
                        as? MKOverlayPathRenderer,
                    let path = renderer.path
                else {
                    continue
                }

                let mapPoint = MKMapPoint(mapView.convert(
                    point,
                    toCoordinateFrom: mapView
                ))
                let rendererPoint = renderer.point(for: mapPoint)

                if path.contains(rendererPoint),
                    let metadata = overlayMetadataByID[
                        ObjectIdentifier(overlay as AnyObject)
                    ],
                    groupsByCountryCode[metadata.code] != nil
                {
                    onCountrySelected(metadata.code)
                    return
                }
            }
        }
    }
}

private struct ArtistWorldMapStyle {
    let colorScheme: ColorScheme
    let maximumArtistCount: Int
    let selectedCountryCode: String?

    var colorSchemeHash: Int {
        switch colorScheme {
        case .light:
            return 0
        case .dark:
            return 1
        @unknown default:
            return 2
        }
    }

    var strokeColor: PlatformColor {
        PlatformColor(
            red: colorScheme == .dark ? 0.06 : 0.14,
            green: colorScheme == .dark ? 0.07 : 0.15,
            blue: colorScheme == .dark ? 0.09 : 0.18,
            alpha: 1
        )
    }

    private var accentColor: PlatformColor {
        PlatformColor(
            red: colorScheme == .dark ? 0.847 : 0.596,
            green: colorScheme == .dark ? 0.498 : 0.184,
            blue: colorScheme == .dark ? 0.820 : 0.576,
            alpha: 1
        )
    }

    private var neutralColor: PlatformColor {
        PlatformColor(
            red: 0.192,
            green: 0.204,
            blue: 0.231,
            alpha: 0.82
        )
    }

    private var selectedStrokeColor: PlatformColor {
        PlatformColor(
            white: colorScheme == .dark ? 0.98 : 0.14,
            alpha: 1
        )
    }

    private var selectedFillBlendColor: PlatformColor {
        PlatformColor(
            red: colorScheme == .dark ? 0.98 : 0.90,
            green: colorScheme == .dark ? 0.88 : 0.72,
            blue: colorScheme == .dark ? 1.0 : 0.94,
            alpha: 1
        )
    }

    func appearance(
        forArtistCount count: Int,
        isSelected: Bool
    ) -> WorldMapOverlayAppearance {
        let baseFillColor = baseFillColor(forArtistCount: count)
        if isSelected {
            return WorldMapOverlayAppearance(
                fillPlatformColor: baseFillColor.mixed(
                    with: selectedFillBlendColor,
                    amount: 0.35
                ).withAlphaComponent(0.96),
                strokePlatformColor: selectedStrokeColor,
                lineWidth: 1.8
            )
        }

        return WorldMapOverlayAppearance(
            fillPlatformColor: baseFillColor,
            strokePlatformColor: strokeColor,
            lineWidth: 0.75
        )
    }

    private func baseFillColor(forArtistCount count: Int) -> PlatformColor {
        guard count > 0 else {
            return neutralColor
        }

        let strength = log(Double(count) + 1) / log(Double(maximumArtistCount) + 1)
        let mixAmount = CGFloat(0.18 + strength * 0.82)

        return neutralColor.mixed(
            with: accentColor,
            amount: mixAmount
        ).withAlphaComponent(0.78)
    }
}

struct WorldMapOverlayAppearance {
    let fillPlatformColor: PlatformColor
    let strokePlatformColor: PlatformColor
    let lineWidth: CGFloat

    var fillColor: Color {
        Color(platformColor: fillPlatformColor)
    }

    var strokeColor: Color {
        Color(platformColor: strokePlatformColor)
    }
}

struct CountryOverlayMetadata {
    let code: String
}

struct LoadedWorldCountryMap: @unchecked Sendable {
    let overlays: [MKPolygon]
    let overlayMetadataByID: [ObjectIdentifier: CountryOverlayMetadata]
    let hitPathsByOverlayID: [ObjectIdentifier: CGPath]
}

@MainActor
final class GeoJSONCountryOverlayLoader: ObservableObject {
    static let worldMapShared = GeoJSONCountryOverlayLoader(
        resourceNames: ["world_countries"]
    )
    static let detailPreviewShared = GeoJSONCountryOverlayLoader(
        resourceNames: ["world_countries_detail", "world_countries"]
    )

    @Published private(set) var loadedMap: LoadedWorldCountryMap? = nil
    @Published private(set) var isLoading = false
    @Published private(set) var hasFailed = false
    private var loadTask: Task<Void, Never>? = nil
    private let resourceNames: [String]

    private init(resourceNames: [String]) {
        self.resourceNames = resourceNames
    }

    func loadIfNeeded() {
        if loadedMap != nil || isLoading {
            debugWorldMapLog(
                "loadIfNeeded skipped loaded=\(loadedMap != nil) isLoading=\(isLoading)"
            )
            return
        }

        isLoading = true
        hasFailed = false
        let loadStart = Date()
        debugWorldMapLog("loadIfNeeded started")

        loadTask = Task {
            do {
                let resourceNames = self.resourceNames
                let loadedMap = try await Task.detached(priority: .userInitiated) {
                    try WorldCountryOverlayStore.buildLoadedMap(
                        resourceNames: resourceNames
                    )
                }.value

                guard !Task.isCancelled else {
                    return
                }

                self.loadedMap = loadedMap
                self.isLoading = false
                debugWorldMapLog(
                    "loadIfNeeded finished with \(loadedMap.overlays.count) overlays in \(debugWorldMapDurationSince(loadStart))"
                )
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self.hasFailed = true
                self.isLoading = false
                debugWorldMapLog(
                    "loadIfNeeded failed in \(debugWorldMapDurationSince(loadStart)): \(error)"
                )
            }
        }
    }

    func ensureLoadedMap() async -> LoadedWorldCountryMap? {
        loadIfNeeded()
        await loadTask?.value
        return loadedMap
    }
}

private enum WorldCountryOverlayStore {

    static func buildLoadedMap(resourceNames: [String]) throws -> LoadedWorldCountryMap {
        let buildStart = Date()
        debugWorldMapLog("buildLoadedMap start")
        guard let url = geoJSONURL(resourceNames: resourceNames) else {
            throw WorldCountryOverlayStoreError.resourceMissing
        }

        let data = try Data(contentsOf: url)
        let decoder = MKGeoJSONDecoder()
        let objects = try decoder.decode(data)

        var overlays: [MKPolygon] = []
        var overlayMetadataByID: [ObjectIdentifier: CountryOverlayMetadata] = [:]
        var hitPathsByOverlayID: [ObjectIdentifier: CGPath] = [:]
        for object in objects {
            guard let feature = object as? MKGeoJSONFeature else {
                continue
            }

            let metadata = metadata(for: feature)
            guard let code = metadata.code, code != "ATA" else {
                continue
            }

            for geometry in feature.geometry {
                if let polygon = geometry as? MKPolygon {
                    overlays.append(polygon)
                    let overlayID = ObjectIdentifier(polygon)
                    overlayMetadataByID[overlayID] = CountryOverlayMetadata(
                        code: code
                    )
                    hitPathsByOverlayID[overlayID] = makeHitPath(for: polygon)
                } else if let multiPolygon = geometry as? MKMultiPolygon {
                    for polygon in multiPolygon.polygons {
                        overlays.append(polygon)
                        let overlayID = ObjectIdentifier(polygon)
                        overlayMetadataByID[overlayID] = CountryOverlayMetadata(
                            code: code
                        )
                        hitPathsByOverlayID[overlayID] = makeHitPath(for: polygon)
                    }
                }
            }
        }

        let loadedMap = LoadedWorldCountryMap(
            overlays: overlays,
            overlayMetadataByID: overlayMetadataByID,
            hitPathsByOverlayID: hitPathsByOverlayID
        )
        debugWorldMapLog(
            "buildLoadedMap finished with \(loadedMap.overlays.count) overlays in \(debugWorldMapDurationSince(buildStart))"
        )
        return loadedMap
    }

    private static func geoJSONURL(resourceNames: [String]) -> URL? {
        for resourceName in resourceNames {
            if let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: "geojson"
            ) {
                return url
            }
        }

        return nil
    }

    private static func makeHitPath(for polygon: MKPolygon) -> CGPath {
        let path = CGMutablePath()
        addRing(of: polygon, to: path)
        for interiorPolygon in polygon.interiorPolygons ?? [] {
            addRing(of: interiorPolygon, to: path)
        }
        return path.copy() ?? path
    }

    private static func addRing(of polygon: MKPolygon, to path: CGMutablePath) {
        guard polygon.pointCount > 0 else {
            return
        }

        let points = polygon.points()
        path.move(
            to: CGPoint(
                x: points[0].x,
                y: points[0].y
            )
        )

        for index in 1..<polygon.pointCount {
            path.addLine(
                to: CGPoint(
                    x: points[index].x,
                    y: points[index].y
                )
            )
        }

        path.closeSubpath()
    }

    private static func metadata(for feature: MKGeoJSONFeature) -> (
        code: String?,
        name: String?
    ) {
        guard
            let properties = feature.properties,
            let rawObject = try? JSONSerialization.jsonObject(with: properties),
            let json = rawObject as? [String: Any]
        else {
            return (nil, nil)
        }

        let codeCandidates = [
            "ISO_A3_EH",
            "ISO_A3",
            "ADM0_A3",
            "WB_A3",
            "BRK_A3",
        ]
        let nameCandidates = [
            "NAME_EN",
            "ADMIN",
            "NAME_LONG",
            "SOVEREIGNT",
            "NAME",
        ]

        return (
            firstStringValue(in: json, keys: codeCandidates),
            firstStringValue(in: json, keys: nameCandidates)
        )
    }

    private static func firstStringValue(
        in json: [String: Any],
        keys: [String]
    ) -> String? {
        for key in keys {
            guard
                let value = json[key] as? String,
                !value.isEmpty,
                value != "-99"
            else {
                continue
            }

            return value
        }

        return nil
    }
}

private enum WorldCountryOverlayStoreError: Error {
    case resourceMissing
}

@MainActor
private final class WorldMapViewStore {
    static let shared = WorldMapViewStore()

    var mapView: WorldMapMKMapView?

    private init() {}

    func makeMapViewIfNeeded() -> WorldMapMKMapView {
        if let mapView {
            return mapView
        }

        let mapView = WorldMapMKMapView(frame: .zero)
        mapView.preferredConfiguration = {
            let configuration = MKHybridMapConfiguration(
                elevationStyle: .realistic
            )
            return configuration
        }()
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.showsUserLocation = false
        self.mapView = mapView
        return mapView
    }

    func prepareMapViewIfNeeded(with loadedMap: LoadedWorldCountryMap) {
        let mapView = makeMapViewIfNeeded()
        if !mapView.hasInstalledWorldCountryOverlays {
            mapView.addOverlays(loadedMap.overlays)
            mapView.hasInstalledWorldCountryOverlays = true
        }
        if !mapView.hasAppliedInitialWorldCamera {
            mapView.setCameraZoomRange(
                MKMapView.CameraZoomRange(
                    minCenterCoordinateDistance: worldMapMinimumZoomDistance,
                    maxCenterCoordinateDistance: worldMapMaximumZoomDistance
                ),
                animated: false
            )
            mapView.setCameraBoundary(nil, animated: false)
            mapView.setCamera(
                MKMapCamera(
                    lookingAtCenter: CLLocationCoordinate2D(
                        latitude: 18,
                        longitude: 8
                    ),
                    fromDistance: 44_000_000,
                    pitch: 48,
                    heading: 0
                ),
                animated: false
            )
            mapView.hasAppliedInitialWorldCamera = true
        }
    }
}

private final class WorldMapMKMapView: MKMapView {
    var hasInstalledWorldCountryOverlays = false
    var hasAppliedInitialWorldCamera = false
    var countrySelectionHandler: ((CGPoint) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        installCountrySelectionGestureRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installCountrySelectionGestureRecognizer()
    }

    private func installCountrySelectionGestureRecognizer() {
        #if os(iOS)
        let tapRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(handleCountrySelectionGesture(_:))
        )
        tapRecognizer.cancelsTouchesInView = false
        addGestureRecognizer(tapRecognizer)
        #elseif os(macOS)
        let clickRecognizer = NSClickGestureRecognizer(
            target: self,
            action: #selector(handleCountrySelectionGesture(_:))
        )
        addGestureRecognizer(clickRecognizer)
        #endif
    }

    #if os(iOS)
    @objc
    private func handleCountrySelectionGesture(
        _ recognizer: UITapGestureRecognizer
    ) {
        guard recognizer.state == .ended else {
            return
        }

        countrySelectionHandler?(recognizer.location(in: self))
    }
    #elseif os(macOS)
    @objc
    private func handleCountrySelectionGesture(
        _ recognizer: NSClickGestureRecognizer
    ) {
        guard recognizer.state == .ended else {
            return
        }

        countrySelectionHandler?(recognizer.location(in: self))
    }
    #endif
}

private extension PlatformColor {
    func mixed(with otherColor: PlatformColor, amount: CGFloat) -> PlatformColor {
        let clampedAmount = min(max(amount, 0), 1)

        var leftRed: CGFloat = 0
        var leftGreen: CGFloat = 0
        var leftBlue: CGFloat = 0
        var leftAlpha: CGFloat = 0
        var rightRed: CGFloat = 0
        var rightGreen: CGFloat = 0
        var rightBlue: CGFloat = 0
        var rightAlpha: CGFloat = 0

        getRed(&leftRed, green: &leftGreen, blue: &leftBlue, alpha: &leftAlpha)
        otherColor.getRed(
            &rightRed,
            green: &rightGreen,
            blue: &rightBlue,
            alpha: &rightAlpha
        )

        return PlatformColor(
            red: leftRed + (rightRed - leftRed) * clampedAmount,
            green: leftGreen + (rightGreen - leftGreen) * clampedAmount,
            blue: leftBlue + (rightBlue - leftBlue) * clampedAmount,
            alpha: leftAlpha + (rightAlpha - leftAlpha) * clampedAmount
        )
    }
}

private extension Color {
    init(platformColor: PlatformColor) {
        #if os(iOS)
        self.init(uiColor: platformColor)
        #elseif os(macOS)
        self.init(nsColor: platformColor)
        #endif
    }
}

private extension View {
    func glassPanel(cornerRadius: CGFloat) -> some View {
        modifier(WorldMapGlassPanelModifier(cornerRadius: cornerRadius))
    }
}

private struct WorldMapGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.02)),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: cornerRadius,
                        style: .continuous
                    )
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        }
    }
}

private struct WorldMapActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(.rudolstadt)
        }
    }
}
