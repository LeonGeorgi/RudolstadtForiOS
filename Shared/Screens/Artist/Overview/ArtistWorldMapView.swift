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

struct ArtistWorldMapView: View {
    let artistCountsByCountryCode: [String: Int]

    var navigate: ((AppNavigationRoute) -> Void)? = nil
    @State private var sheetNavigation = MapSheetNavigation<String>()
    @State private var sheetDetent: PresentationDetent = .medium
    @StateObject private var overlayLoader = GeoJSONCountryOverlayLoader.worldMapShared

    static func preloadResources() {
        let overlayLoader = GeoJSONCountryOverlayLoader.worldMapShared
        overlayLoader.loadIfNeeded()
    }

    var body: some View {
        Group {
            if artistCountsByCountryCode.isEmpty {
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
                    ArtistWorldMapSwiftUIMap(
                        artistCountsByCountryCode: artistCountsByCountryCode,
                        loadedMap: overlayLoader.loadedMap,
                        selectedCountryCode: sheetNavigation.selection
                    ) { countryCode in
                        if sheetNavigation.selection == nil { sheetDetent = .medium }
                        sheetNavigation.select(countryCode)
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
        .accessibilityIdentifier("artist-world-map")
        .sheet(isPresented: $sheetNavigation.isSheetPresented, onDismiss: {
            if let route = sheetNavigation.sheetDismissed() { navigate?(route) }
        }) {
            Group {
                if let country = sheetNavigation.selection {
                    NavigationStack {
                        ArtistCountryListRouteView(
                            countryCode: country,
                            imageTransitionNamespace: nil,
                            showsCountryPreview: false,
                            onSelectArtist: { sheetNavigation.open($0) }
                        )
                    }
                    .id(country)
                }
            }
            #if os(iOS)
            .environment(\.isPresentedInMapSheet, true)
            #endif
            .presentationDetents([.medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .onAppear { sheetNavigation.returnToMap() }
        .onChange(of: artistCountsByCountryCode) { _, counts in
            if let country = sheetNavigation.selection, counts[country] == nil {
                sheetNavigation.clearSelection()
            }
        }
        .task {
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

private struct ArtistWorldMapSwiftUIMap: View {
    let artistCountsByCountryCode: [String: Int]
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

    private var cameraBounds: MapCameraBounds {
        MapCameraBounds(
            minimumDistance: worldMapMinimumZoomDistance,
            maximumDistance: worldMapMaximumZoomDistance
        )
    }

    private var accessibilityCountryCodes: [String] {
        artistCountsByCountryCode.keys.sorted {
            localizedCountryName(forRegionCode: $0).localizedCaseInsensitiveCompare(
                localizedCountryName(forRegionCode: $1)
            ) == .orderedAscending
        }
    }

    var body: some View {
        let style = ArtistWorldMapStyle(
            colorScheme: colorScheme,
            maximumArtistCount: artistCountsByCountryCode.values.max() ?? 1
        )

        MapReader { proxy in
            Map(
                position: $cameraPosition,
                bounds: cameraBounds,
                interactionModes: [.pan, .zoom, .pitch],
                scope: mapScope
            ) {
                if let loadedMap {
                    ForEach(loadedMap.overlays, id: \.self) { overlay in
                        let count = loadedMap.overlayMetadataByID[ObjectIdentifier(overlay)]
                            .flatMap { artistCountsByCountryCode[$0.code] } ?? 0
                        let appearance = style.appearance(forArtistCount: count)
                        let isSelected = loadedMap.overlayMetadataByID[ObjectIdentifier(overlay)]?.code
                            == selectedCountryCode
                        MapPolygon(overlay)
                            .foregroundStyle(appearance.fillColor)
                            .stroke(
                                isSelected ? Color.primary : appearance.strokeColor,
                                lineWidth: isSelected ? 1.8 : appearance.lineWidth
                            )
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
        }
        .accessibilityRepresentation {
            VStack {
                ForEach(accessibilityCountryCodes, id: \.self) { code in
                    Button {
                        onCountrySelected(code)
                    } label: {
                        Text(accessibilityLabel(for: code))
                    }
                    .accessibilityAddTraits(code == selectedCountryCode ? .isSelected : [])
                }
            }
            .disabled(loadedMap == nil)
        }
    }

    private func accessibilityLabel(for code: String) -> String {
        let artistCount = artistCountsByCountryCode[code] ?? 0
        let countKey = artistCount == 1
            ? "artists.map.accessibility.artist_count.one"
            : "artists.map.accessibility.artist_count.other"
        let count = String(
            format: NSLocalizedString(countKey, comment: ""),
            locale: Locale.current,
            artistCount
        )
        return "\(localizedCountryName(forRegionCode: code)), \(count)"
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
                artistCountsByCountryCode[metadata.code] != nil,
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

@MainActor
private struct ArtistWorldMapStyle {
    let colorScheme: ColorScheme
    let maximumArtistCount: Int

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

    func appearance(forArtistCount count: Int) -> WorldMapOverlayAppearance {
        WorldMapOverlayAppearance(
            fillPlatformColor: baseFillColor(forArtistCount: count),
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
    private let resourceNames: [String]

    private init(resourceNames: [String]) {
        self.resourceNames = resourceNames
    }

    func loadIfNeeded() {
        if loadedMap != nil || isLoading {
            return
        }

        isLoading = true
        hasFailed = false

        Task {
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
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                self.hasFailed = true
                self.isLoading = false
            }
        }
    }
}

enum WorldCountryOverlayStore {

    static func buildLoadedMap(resourceNames: [String]) throws -> LoadedWorldCountryMap {
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

            guard let code = countryCode(for: feature), code != "ATA" else {
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

    private static func countryCode(for feature: MKGeoJSONFeature) -> String? {
        guard
            let properties = feature.properties,
            let rawObject = try? JSONSerialization.jsonObject(with: properties),
            let json = rawObject as? [String: Any]
        else {
            return nil
        }

        let codeCandidates = [
            "ISO_A3_EH",
            "ISO_A3",
            "ADM0_A3",
            "WB_A3",
            "BRK_A3",
        ]
        guard let code = firstStringValue(in: json, keys: codeCandidates) else {
            return nil
        }
        return parseArtistCountryCodes(code).first ?? code
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
