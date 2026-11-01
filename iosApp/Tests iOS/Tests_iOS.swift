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

final class NavigationRegressionTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testFestivalSelectionKeepsEveryTabUsable() {
        let app = launch(seeded: false)
        selectFestival("Rudolstadt 2026", in: app)
        selectFestival("Straßenmusikfestival Ludwigsburg 2026", in: app)
        tapID("ellipsis", in: app)
        require(text("Settings|Einstellungen", in: app))
        tapID("theatermasks.fill", in: app)
        require(matchingID("artist-.*", in: app))
        tapID("map.fill", in: app)
        require(text("Approximate positions derived from the site plan\\.|Ungefähre Positionen aus dem Lageplan.*", in: app))
        tapID("person.2.fill", in: app)
        require(text("Shared plans and iCloud sharing are unavailable.*|Gemeinsame Pläne und iCloud-Freigaben sind.*", in: app))
        tapID("calendar", in: app)
        require(id("schedule-screen", in: app))
        selectFestival("Rudolstadt 2024", in: app)
        tapID("ellipsis", in: app)
        require(text("Settings|Einstellungen", in: app))
        selectFestival("Rudolstadt 2026", in: app)
        tapID("ellipsis", in: app)
        require(text("Settings|Einstellungen", in: app))
    }

    @MainActor func testFriendRatingsWithOneAndMultipleFriends() {
        let app = launch()
        tapID("theatermasks.fill", in: app)
        tapText("Darstellung|View", in: app)
        tapText("Liste|List", in: app)
        scrollTo(id("artist-176", in: app), in: app).tap()
        require(id("artist-detail-176-theme-ready", in: app))
        for attempt in 0..<2 {
            tapID("artist-friend-ratings", in: app)
            require(id("artist-friend-ratings-overview", in: app))
            require(text("Aya, 2 Herzen|Aya, 2 hearts", in: app))
            XCTAssertFalse(text("Mika,.*", in: app).exists)
            if attempt == 0 { snapshot("friend-ratings-single") }
            tapText("Close ratings|Bewertungen schließen", in: app)
            requireAbsent(id("artist-friend-ratings-overview", in: app))
            require(id("artist-friend-ratings", in: app))
        }
        back(in: app)
        scrollTo(id("artist-223", in: app), in: app, upwards: false).tap()
        require(id("artist-detail-223-theme-ready", in: app))
        tapID("artist-friend-ratings", in: app)
        require(id("artist-friend-ratings-overview", in: app))
        require(text("Aya, 2 Herzen|Aya, 2 hearts", in: app))
        require(text("Mika, 3 Herzen|Mika, 3 hearts", in: app))
        snapshot("friend-ratings-multiple")
        tapText("Close ratings|Bewertungen schließen", in: app)
        requireAbsent(id("artist-friend-ratings-overview", in: app))
        require(id("artist-friend-ratings", in: app))
    }

    @MainActor func testMapSheetsAndClassicPlaceNavigation() {
        let app = launch()
        tapID("map.fill", in: app)
        require(id("festival-map", in: app))
        tapID("festival-place-35", in: app)
        if !id("stage-detail-35", in: app).waitForExistence(timeout: 3) {
            tapID("festival-place-35", in: app)
        }
        require(id("stage-detail-35", in: app))
        XCTAssertFalse(id("stage-map-preview", in: app).exists)
        snapshot("places-tab-sheet")
        tapText("Fri|Fr\\.?", in: app)
        scrollTo(id("stage-event-45", in: app), in: app).tap()
        require(matchingID("artist-detail-.*-theme-ready", in: app))
        requireAbsent(id("stage-detail-35", in: app))
        scrollTo(text("Bauernhäuser", in: app), in: app).tap()
        require(id("stage-detail-35", in: app))
        require(id("stage-map-preview", in: app))
        snapshot("classic-place-detail")
        scrollTo(text("Sat|Sa\\.?", in: app), in: app).tap()
        scrollTo(matchingID("stage-event-.*", in: app), in: app).tap()
        require(matchingID("artist-detail-.*-theme-ready", in: app))
        requireAbsent(id("stage-detail-35", in: app))
        back(in: app)
        require(id("stage-detail-35", in: app))
        back(in: app)
        require(matchingID("artist-detail-.*-theme-ready", in: app))
        requireAbsent(id("stage-detail-35", in: app))
        back(in: app)
        require(id("stage-detail-35", in: app))
        XCTAssertFalse(id("stage-map-preview", in: app).exists)
        tapText("Close|Schließen", in: app)
        requireAbsent(id("stage-detail-35", in: app))
        require(id("festival-map", in: app))
    }

    @MainActor private func launch(seeded: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        if seeded { app.launchArguments += ["-screenshotMode", "YES", "-screenshotAppearance", "light"] }
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        require(id("schedule-screen", in: app), timeout: 60)
        return app
    }

    @MainActor private func id(_ name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: name).firstMatch
    }

    @MainActor private func matchingID(_ pattern: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier MATCHES %@", pattern)).firstMatch
    }

    @MainActor private func text(_ pattern: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label MATCHES %@", pattern)).firstMatch
    }

    @MainActor private func require(_ element: XCUIElement, timeout: TimeInterval = 20) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout: timeout), "Missing regression element: \(element)")
    }

    @MainActor private func requireAbsent(_ element: XCUIElement) {
        let absent = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !element.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [absent], timeout: 10), .completed, "Unexpected regression element: \(element)")
    }

    @MainActor private func tapID(_ name: String, in app: XCUIApplication) {
        let element = id(name, in: app)
        require(element)
        element.tap()
    }

    @MainActor private func tapText(_ pattern: String, in app: XCUIApplication) {
        let element = text(pattern, in: app)
        require(element)
        element.tap()
    }

    @MainActor private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, upwards: Bool = true) -> XCUIElement {
        for _ in 0..<30 {
            if element.exists && element.isHittable { return element }
            if upwards { app.swipeUp() } else { app.swipeDown() }
        }
        XCTFail("Regression scroll target not hittable: \(element)")
        return element
    }

    @MainActor private func selectFestival(_ name: String, in app: XCUIApplication) {
        tapID("ellipsis", in: app)
        if !id("festival-year-picker", in: app).exists {
            tapText("Settings|Einstellungen", in: app)
        }
        let picker = id("festival-year-picker", in: app)
        require(picker)
        picker.staticTexts.firstMatch.tap()
        let option = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
        require(option)
        option.tap()
        if !id("schedule-screen", in: app).waitForExistence(timeout: 3) {
            // Selecting the already active edition keeps the settings screen open.
            let picker = id("festival-year-picker", in: app)
            require(picker)
            XCTAssertTrue(picker.label.hasSuffix(name), "Festival selection did not change to \(name)")
            tapID("calendar", in: app)
        }
        require(id("schedule-screen", in: app), timeout: 60)
    }

    @MainActor private func back(in app: XCUIApplication) {
        let button = app.buttons.matching(identifier: "BackButton").firstMatch
        if button.exists { button.tap() } else { app.navigationBars.buttons.firstMatch.tap() }
    }

    @MainActor private func snapshot(_ name: String) {
        // Custom keyframes (<0.8 s) expose their final labels before the visual reveal finishes.
        Thread.sleep(forTimeInterval: 1)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "regression-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
