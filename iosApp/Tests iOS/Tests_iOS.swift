import XCTest

final class NativeScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testGermanScreenshots() throws { try capture(locale: "de") }
    @MainActor func testEnglishScreenshots() throws { try capture(locale: "en") }

    @MainActor private func capture(locale: String) throws {
        let app = XCUIApplication()
        let german = locale == "de"
        XCUIDevice.shared.orientation = .portrait

        func identifier(_ name: String) -> XCUIElement {
            app.descendants(matching: .any).matching(identifier: name).firstMatch
        }
        func wait(_ element: XCUIElement, timeout: TimeInterval = 20) throws {
            guard element.waitForExistence(timeout: timeout) else {
                XCTFail("Missing screenshot element: \(element)")
                throw CaptureFailure.missingElement
            }
        }
        func tapID(_ name: String) throws {
            let element = identifier(name)
            try wait(element)
            element.tap()
        }
        func text(_ pattern: String) -> XCUIElementQuery {
            app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", pattern))
        }
        func tapText(_ pattern: String) throws {
            let candidates = text(pattern)
            try wait(candidates.firstMatch)
            guard let element = candidates.allElementsBoundByIndex.first(where: { $0.isHittable }) else {
                XCTFail("Screenshot action is not hittable: \(pattern)")
                throw CaptureFailure.missingElement
            }
            element.tap()
        }
        func screenshot(_ name: String) {
            XCTAssertFalse(app.alerts.firstMatch.exists, "Blocking app alert before \(name)")
            XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists,
                           "Blocking system alert before \(name)")
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "native-\(locale)-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func launch(appearance: String) throws {
            app.launchArguments = [
                "-screenshotMode", "YES", "-screenshotAppearance", appearance,
                "-AppleLanguages", "(\(locale))", "-AppleLocale", german ? "de_DE" : "en_US"
            ]
            app.launch()
            try wait(identifier("schedule-screen"))
        }
        func schedule() throws {
            try tapText("Thu.*|Do\\..*")
            try tapText("Sun.*|So\\..*")
            app.scrollViews.matching(identifier: "schedule-screen").firstMatch.swipeUp()
        }

        try launch(appearance: "light")
        try schedule()
        screenshot("01-schedule")
        try tapID("calendar")
        try tapID("theatermasks.fill")
        try wait(identifier("artist-194"))
        try wait(identifier("artist-image-loaded-194"), timeout: 30)
        screenshot("02-artists")

        try tapID("map.fill")
        try wait(identifier("festival-map"))
        screenshot("03-locations")

        try tapID("theatermasks.fill")
        try wait(identifier("artist-194"))
        app.swipeDown()
        try tapText("Search|Suchen")
        let search = app.searchFields.firstMatch
        try wait(search)
        search.tap()
        search.typeText("Duo Ruut")
        try tapID("artist-176")
        try wait(identifier("artist-detail-176-theme-ready"))
        try wait(identifier("artist-image-loaded-176"), timeout: 30)
        screenshot("04-artist-detail")

        try tapID("theatermasks.fill")
        try tapText("Clear text|Text löschen")
        text("Close|Schließen").allElementsBoundByIndex.first(where: { $0.isHittable })?.tap()
        try wait(identifier("artist-194"))
        try tapID("person.2.fill")
        let recommendations = text("Friend recommendations|Freundesempfehlungen").firstMatch
        for _ in 0..<8 {
            if recommendations.exists && recommendations.isHittable { break }
            app.swipeUp()
        }
        try tapText("Show more|Mehr anzeigen")
        try wait(recommendations)
        try wait(identifier("artist-image-loaded-175"), timeout: 30)
        screenshot("05-friends")

        try tapID("person.2.fill")
        try tapID("theatermasks.fill")
        try wait(identifier("artist-194"))
        try tapID("globe.europe.africa")
        try wait(identifier("artist-world-map"))
        let loading = text("Loading world map…|Weltkarte wird geladen…").firstMatch
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !loading.exists }, object: nil)
        guard XCTWaiter.wait(for: [ready], timeout: 30) == .completed else {
            XCTFail("World map did not finish loading")
            throw CaptureFailure.missingElement
        }
        screenshot("06-artist-world-map")

        try launch(appearance: "dark")
        try schedule()
        screenshot("07-schedule-dark")
    }

    private enum CaptureFailure: Error { case missingElement }
}
