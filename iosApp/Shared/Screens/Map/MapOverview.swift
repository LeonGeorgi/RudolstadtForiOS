import MapKit
import PDFKit
import SwiftUI
import WebKit

struct MapOverview: View {
    var initialPlaceID: FestivalPlaceID? = nil
    var presentsPlaceSheets = false
    var navigate: ((AppNavigationRoute) -> Void)? = nil
    @Environment(\.festivalData) private var data
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var settings: UserSettings
    @State private var initialized = false
    @State private var selectedMapID: String?
    @State private var selectedPlaceID: FestivalPlaceID?
    @State private var sheetNavigation = MapSheetNavigation<Stage>()
    @State private var sheetStartsWithList = false
    @State private var enabledCategories: Set<String> = []
    @State private var selectedProgramDay = ""
    @State private var sheetDetent: PresentationDetent = .medium
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.locationsScreen)
    @State private var showsUserLocation = false
    @State private var followsUserLocation = false
    @State private var showsLocationPermissionAlert = false
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion()
    @State private var focusTrigger = 0

    private var provider: (any FestivalMapProviding)? { data.features.map.value }
    private var selectedMap: FestivalMap? {
        provider?.maps.first { $0.id == selectedMapID }
            ?? provider?.maps.first { $0.id == provider?.defaultMapID }
    }
    private var visiblePlaces: [Stage] {
        guard let map = selectedMap else { return [] }
        return (data.stages).filter { place in
            let isPositioned: Bool
            switch map.content {
            case .geographic(let coordinates): isPositioned = coordinates[place.id] != nil
            case .illustrated(_, let positions): isPositioned = positions[place.id] != nil
            }
            let category = provider?.category(for: place.id)
            return isPositioned
                && (category == nil || enabledCategories.contains(category?.id ?? ""))
        }
    }

    private var isGeographicMap: Bool {
        if case .geographic = selectedMap?.content { return true }
        return false
    }

    private var canChangeMapStyle: Bool {
        #if os(iOS)
            return isGeographicMap
        #else
            if #available(macOS 14, *) { return isGeographicMap }
            return false
        #endif
    }

    private var locationAwareMap: some View {
        mapScreen
            .onAppear {
                sheetNavigation.returnToMap()
                guard !initialized else { return }
                initialized = true
                let maps = provider?.maps ?? []
                let stored = data.identity.flatMap { settings.selectedMap(for: $0) }
                selectedMapID = maps.first { $0.id == stored }?.id ?? provider?.defaultMapID
                let categoryIDs = Set(provider?.categories.map(\.id) ?? [])
                let saved = data.identity.flatMap { settings.mapVisibility(for: $0) }
                enabledCategories =
                    saved.map { $0.categories.intersection(categoryIDs) } ?? categoryIDs
                recenter()
                selectedPlaceID = initialPlaceID
                focusSelectedPlace()
            }
            .task(id: isGeographicMap) {
                guard isGeographicMap else {
                    showsUserLocation = false
                    followsUserLocation = false
                    locationManager.stopLocationTracking()
                    return
                }
                await Task.yield()
                guard !Task.isCancelled else { return }
                showsUserLocation = true
                locationManager.startLocationTracking()
            }
            .onDisappear {
                followsUserLocation = false
                locationManager.stopLocationTracking()
            }
            .onChange(of: locationManager.authorizationStatus) { _, _ in
                if locationManager.isLocationAccessDenied { followsUserLocation = false }
            }
            .alert("map.location.permission.title", isPresented: $showsLocationPermissionAlert) {
                #if os(iOS)
                    Button("map.location.open_settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                #endif
                Button("map.location.cancel", role: .cancel) {}
            } message: {
                Text("map.location.permission.message")
            }
    }

    var body: some View {
        locationAwareMap
            .onChange(of: selectedPlaceID) { _, _ in focusSelectedPlace() }
            .onChange(of: selectedMapID) { _, value in
                if let identity = data.identity, let value {
                    settings.setSelectedMap(value, for: identity)
                }
                let selection = selectedPlaceID
                recenter()
                selectedPlaceID = selection
                focusSelectedPlace()
            }
            .onChange(of: provider?.categories.map(\.id) ?? []) { old, new in
                let added = Set(new).subtracting(old)
                enabledCategories = enabledCategories.intersection(new).union(added)
            }
            .onChange(of: provider?.maps.map(\.id) ?? []) { _, ids in
                if !ids.contains(selectedMapID ?? "") { selectedMapID = provider?.defaultMapID }
            }
            .sheet(
                isPresented: $sheetNavigation.isSheetPresented,
                onDismiss: {
                    if let route = sheetNavigation.sheetDismissed() { navigate?(route) }
                    if sheetNavigation.selection == nil { selectedPlaceID = nil }
                }
            ) {
                placeSheetContent
                #if os(iOS)
                    .environment(\.isPresentedInMapSheet, true)
                #endif
                .presentationDetents(
                    sheetNavigation.selection == nil ? [.large] : [.medium, .large],
                    selection: $sheetDetent)
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(
                    sheetNavigation.selection == nil ? .disabled : .enabled(upThrough: .medium))
            }
    }

    private var mapScreen: some View {
        content
            .navigationTitle("locations.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { mapToolbar }
            .toolbarBackground(
                isGeographicMap ? .hidden : .visible, for: .navigationBar)
    }

    private var placeSheetContent: some View {
        NavigationStack(path: placeSheetPath) {
            Group {
                if sheetStartsWithList {
                    LocationListView()
                } else if let place = sheetNavigation.selection {
                    placeSheet(place).id(place.id)
                }
            }
            .toolbar {
                if !sheetStartsWithList || sheetNavigation.selection == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            sheetNavigation.isSheetPresented = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("locations.close")
                    }
                }
            }
            .navigationDestination(for: FestivalPlaceID.self) { id in
                if let place = data.stages.first(where: { $0.id == id }) {
                    placeSheet(place).id(place.id)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var mapToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if canChangeMapStyle || (provider?.maps.count ?? 0) > 1 {
                Menu {
                    if let provider, provider.maps.count > 1 {
                        Picker("map.title", selection: $selectedMapID) {
                            ForEach(provider.maps) { item in
                                Text(item.title.resolved()).tag(Optional(item.id))
                            }
                        }
                    }
                    if canChangeMapStyle {
                        Picker("map.type.title", selection: $settings.mapStyle) {
                            ForEach(FestivalMapStyle.allCases) { style in
                                Text(style.titleKey).tag(style)
                            }
                        }
                    }
                } label: {
                    Label("map.options", systemImage: "map")
                }
                .accessibilityIdentifier("festival-map-options")
            }
            if initialPlaceID == nil {
                Button(action: showPlaceList) {
                    Image(systemName: "list.bullet")
                }
                .accessibilityLabel("list.title")
                .disabled(data.stages.isEmpty)
                .accessibilityIdentifier("locations-view-mode-toggle")
                .appPopoverTip(
                    DiscoverabilityTips.locationsViewMode,
                    currentTipID: tipSequencer.currentTipID, arrowEdge: .top)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if let map = selectedMap {
                VStack(spacing: 0) {
                    ZStack(alignment: .bottomTrailing) {
                        mapContent(map)
                            .ignoresSafeArea()
                        mapCameraControls
                            .padding(.trailing, 22)
                            .padding(.bottom, 16)
                    }
                    .overlay(alignment: .top) { legend }
                    if case .geographic(let values) = map.content,
                        values.values.contains(where: \.isApproximate)
                    {
                        VStack(spacing: 4) {
                            Text("site_plan.coordinates_approximate")
                            if let source = values.values.compactMap(\.sourceURL).first {
                                Link("site_plan.coordinate_source", destination: source)
                            }
                        }
                        .font(.footnote).multilineTextAlignment(.center).padding(8)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    if case .unavailable = data.features.map {
                        Label("festival.map.unavailable", systemImage: "exclamationmark.triangle")
                            .font(.footnote).foregroundStyle(.secondary).padding()
                    } else if provider == nil {
                        Text("festival.locations_unavailable")
                            .font(.footnote).foregroundStyle(.secondary).padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var mapCameraControls: some View {
        VStack(spacing: 0) {
            Button(action: recenter) {
                Image(systemName: "target")
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(.primary)
            .accessibilityLabel("map.festival_area")
            .accessibilityIdentifier("festival-map-recenter")
            .appPopoverTip(
                DiscoverabilityTips.mapRecenter,
                currentTipID: tipSequencer.currentTipID, arrowEdge: .leading)

            if isGeographicMap {
                Button(action: locateUser) {
                    Image(systemName: "location.fill")
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(.blue)
                .accessibilityLabel("map.locate_me")
                .accessibilityIdentifier("festival-map-user-location")
                .accessibilityAddTraits(followsUserLocation ? .isSelected : [])
            }
        }
        .font(.system(size: 20, weight: .semibold))
        .buttonStyle(.plain)
        .modifier(MapCameraControlsStyle())
    }

    private func locateUser() {
        guard !locationManager.isLocationAccessDenied else {
            showsLocationPermissionAlert = true
            return
        }
        selectedPlaceID = nil
        followsUserLocation = true
        locationManager.startLocationTracking()
    }

    private func placeSheet(_ place: Stage) -> some View {
        StageDetailView(
            stage: place,
            highlightedEventId: nil,
            showsMap: false,
            showsNearbyStages: false,
            navigate: { route in
                if case .stage(let id, _) = route {
                    withAnimation {
                        sheetDetent = .medium
                        selectPlace(id)
                    }
                } else {
                    sheetNavigation.open(route)
                }
            },
            programDaySelection: $selectedProgramDay
        )
    }

    private var placeSheetPath: Binding<[FestivalPlaceID]> {
        Binding(
            get: {
                sheetStartsWithList ? sheetNavigation.selection.map { [$0.id] } ?? [] : []
            },
            set: { path in
                guard sheetStartsWithList else { return }
                if let id = path.last {
                    selectPlace(id)
                } else {
                    showPlaceList()
                }
            })
    }

    private func showPlaceList() {
        withAnimation {
            sheetStartsWithList = true
            selectedPlaceID = nil
            sheetDetent = .large
            sheetNavigation.showList()
        }
    }

    private var legend: some View {
        VStack(spacing: 8) {
            AppInlineTipView(
                tip: DiscoverabilityTips.mapLegend,
                currentTipID: tipSequencer.currentTipID, arrowEdge: .bottom)
            if let provider, !provider.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(provider.categories) { category in
                            let isEnabled = enabledCategories.contains(category.id)
                            let color = categoryColor(category)
                            Button {
                                toggle(category.id)
                            } label: {
                                Label {
                                    Text(category.title.resolved())
                                } icon: {
                                    Image(systemName: "circle.fill")
                                        .foregroundStyle(isEnabled ? color : .secondary)
                                }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary).lineLimit(1).padding(3)
                            }
                            .modifier(
                                MapLegendChipButtonStyle(isEnabled: isEnabled, tintColor: color)
                            )
                            .accessibilityValue(Text(isEnabled ? "On" : "Off"))
                        }
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
        .padding(.top, 8).padding(.horizontal, 10)
    }

    @ViewBuilder
    private func mapContent(_ map: FestivalMap) -> some View {
        switch map.content {
        case .geographic(let coordinates):
            let located = visiblePlaces.compactMap { place in
                coordinates[place.id].map {
                    LocatedFestivalPlace(
                        place: place,
                        coordinate: CLLocationCoordinate2D(
                            latitude: $0.latitude, longitude: $0.longitude))
                }
            }
            #if os(iOS)
                FestivalMapCanvas(
                    stages: located.map(\.place),
                    performancePlaceIDs: Set(data.events.map { $0.stage.id }),
                    selectedPlaceID: selectedPlaceID, focusTrigger: focusTrigger,
                    showsUserLocation: showsUserLocation,
                    mapStyle: settings.mapStyle,
                    followsUserLocation: $followsUserLocation,
                    isPlaceSheetPresented: sheetNavigation.selection != nil,
                    onSelectPlace: selectMapPlace
                )
            #else
                if #available(macOS 14, *) {
                    FestivalGeographicMap(
                        places: located, region: region, focusTrigger: focusTrigger,
                        showsUserLocation: showsUserLocation,
                        mapStyle: settings.mapStyle,
                        followsUserLocation: $followsUserLocation
                    ) {
                        marker($0)
                    }
                } else {
                    Map(
                        coordinateRegion: $region, showsUserLocation: showsUserLocation,
                        userTrackingMode: Binding(
                            get: { followsUserLocation ? .follow : .none },
                            set: { followsUserLocation = $0 != .none }),
                        annotationItems: located
                    ) { item in
                        MapAnnotation(coordinate: item.coordinate) { marker(item.place) }
                    }
                }
            #endif
        case .illustrated(let artwork, let positions):
            FestivalIllustratedMap(
                artwork: artwork, positions: positions,
                places: visiblePlaces, focusTrigger: focusTrigger, marker: marker
            )
            .id(map.id)
        }
    }

    private func marker(_ place: Stage) -> some View {
        Button {
            selectMapPlace(place.id)
        } label: {
            StageNumber(stage: place, size: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(place.name.resolved())
        .accessibilityIdentifier("festival-place-\(place.id)")
    }

    private func toggle(_ id: String) {
        if enabledCategories.contains(id) {
            if enabledCategories.count > 1 { enabledCategories.remove(id) }
        } else {
            enabledCategories.insert(id)
        }
        saveMapVisibility()
    }
    private func saveMapVisibility() {
        if let identity = data.identity {
            settings.setMapVisibility(categories: enabledCategories, legend: true, for: identity)
        }
    }
    private func categoryColor(_ category: MapCategory) -> Color {
        .festivalCategory(
            tintHex: category.tintHex, darkTintHex: category.darkTintHex,
            colorScheme: colorScheme)
    }
    private func selectMapPlace(_ id: FestivalPlaceID) {
        sheetStartsWithList = false
        selectPlace(id)
    }

    private func selectPlace(_ id: FestivalPlaceID) {
        guard let place = data.stages.first(where: { $0.id == id }) else { return }
        guard presentsPlaceSheets else {
            navigate?(.stage(id: id, highlightedEventId: nil))
            return
        }
        if sheetNavigation.selection?.id != id { selectedProgramDay = "" }
        selectedPlaceID = id
        if sheetNavigation.selection == nil { sheetDetent = .medium }
        sheetNavigation.select(place)
    }

    private func focusSelectedPlace() {
        if let id = selectedPlaceID, let category = provider?.category(for: id) {
            enabledCategories.insert(category.id)
        }
        guard let id = selectedPlaceID, case .geographic(let coordinates) = selectedMap?.content,
            let coordinate = coordinates[id]
        else { return }
        followsUserLocation = false
        focusTrigger += 1
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: coordinate.latitude, longitude: coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003))
    }
    private func recenter() {
        followsUserLocation = false
        selectedPlaceID = nil
        guard case .geographic(let coordinates) = selectedMap?.content else {
            focusTrigger += 1
            return
        }
        let visibleIDs = Set(visiblePlaces.map(\.id))
        let values = coordinates.filter { visibleIDs.contains($0.key) }.map(\.value)
        guard let minLat = values.map(\.latitude).min(), let maxLat = values.map(\.latitude).max(),
            let minLon = values.map(\.longitude).min(), let maxLon = values.map(\.longitude).max()
        else { return }
        focusTrigger += 1
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.002, (maxLat - minLat) * 1.3),
                longitudeDelta: max(0.002, (maxLon - minLon) * 1.3)))
    }
}

private struct FestivalIllustratedMap<Marker: View>: View {
    let artwork: FestivalMapArtwork
    let positions: [FestivalPlaceID: NormalizedMapPoint]
    let places: [Stage]
    let focusTrigger: Int
    let marker: (Stage) -> Marker
    // Retain the zoom model without observing it here; only pins and the native adapter observe scale.
    @State private var zoom = FestivalMapZoomState()

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let height = width * artwork.logicalSize.height / artwork.logicalSize.width
            FestivalZoomableMap(contentSize: CGSize(width: width, height: height), zoom: zoom) {
                ZStack(alignment: .topLeading) {
                    FestivalArtworkView(artwork: artwork).frame(width: width, height: height)
                    ForEach(places) { place in
                        if let point = positions[place.id] {
                            marker(place)
                                .modifier(FestivalMapMarkerScale(zoom: zoom))
                                .position(x: width * point.x, y: height * point.y)
                        }
                    }
                }
                .frame(width: width, height: height)
            }
            .overlay(alignment: .bottomTrailing) {
                HStack {
                    Button {
                        zoom.scale = max(1, zoom.scale / 1.5)
                    } label: {
                        Label("map.zoom_out", systemImage: "minus.magnifyingglass")
                    }
                    Button {
                        zoom.scale = min(8, zoom.scale * 1.5)
                    } label: {
                        Label("map.zoom_in", systemImage: "plus.magnifyingglass")
                    }
                }.buttonStyle(.bordered).labelStyle(.iconOnly).padding().background(.background)
            }
        }
        .onChange(of: focusTrigger) { _, _ in zoom.scale = 1 }
    }
}

struct FestivalOriginalPlanView: View {
    let document: SitePlanDocument
    var position: SitePlanPosition? = nil
    var body: some View {
        VStack(spacing: 0) {
            if let pdf = PDFDocument(url: document.localFileURL) {
                FestivalPlanDocumentView(
                    document: pdf,
                    point: position.map { FestivalPlanPoint(x: $0.point.x, y: $0.point.y) },
                    pageIndex: position?.pageIndex ?? 0)
            } else {
                Label("site_plan.unavailable", systemImage: "doc.badge.exclamationmark")
            }
            if let source = document.sourceURL {
                Link("site_plan.official_source", destination: source).font(.footnote).padding(8)
            }
        }.navigationTitle(document.title.resolved())
    }
}

private struct FestivalArtworkView: View {
    let artwork: FestivalMapArtwork
    @State private var previewImage: Image?
    @State private var isLoading = true

    var body: some View {
        Group {
            switch artwork.format {
            case .svg, .rasterImage:
                FestivalImageWebView(url: artwork.localFileURL)
                    .id(artwork.sha256 + artwork.localFileURL.absoluteString).allowsHitTesting(
                        false)
            case .pdf:
                if let previewImage {
                    previewImage.resizable().scaledToFit()
                } else if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.secondary)
                }
            }
        }
        .task(id: artwork.sha256 + artwork.localFileURL.absoluteString) {
            isLoading = true
            let data = await Self.thumbnail(artwork)
            #if os(iOS)
                previewImage = data.flatMap { UIImage(data: $0) }.map { Image(uiImage: $0) }
            #else
                previewImage = data.flatMap { NSImage(data: $0) }.map { Image(nsImage: $0) }
            #endif
            isLoading = false
        }
        .accessibilityHidden(true)
    }

    nonisolated private static func thumbnail(_ artwork: FestivalMapArtwork) async -> Data? {
        guard case .pdf(let pageIndex) = artwork.format,
            let page = PDFDocument(url: artwork.localFileURL)?.page(at: pageIndex)
        else { return nil }
        let scale = min(4, 4096 / max(artwork.logicalSize.width, artwork.logicalSize.height))
        let image = page.thumbnail(
            of: CGSize(
                width: artwork.logicalSize.width * scale,
                height: artwork.logicalSize.height * scale), for: .mediaBox)
        #if os(iOS)
            return image.pngData()
        #else
            return image.tiffRepresentation
        #endif
    }
}

private struct LocatedFestivalPlace: Identifiable {
    let place: Stage
    let coordinate: CLLocationCoordinate2D
    var id: FestivalPlaceID { place.id }
}

@available(iOS 17, macOS 14, *)
private struct FestivalGeographicMap<Marker: View>: View {
    let places: [LocatedFestivalPlace]
    let region: MKCoordinateRegion
    let focusTrigger: Int
    let showsUserLocation: Bool
    let mapStyle: FestivalMapStyle
    @Binding var followsUserLocation: Bool
    let marker: (Stage) -> Marker
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(places) { item in
                Annotation(item.place.name.resolved(), coordinate: item.coordinate) {
                    marker(item.place)
                }
            }
            if showsUserLocation { UserAnnotation() }
        }
        .mapStyle(mapStyle.swiftUIStyle)
        .onAppear { updatePosition() }
        .onChange(of: focusTrigger) { _, _ in position = .region(region) }
        .onChange(of: followsUserLocation) { _, _ in updatePosition() }
        .onChange(of: position.positionedByUser) { _, positionedByUser in
            if positionedByUser { followsUserLocation = false }
        }
    }

    private func updatePosition() {
        if followsUserLocation {
            position = .userLocation(followsHeading: false, fallback: .region(region))
        } else if !position.positionedByUser {
            position = .region(region)
        }
    }
}

private func festivalArtworkWebView(url: URL) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.userContentController.addUserScript(
        WKUserScript(
            source: """
                const root = document.documentElement;
                root.style.width = '100%'; root.style.height = '100%'; root.style.margin = '0';
                if (document.body) { document.body.style.margin = '0'; document.body.style.height = '100%'; document.body.style.overflow = 'hidden'; }
                document.querySelectorAll('img, svg').forEach(image => {
                    image.style.width = '100%'; image.style.height = '100%'; image.style.objectFit = 'contain';
                });
                """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
    let view = WKWebView(frame: .zero, configuration: configuration)
    view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    return view
}

#if os(iOS)
    private struct FestivalImageWebView: UIViewRepresentable {
        let url: URL
        func makeUIView(context: Context) -> WKWebView {
            let view = festivalArtworkWebView(url: url)
            view.scrollView.isScrollEnabled = false
            return view
        }
        func updateUIView(_ view: WKWebView, context: Context) {}
    }
#else
    private struct FestivalImageWebView: NSViewRepresentable {
        let url: URL
        func makeNSView(context: Context) -> WKWebView {
            let view = festivalArtworkWebView(url: url)
            return view
        }
        func updateNSView(_ view: WKWebView, context: Context) {}
    }
#endif

private struct MapCameraControlsStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

private struct MapLegendChipButtonStyle: ViewModifier {
    let isEnabled: Bool
    let tintColor: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.mini)
                .tint(isEnabled ? tintColor : .gray.opacity(0.55))
        } else {
            content
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(isEnabled ? tintColor : .gray)
        }
    }
}
