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

    @MainActor func testTimelineHeadersStayAlignedWhenZooming() {
        let app = launch()
        tapText("Do\\..*|Thu.*", in: app)
        tapText("Sa\\..*|Sat.*", in: app)
        func verifyAlignment(_ phase: String, stageNumber: Int = 2, artist: String = "La Vespa") {
            let heading = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", "\(stageNumber), ")).firstMatch
            let concert = app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", artist)).firstMatch
            let info = app.buttons.matching(
                NSPredicate(format: "label == %@", "Endzeiten sind geschätzt")).firstMatch
            require(heading)
            require(concert)
            require(info)
            if stageNumber == 2 {
                XCTAssertTrue(heading.label.contains("Konzertbühne Heinepark"))
            }
            print("HEADER_ALIGNMENT \(phase) header=\(heading.frame) card=\(concert.frame) info=\(info.frame)")
            XCTAssertEqual(heading.frame.midX, concert.frame.midX, accuracy: 1, phase)
            XCTAssertEqual(heading.frame.width, concert.frame.width, accuracy: 1, phase)
            XCTAssertGreaterThan(info.frame.midX, 0, phase)
            XCTAssertLessThan(info.frame.maxX, 60, phase)
        }
        verifyAlignment("standard")
        snapshot("timeline-standard-headers")
        tapID("schedule-zoom-menu", in: app)
        tapText("Details.*", in: app)
        snapshot("timeline-detail-headers")
        verifyAlignment("detail preset")
        let concert = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "La Vespa")).firstMatch
        concert.pinch(withScale: 0.85, velocity: -0.5)
        snapshot("timeline-pinch-headers")
        verifyAlignment("pinch")
        tapID("schedule-zoom-menu", in: app)
        tapText("Standard.*", in: app)
        verifyAlignment("reset")
        app.swipeLeft()
        app.swipeLeft()
        verifyAlignment("scrolled", stageNumber: 19, artist: "Camila Morgenstern")
        tapID("schedule-zoom-menu", in: app)
        tapText("Details.*", in: app)
        app.swipeUp()
        snapshot("timeline-scrolled-detail-headers")
        verifyAlignment("scrolled detail", stageNumber: 18, artist: "Knaute und Konsorten")
    }

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
        require(text("Shared plans and sharing are unavailable.*|Gemeinsame Pläne und Freigaben sind.*", in: app))
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

    @MainActor func testNewsInlineArtistLongPressKeepsArticleOpen() {
        let app = launch()
        tapID("ellipsis", in: app)
        tapText("Neuigkeiten", in: app)
        scrollTo(id("news-1746", in: app), in: app).tap()
        let article = id("news-inline-content", in: app)
        require(article)
        article.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 68, dy: 10))
            .press(forDuration: 1.2)
        XCTAssertEqual(app.state, .runningForeground)
        require(article)
        snapshot("news-inline-artist-long-press")
        tapText("Künstler anzeigen", in: app)
        require(id("artist-detail-208-theme-ready", in: app))
    }

    @MainActor func testScannerFailureCanBeDismissed() throws {
        #if targetEnvironment(simulator)
        let app = launch()
        tapID("person.2.fill", in: app)
        tapText("Freund hinzufügen", in: app)
        tapID("qrcode.viewfinder", in: app)
        let failure = app.alerts.firstMatch
        require(failure)
        snapshot("qr-scanner-unavailable")
        failure.buttons["Fertig"].tap()
        requireAbsent(app.navigationBars["Freundes-QR scannen"])
        require(id("friends-edit-profile", in: app))
        #else
        throw XCTSkip("Requires a simulator without a usable camera")
        #endif
    }

    @MainActor func testPersonalPlanDetailNavigationPreservesTheBackStack() {
        let app = launch()
        tapText("Do[.].*", in: app)
        tapText("So[.].*", in: app)
        tapID("schedule-personal-plan", in: app)
        let plan = app.scrollViews["schedule-personal-plan-screen"]
        require(plan)

        for _ in 0..<2 {
            scrollTo(id("personal-plan-event-219", in: app), in: app).tap()
            require(matchingID("artist-detail-.*-theme-ready|concert-detail-.*", in: app))
            requireAbsent(plan)

            back(in: app)
            require(plan)
            require(id("personal-plan-event-219", in: app))
        }

        back(in: app)
        require(id("schedule-screen", in: app))
        require(id("schedule-personal-plan", in: app))
        requireAbsent(plan)
    }

    @MainActor func testPersonalPlanFinalDesignAndActions() {
        let app = launch()
        tapText("Do\\..*", in: app)
        tapText("So\\..*", in: app)
        tapID("schedule-personal-plan", in: app)
        require(app.scrollViews["schedule-personal-plan-screen"])
        require(id("personal-plan-event-219", in: app))
        XCTAssertFalse(app.staticTexts["Sonntag, 5. Juli"].exists)
        require(text("Freie Zeit", in: app))
        let saved = id("personal-plan-save-219", in: app)
        let route = id("personal-plan-routes-349", in: app)
        require(saved)
        require(route)
        XCTAssertGreaterThanOrEqual(saved.frame.width, 44)
        XCTAssertGreaterThanOrEqual(route.frame.width, 44)
        XCTAssertEqual(saved.frame.midX, route.frame.midX, accuracy: 1)
        snapshot("personal-plan-final-saved")

        saved.tap()
        require(app.alerts.firstMatch)
        app.alerts.firstMatch.buttons["Abbrechen"].tap()
        require(id("personal-plan-event-219", in: app))

        tapText("Filtern", in: app)
        tapID("personal-plan-show-recommendations", in: app)
        require(app.scrollViews["schedule-personal-plan-screen"])
        require(app.descendants(matching: .any).matching(
            NSPredicate(format: "value == %@", "Empfohlenes Konzert")).firstMatch)
        app.scrollViews["schedule-personal-plan-screen"].swipeDown()
        app.scrollViews["schedule-personal-plan-screen"].swipeDown()
        snapshot("personal-plan-final-recommendations")
    }

    @MainActor func testPersonalPlanConflictOnlyMarksTheLaterConcert() {
        let app = launch()
        tapText("Do\\..*", in: app)
        tapText("So\\..*", in: app)
        tapID("list.bullet", in: app)
        let simultaneous = app.buttons.matching(NSPredicate(
            format: "label CONTAINS %@ AND label CONTAINS %@", "AltBadSeer Musi", "16:00"
        )).firstMatch
        scrollTo(simultaneous, in: app).press(forDuration: 1)
        tapText("Speichern", in: app)
        tapID("schedule-personal-plan", in: app)
        require(text(".*Möglicher Zeitkonflikt mit.*", in: app))
        require(id("personal-plan-save-219", in: app))
        require(id("personal-plan-save-251", in: app))
        snapshot("personal-plan-final-conflict")
    }

    @MainActor func testPersonalPlanEnglishDarkWithLargeText() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-screenshotMode", "YES", "-screenshotAppearance", "dark",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"
        ]
        app.launch()
        require(id("schedule-screen", in: app), timeout: 60)
        tapID("schedule-personal-plan", in: app)
        tapText("Sun.*", in: app)
        require(id("personal-plan-event-219", in: app))
        require(text("Free time", in: app))
        XCTAssertFalse(app.staticTexts["Sunday, July 5"].exists)
        require(text("19:52", in: app))
        let saved = id("personal-plan-save-219", in: app)
        require(saved)
        XCTAssertGreaterThanOrEqual(saved.frame.width, 44)
        snapshot("personal-plan-final-english-dark-large-text")
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

final class AccountLayoutTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func openAccount(_ app: XCUIApplication) throws {
        app.launchArguments = ["-screenshotAppearance", "light", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        let friends = app.tabBars.buttons["Freunde"]
        XCTAssertTrue(friends.waitForExistence(timeout: 90))
        let later = app.buttons["Später"]
        if later.waitForExistence(timeout: 5), later.isHittable { later.tap() }
        friends.tap()
    }

    @MainActor private func tap(_ element: XCUIElement, in app: XCUIApplication) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 25))
        for _ in 0..<4 {
            let later = app.buttons["Später"]
            if later.exists && later.isHittable { later.tap() }
            if element.isHittable { element.tap(); return }
            app.swipeUp()
        }
        XCTFail("Element not hittable: \(element.label)")
        throw CaptureError.unavailable
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "account-layout-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let rows: [[String: Any]] = app.descendants(matching: .any).allElementsBoundByIndex
            .filter { $0.isHittable && !$0.label.isEmpty }
            .map { element in
                let frame = element.frame
                return ["label": element.label.hasPrefix("FF1-") ? "<test key>" : element.label,
                        "type": element.elementType.rawValue,
                        "x": frame.minX, "y": frame.minY,
                        "width": frame.width, "height": frame.height]
            }
        if let json = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]) {
            let metrics = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
            metrics.name = "account-metrics-\(name)"
            metrics.lifetime = .keepAlways
            add(metrics)
        }
    }

    @MainActor func testSignedOutLayouts() throws {
        let app = XCUIApplication()
        try openAccount(app)
        XCTAssertTrue(app.buttons["Anonymes Konto erstellen"].waitForExistence(timeout: 20))
        capture(app, "login")
        try tap(app.buttons["Mit E-Mail anmelden"], in: app)
        XCTAssertTrue(app.textFields["E-Mail-Adresse"].waitForExistence(timeout: 10))
        capture(app, "email")
        try tap(app.buttons["Zurück"], in: app)
        try tap(app.buttons["Mit Schlüssel anmelden"], in: app)
        XCTAssertTrue(app.secureTextFields["Geheimer Zugangsschlüssel"].waitForExistence(timeout: 10))
        capture(app, "key-login")
        try tap(app.buttons["Zurück"], in: app)
        app.tabBars.buttons["Freunde"].tap()
        XCTAssertTrue(app.buttons["Anonymes Konto erstellen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Freigabe an Freunde"].exists)
        capture(app, "friends-login")
    }

    @MainActor func testAnonymousAccountLayoutsAndCleanup() throws {
        let app = XCUIApplication()
        try openAccount(app)
        var keyImage: XCUIScreenshot?
        if app.buttons["Anonymes Konto erstellen"].exists {
            try tap(app.buttons["Anonymes Konto erstellen"], in: app)
            let secured = app.buttons["Ich habe den Schlüssel gesichert"].firstMatch
            XCTAssertTrue(secured.waitForExistence(timeout: 60))
            keyImage = XCUIScreen.main.screenshot()
            try tap(secured, in: app)
        }
        let profileMenu = app.buttons["friends-profile"]
        XCTAssertTrue(profileMenu.waitForExistence(timeout: 30))
        let sync = app.navigationBars.buttons.matching(
            NSPredicate(format: "identifier == %@ AND enabled == true", "profile-sync")
        ).firstMatch
        try tap(sync, in: app)
        XCTAssertTrue(profileMenu.exists)
        XCTAssertFalse(app.staticTexts["Dein Profil ist synchronisiert."].exists)
        try tap(profileMenu, in: app)
        capture(app, "anonymous-account-menu")
        try tap(app.buttons["Zugangsschlüssel"], in: app)
        XCTAssertTrue(app.buttons["Schlüssel ersetzen"].waitForExistence(timeout: 30))
        capture(app, "key-management")
        try tap(app.buttons["Schlüssel ersetzen"], in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
        capture(app, "key-replacement-confirmation")
        if keyImage == nil {
            app.alerts.buttons["Schlüssel ersetzen"].tap()
            let secured = app.buttons["Ich habe den Schlüssel gesichert"].firstMatch
            XCTAssertTrue(secured.waitForExistence(timeout: 60))
            keyImage = XCUIScreen.main.screenshot()
            try tap(secured, in: app)
        } else { app.alerts.buttons["Abbrechen"].tap() }
        app.navigationBars.buttons.firstMatch.tap()
        try tap(profileMenu, in: app)
        try tap(app.buttons["Konto löschen …"], in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
        capture(app, "deletion-confirmation")
        app.alerts.buttons["Konto löschen"].tap()
        XCTAssertTrue(app.staticTexts["Das Konto und seine Cloud-Daten wurden gelöscht. Dein Profil bleibt auf diesem Gerät erhalten."].waitForExistence(timeout: 60))
        if let keyImage {
            let attachment = XCTAttachment(screenshot: keyImage)
            attachment.name = "account-layout-revoked-test-key"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        capture(app, "deleted-account-login")
    }

    private enum CaptureError: Error { case unavailable }
}

final class FriendsLayoutTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 1)
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "friends-layout-\(name)"
        image.lifetime = .keepAlways
        add(image)
        let metrics = XCTAttachment(string: app.navigationBars.firstMatch.debugDescription)
        metrics.name = "friends-metrics-\(name)"
        metrics.lifetime = .keepAlways
        add(metrics)
    }

    @MainActor private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 30))
        XCTAssertTrue(element.isHittable, "Expected a visible control: \(element.label)")
        element.tap()
    }

    @MainActor private func openAllFriends(in app: XCUIApplication) {
        let allFriends = app.buttons["friends-all"]
        XCTAssertTrue(allFriends.waitForExistence(timeout: 45))
        for _ in 0..<3 where !allFriends.isHittable {
            app.swipeUp()
        }
        tap(allFriends)
        XCTAssertTrue(app.navigationBars["Alle Freunde"].waitForExistence(timeout: 10))
    }

    @MainActor func testConnectedFriendLayouts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        let friends = app.tabBars.buttons["Freunde"]
        XCTAssertTrue(friends.waitForExistence(timeout: 90))
        let later = app.buttons["Später"]
        if later.waitForExistence(timeout: 20), later.isHittable { later.tap() }
        tap(friends)
        if app.buttons["Mit Schlüssel anmelden"].waitForExistence(timeout: 5) {
            tap(app.buttons["Mit Schlüssel anmelden"])
            let key = try XCTUnwrap(ProcessInfo.processInfo.environment["FRIENDS_TEST_KEY"])
            let input = app.secureTextFields["Geheimer Zugangsschlüssel"]
            tap(input)
            input.typeText(key)
            tap(app.buttons["Mit Schlüssel anmelden"])
        }
        let add = app.buttons["friends-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 60))
        XCTAssertTrue(app.buttons["friends-all"].waitForExistence(timeout: 45))
        Thread.sleep(forTimeInterval: 5)
        capture(app, "full")
        tap(add)
        capture(app, "plus")
        tap(app.buttons["Einladung erstellen"])
        XCTAssertTrue(app.buttons["Einladung teilen"].waitForExistence(timeout: 30))
        capture(app, "qr")
        tap(app.navigationBars.buttons.firstMatch)
        XCTAssertTrue(app.navigationBars.buttons["profile-sync"].exists)
        tap(app.buttons["friends-profile"])
        let editProfile = app.buttons["Profil bearbeiten"]
        XCTAssertTrue(editProfile.waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["Name"].exists)
        capture(app, "profile")
        tap(editProfile)
        let profileEditor = app.navigationBars["Profil bearbeiten"]
        XCTAssertTrue(profileEditor.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["Name"].exists)
        XCTAssertTrue(profileEditor.buttons["Speichern"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["friends-hue-wheel"].waitForExistence(timeout: 10))
        capture(app, "color")
        tap(profileEditor.buttons["Abbrechen"])
        openAllFriends(in: app)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Test · Ben")).firstMatch
        tap(row)
        XCTAssertTrue(app.navigationBars["Test · Ben"].waitForExistence(timeout: 15))
        app.swipeDown()
        capture(app, "detail")
        tap(app.navigationBars.buttons.firstMatch)
        tap(app.navigationBars["Alle Freunde"].buttons.firstMatch)
        let recommendations = app.buttons["friends-recommendations"]
        for _ in 0..<3 where !recommendations.isHittable {
            app.swipeDown()
            Thread.sleep(forTimeInterval: 0.5)
        }
        tap(recommendations)
        XCTAssertTrue(app.navigationBars["Freundesempfehlungen"].waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 4)
        capture(app, "recommendations")
        tap(app.navigationBars.buttons.firstMatch)
        tap(add)
        tap(app.buttons["Einladung erstellen"])
        XCTAssertTrue(app.buttons["Einladung teilen"].waitForExistence(timeout: 30))
        tap(app.navigationBars.buttons.firstMatch)
    }
    @MainActor func testFriendDetailLayout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        tap(app.tabBars.buttons["Freunde"])
        openAllFriends(in: app)
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Test · Ben")).firstMatch
        tap(row)
        XCTAssertTrue(app.navigationBars["Test · Ben"].waitForExistence(timeout: 15))
        app.swipeDown()
        capture(app, "detail")
    }

    @MainActor func testHomeFriendLayouts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        let friends = app.tabBars.buttons["Freunde"]
        XCTAssertTrue(friends.waitForExistence(timeout: 90))
        tap(friends)
        let add = app.buttons["friends-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 45))
        Thread.sleep(forTimeInterval: 5)
        capture(app, "full")
        tap(add)
        capture(app, "plus")
        tap(app.buttons["Einladung erstellen"])
        XCTAssertTrue(app.buttons["Einladung teilen"].waitForExistence(timeout: 30))
        tap(app.navigationBars.buttons.firstMatch)
        XCTAssertTrue(app.navigationBars.buttons["profile-sync"].exists)
        tap(app.buttons["friends-profile"])
        XCTAssertTrue(app.buttons["Profil bearbeiten"].waitForExistence(timeout: 10))
        capture(app, "profile")
    }

}
