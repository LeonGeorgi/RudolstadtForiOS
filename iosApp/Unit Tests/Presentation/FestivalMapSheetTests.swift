#if os(iOS)
import MapKit
import SwiftUI
import Testing
@testable import Rudolstadt

@MainActor
@Suite(.serialized)
struct FestivalMapSheetTests {
    @Test
    func listAndPlaceSelectionUseTheSameSheet() {
        var navigation = MapSheetNavigation<Int>()
        navigation.showList()
        #expect(navigation.isSheetPresented)
        #expect(navigation.selection == nil)

        navigation.select(101)
        #expect(navigation.isSheetPresented)
        #expect(navigation.selection == 101)

        navigation.showList()
        #expect(navigation.isSheetPresented)
        #expect(navigation.selection == nil)

        navigation.isSheetPresented = false
        #expect(navigation.sheetDismissed() == nil)
        navigation.returnToMap()
        #expect(!navigation.isSheetPresented)
    }

    @Test
    func artistNavigationWaitsForSheetDismissalAndRestoresSelectionOnReturn() {
        var navigation = MapSheetNavigation<Int>()
        let artist = AppNavigationRoute.artist(id: 5, highlightedEventId: 12, transitionSourceID: nil)
        navigation.select(101)

        navigation.open(artist)
        #expect(!navigation.isSheetPresented)
        #expect(navigation.selection == 101)

        let destination = navigation.sheetDismissed()
        #expect(destination == artist)
        #expect(navigation.selection == 101)

        navigation.returnToMap()
        #expect(navigation.isSheetPresented)
        #expect(navigation.selection == 101)

        navigation.select(102)
        #expect(navigation.selection == 102)
    }

    @Test
    func swipingSheetAwayClearsSelectionWithoutOpeningAPage() {
        var navigation = MapSheetNavigation<String>()
        navigation.select("DEU")
        navigation.isSheetPresented = false
        let destination = navigation.sheetDismissed()

        #expect(destination == nil)
        #expect(navigation.selection == nil)
        #expect(!navigation.isSheetPresented)
    }

    @Test
    func removedCountryDoesNotRestoreAnEmptySheetOnReturn() {
        var navigation = MapSheetNavigation<String>()
        navigation.select("DEU")
        navigation.open(.artist(id: 5, highlightedEventId: nil, transitionSourceID: nil))
        _ = navigation.sheetDismissed()

        navigation.clearSelection()
        navigation.returnToMap()

        #expect(navigation.selection == nil)
        #expect(!navigation.isSheetPresented)
    }

    @Test(arguments: [false, true])
    func placeRoutesOpenTheClassicDetailWithoutASheet(usesFestivalDestination: Bool) async throws {
        let stage = TestFixtures.stage(id: 101, stageNumber: 7)
        let settings = TestFixtures.userSettings()
        let profile = FestivalProfileStore(userDefaults: settings.userDefaults, cloudKitEnabled: false)
        let adapter = FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(),
            archive: false, includesSupplementaryInformation: false)
        let data = try adapter.prepare(FestivalData(artists: [], areas: [], stages: [stage], events: []), source: .preview)
        let root = NavigationStack {
            AppNavigationDestination(route: usesFestivalDestination
                ? .festival(.place(stage.id))
                : .stage(id: stage.id, highlightedEventId: nil))
        }
        .environment(\.festivalData, data)
        .environmentObject(settings)
        .environmentObject(profile)
        .environmentObject(profile.friendProfilesStore)
        let host = UIHostingController(rootView: root)
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        }
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        try await waitUntil { findMap(in: host.view) != nil }
        let preview = try #require(findMap(in: host.view))
        #expect(preview.accessibilityIdentifier != "festival-map")
        #expect(host.presentedViewController == nil)
        let annotation = try #require(preview.annotations.first { $0 is FestivalMapAnnotation })
        try await waitUntil { preview.view(for: annotation) is MKMarkerAnnotationView }
        let marker = try #require(preview.view(for: annotation) as? MKMarkerAnnotationView)
        #expect(marker.glyphText == "7")
        #expect(marker.accessibilityIdentifier == "festival-place-\(stage.id)")
    }

    @Test
    func selectingAnotherPinKeepsTheSheetAtMediumHeight() async throws {
        let settings = TestFixtures.userSettings()
        let profile = FestivalProfileStore(userDefaults: settings.userDefaults, cloudKitEnabled: false)
        let adapter = FestivalRegistry.rudolstadt(year: 2026, source: FestivalDataProviderStub(),
            archive: false, includesSupplementaryInformation: false)
        let stages = [TestFixtures.stage(id: 101), TestFixtures.stage(id: 102)]
        let raw = FestivalData(artists: [], areas: [], stages: stages, events: [])
        let snapshot = try adapter.prepare(raw, source: .preview)
        let data = snapshot
        let root = NavigationStack { MapOverview(presentsPlaceSheets: true) }
            .environment(\.festivalData, data)
            .environmentObject(settings)
            .environmentObject(profile)
            .environmentObject(profile.friendProfilesStore)
        let host = UIHostingController(rootView: root)
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        }
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            host.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        try await waitUntil { findMap(in: host.view)?.annotations.count == 2 }
        let map = try #require(findMap(in: host.view))
        let first = try #require(map.annotations.first { $0.title == stages[0].localizedName })
        let second = try #require(map.annotations.first { $0.title == stages[1].localizedName })
        map.selectAnnotation(first, animated: false)
        try await waitUntil { host.presentedViewController?.sheetPresentationController?.selectedDetentIdentifier == .medium }
        try await Task.sleep(for: .milliseconds(600))
        let initialHeight = try #require(host.presentedViewController?.view.bounds.height)

        map.selectAnnotation(second, animated: false)
        try await waitUntil {
            (map.delegate as? FestivalMapCanvas.Coordinator)?.parent.selectedPlaceID == stages[1].id
        }
        try await Task.sleep(for: .seconds(1))

        let sheet = try #require(host.presentedViewController)
        #expect(sheet.sheetPresentationController?.selectedDetentIdentifier == .medium)
        #expect(abs(sheet.view.bounds.height - initialHeight) < 1)
    }

    private func findMap(in view: UIView) -> MKMapView? {
        if let map = view as? MKMapView { return map }
        return view.subviews.lazy.compactMap { findMap(in: $0) }.first
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(condition())
    }
}

@MainActor
struct FestivalMapCameraTests {
    @Test
    func ownLocationTakesPriorityOverPendingFestivalFocus() {
        let coordinator = makeCoordinator(followsUserLocation: .constant(true))
        let map = CameraMapView()
        coordinator.pendingFocus = []

        coordinator.performPendingFocus(in: map)
        coordinator.performPendingFocus(in: map)

        #expect(map.trackingRequests == [.follow])
        #expect(map.festivalFocusCount == 0)
        #expect(coordinator.pendingFocus == nil)
    }

    @Test
    func festivalFocusStopsFollowingAndFitsThePlaces() {
        let coordinator = makeCoordinator(followsUserLocation: .constant(false))
        let map = CameraMapView()
        map.userTrackingMode = .follow
        coordinator.pendingFocus = []

        coordinator.performPendingFocus(in: map)

        #expect(map.trackingRequests == [.none])
        #expect(map.festivalFocusCount > 0)
    }

    @Test
    func manualPanningStopsFollowingWithoutResettingTheMap() async throws {
        var followsUserLocation = true
        let binding = Binding(get: { followsUserLocation }, set: { followsUserLocation = $0 })
        let coordinator = makeCoordinator(followsUserLocation: binding)
        let map = CameraMapView()

        coordinator.mapView(map, didChange: .none, animated: false)
        for _ in 0..<50 where followsUserLocation { try await Task.sleep(for: .milliseconds(10)) }
        coordinator.performPendingFocus(in: map)

        #expect(!followsUserLocation)
        #expect(map.festivalFocusCount == 0)
        #expect(map.trackingRequests.isEmpty)
    }

    @Test
    func staleStopFollowingCallbackDoesNotCancelANewLocationRequest() async throws {
        var followsUserLocation = true
        let binding = Binding(get: { followsUserLocation }, set: { followsUserLocation = $0 })
        let coordinator = makeCoordinator(followsUserLocation: binding)
        let map = CameraMapView()

        coordinator.mapView(map, didChange: .none, animated: false)
        map.userTrackingMode = .follow
        try await Task.sleep(for: .milliseconds(20))

        #expect(followsUserLocation)
    }

    @Test
    func changingMapStyleKeepsCameraAndLocationTracking() {
        let coordinator = makeCoordinator(followsUserLocation: .constant(true))
        let map = CameraMapView()
        map.userTrackingMode = .follow
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.72, longitude: 11.34),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.03)), animated: false)
        let initialRegion = map.region
        coordinator.updateConfiguration(in: map)
        #expect(map.preferredConfiguration is MKStandardMapConfiguration)

        for style in [FestivalMapStyle.satellite, .hybrid] {
            coordinator.parent = makeCoordinator(
                followsUserLocation: .constant(true), mapStyle: style).parent
            coordinator.updateConfiguration(in: map)

            switch style {
            case .satellite: #expect(map.preferredConfiguration is MKImageryMapConfiguration)
            case .hybrid: #expect(map.preferredConfiguration is MKHybridMapConfiguration)
            case .standard: break
            }
            #expect(abs(map.region.center.latitude - initialRegion.center.latitude) < 0.000001)
            #expect(abs(map.region.center.longitude - initialRegion.center.longitude) < 0.000001)
            #expect(abs(map.region.span.latitudeDelta - initialRegion.span.latitudeDelta) < 0.000001)
            #expect(abs(map.region.span.longitudeDelta - initialRegion.span.longitudeDelta) < 0.000001)
            #expect(map.userTrackingMode == .follow)
            #expect(map.trackingRequests.isEmpty)
        }
    }

    private func makeCoordinator(followsUserLocation: Binding<Bool>,
                                 mapStyle: FestivalMapStyle = .standard) -> FestivalMapCanvas.Coordinator {
        FestivalMapCanvas(
            stages: [TestFixtures.stage(id: 101)], performancePlaceIDs: [],
            selectedPlaceID: nil, focusTrigger: 1, showsUserLocation: true,
            mapStyle: mapStyle,
            followsUserLocation: followsUserLocation,
            isPlaceSheetPresented: false, onSelectPlace: { _ in }
        ).makeCoordinator()
    }

    private final class CameraMapView: MKMapView {
        private var trackingMode: MKUserTrackingMode = .none
        var trackingRequests: [MKUserTrackingMode] = []
        var festivalFocusCount = 0

        init() {
            super.init(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override var userTrackingMode: MKUserTrackingMode {
            get { trackingMode }
            set { trackingMode = newValue }
        }

        override func setUserTrackingMode(_ mode: MKUserTrackingMode, animated: Bool) {
            trackingRequests.append(mode)
            trackingMode = mode
        }

        override func setVisibleMapRect(_ mapRect: MKMapRect, edgePadding insets: UIEdgeInsets,
                                        animated animate: Bool) {
            festivalFocusCount += 1
        }
    }
}

@MainActor
struct FestivalLocationPermissionTests {
    @Test(arguments: [CLAuthorizationStatus.denied, .restricted])
    func deniedAccessDoesNotStartLocationUpdates(status: CLAuthorizationStatus) {
        let native = StubLocationManager(status: status)
        let location = LocationManager(manager: native)

        location.startLocationTracking()

        #expect(location.isLocationAccessDenied)
        #expect(native.startCount == 0)
        #expect(native.permissionRequestCount == 0)
    }

    @Test
    func grantingPermissionStartsThePendingLocationRequest() {
        let native = StubLocationManager(status: .notDetermined)
        let location = LocationManager(manager: native)
        location.startLocationTracking()
        #expect(native.permissionRequestCount == 1)

        native.status = .authorizedWhenInUse
        location.locationManagerDidChangeAuthorization(native)
        location.startLocationTracking()

        #expect(location.authorizationStatus == .authorizedWhenInUse)
        #expect(!location.isLocationAccessDenied)
        #expect(native.startCount == 1)
    }

    @Test
    func leavingTheMapCancelsAPendingPermissionRequest() {
        let native = StubLocationManager(status: .notDetermined)
        let location = LocationManager(manager: native)
        location.startLocationTracking()
        location.stopLocationTracking()

        native.status = .authorizedWhenInUse
        location.locationManagerDidChangeAuthorization(native)

        #expect(native.startCount == 0)
    }

    @Test
    func regrantingPermissionRestartsUpdatesAfterRevocation() {
        let native = StubLocationManager(status: .authorizedWhenInUse)
        let location = LocationManager(manager: native)
        location.startLocationTracking()

        native.status = .denied
        location.locationManagerDidChangeAuthorization(native)
        #expect(location.isLocationAccessDenied)

        native.status = .authorizedWhenInUse
        location.locationManagerDidChangeAuthorization(native)

        #expect(native.startCount == 2)
    }

    private final class StubLocationManager: CLLocationManager {
        var status: CLAuthorizationStatus
        var startCount = 0
        var permissionRequestCount = 0

        init(status: CLAuthorizationStatus) {
            self.status = status
            super.init()
        }

        override var authorizationStatus: CLAuthorizationStatus { status }
        override func startUpdatingLocation() { startCount += 1 }
        override func stopUpdatingLocation() {}
        override func requestWhenInUseAuthorization() { permissionRequestCount += 1 }
    }
}
#endif
