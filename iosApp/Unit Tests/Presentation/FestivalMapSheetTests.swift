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
#endif
