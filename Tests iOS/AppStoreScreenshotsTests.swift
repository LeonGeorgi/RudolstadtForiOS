import XCTest

final class AppStoreScreenshotsTests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMainScreenScreenshot() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-screenshotMode", "YES"]

        if appearanceMode() == "dark" {
            app.launchArguments += ["-uiuserinterfacestyle", "dark"]
        } else {
            app.launchArguments += ["-uiuserinterfacestyle", "light"]
        }

        addUIInterruptionMonitor(withDescription: "System Permissions") { [weak self] alert -> Bool in
            self?.acceptAlertIfNeeded(alert: alert) ?? false
        }

        app.launch()
        acceptSystemAlertIfNeeded(app: app)
        XCUIDevice.shared.orientation = .portrait

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))

        captureScreenshot(app: app, key: "main")

        openScheduleSaturdayAndCapture(app: app)
        openLocationsMapAndCapture(app: app)
        openArtistListAndCapture(app: app)
        openArtistDetailAndCapture(app: app)
        openStageThreeAndCapture(app: app)
        openNewsDetailAndCapture(app: app)
    }

    private func openScheduleSaturdayAndCapture(app: XCUIApplication) {
        tapTab(app: app, labels: ["Schedule", "Zeitplan"])

        let dayPicker = app.segmentedControls.firstMatch
        XCTAssertTrue(dayPicker.waitForExistence(timeout: 20))

        if dayPicker.buttons.count > 1 {
            dayPicker.buttons.element(boundBy: 1).tap()
        }

        captureScreenshot(app: app, key: "schedule_saturday")
    }

    private func openLocationsMapAndCapture(app: XCUIApplication) {
        tapTab(app: app, labels: ["Locations", "Orte"])

        // If currently in list mode, switch back to map mode.
        let mapButton = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Map", "Karte"])
        ).firstMatch
        if mapButton.waitForExistence(timeout: 3) {
            mapButton.tap()
        }

        acceptSystemAlertIfNeeded(app: app)
        waitForMapToRender(app: app)
        captureScreenshot(app: app, key: "locations_map")
    }

    private func openArtistListAndCapture(app: XCUIApplication) {
        tapTab(app: app, labels: ["Artists", "Künstler"])
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))

        captureScreenshot(app: app, key: "artists_list")
    }

    private func openArtistDetailAndCapture(app: XCUIApplication) {
        tapTab(app: app, labels: ["Artists", "Künstler"])

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 15))
        searchField.tap()
        searchField.clearAndType(text: "La Nina")

        let artistCandidates = ["La Nina", "La Ni", "La Niña"]
        let artistCell = firstExistingStaticText(in: app, candidates: artistCandidates, timeout: 15)
        XCTAssertTrue(artistCell.exists, "Could not find artist La Niña in list")
        artistCell.tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))
        captureScreenshot(app: app, key: "artist_la_nina")

        navigateBack(app: app)
    }

    private func openStageThreeAndCapture(app: XCUIApplication) {
        tapTab(app: app, labels: ["Locations", "Orte"])

        let listButton = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["List", "Liste"])
        ).firstMatch
        if listButton.waitForExistence(timeout: 8) {
            listButton.tap()
        }

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 15))
        searchField.tap()
        searchField.clearAndType(text: "3")

        let stageNumberText = app.staticTexts["3"].firstMatch
        XCTAssertTrue(waitAndScrollToElement(app: app, element: stageNumberText, timeout: 15))
        stageNumberText.tap()

        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 15))
        captureScreenshot(app: app, key: "stage_3")

        navigateBack(app: app)
    }

    private func openNewsDetailAndCapture(app: XCUIApplication) {
        tapTab(app: app, labels: ["News", "Neuigkeiten", "News"])

        let item = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Dota Kehr")).firstMatch
        XCTAssertTrue(waitAndScrollToElement(app: app, element: item, timeout: 25), "Could not find news item Dota Kehr")
        item.tap()

        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15))
        captureScreenshot(app: app, key: "news_dota_kehr")

        navigateBack(app: app)
    }

    private func captureScreenshot(app: XCUIApplication, key: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let name = screenshotName(
            key: key,
            deviceName: ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? "simulator",
            localeCode: localeCode(),
            appearance: appearanceMode()
        )

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func acceptSystemAlertIfNeeded(app: XCUIApplication) {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 2) else {
            return
        }

        XCTAssertTrue(acceptAlertIfNeeded(alert: alert), "Could not accept system alert")

        // Trigger interruption handling to complete before continuing.
        app.tap()
    }

    private func acceptAlertIfNeeded(alert: XCUIElement) -> Bool {
        let allowButtonLabels = [
            "Allow",
            "OK",
            "Allow While Using App",
            "Allow Once",
            "Immer erlauben",
            "Beim Verwenden der App erlauben",
            "Einmal erlauben",
            "Erlauben"
        ]

        for label in allowButtonLabels {
            let button = alert.buttons[label]
            if button.exists {
                button.tap()
                return true
            }
        }

        let defaultButton = alert.buttons.matching(
            NSPredicate(format: "userTestingAttributes CONTAINS %@", "default-button")
        ).firstMatch
        if defaultButton.exists {
            defaultButton.tap()
            return true
        }

        return false
    }

    private func waitForMapToRender(app: XCUIApplication) {
        let map = app.otherElements["festival-map"].firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 15), "Map did not appear")

        let stageMarker = app.staticTexts["1"].firstMatch
        _ = waitAndScrollToElement(app: app, element: stageMarker, timeout: 10)

        // Apple Maps tiles can still paint shortly after the view appears.
        sleep(2)
    }

    private func firstExistingStaticText(in app: XCUIApplication, candidates: [String], timeout: TimeInterval) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            for candidate in candidates {
                let exact = app.staticTexts[candidate]
                if exact.exists {
                    return exact
                }

                let contains = app.staticTexts.matching(
                    NSPredicate(format: "label CONTAINS[c] %@", candidate)
                ).firstMatch
                if contains.exists {
                    return contains
                }
            }
            app.swipeUp()
        }

        return app.staticTexts.firstMatch
    }

    private func tapTab(app: XCUIApplication, labels: [String]) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))

        for label in labels {
            let button = tabBar.buttons[label]
            if button.exists {
                button.tap()
                return
            }
        }

        XCTFail("Could not find tab button with labels: \(labels)")
    }

    private func navigateBack(app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.firstMatch
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
        }
    }

    private func waitAndScrollToElement(app: XCUIApplication, element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                return true
            }
            app.swipeUp()
        }
        return element.exists
    }

    private func localeCode() -> String {
        ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_LOCALE"]
            ?? Locale.preferredLanguages.first
            ?? "en"
    }

    private func appearanceMode() -> String {
        ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOT_APPEARANCE"] ?? "light"
    }

    private func screenshotName(
        key: String,
        deviceName: String,
        localeCode: String,
        appearance: String
    ) -> String {
        "\(sanitize(key))_\(sanitize(localeCode))_\(sanitize(appearance))_\(sanitize(deviceName))"
    }

    private func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "_", options: .regularExpression)
    }
}

private extension XCUIElement {
    func clearAndType(text: String) {
        guard let value = self.value as? String else {
            self.typeText(text)
            return
        }

        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}
