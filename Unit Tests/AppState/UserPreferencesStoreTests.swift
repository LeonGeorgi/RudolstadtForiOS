import Foundation
import Testing
@testable import Rudolstadt

@MainActor
struct UserPreferencesStoreTests {
    @Test
    func festivalIdentityDistinguishesSameYearAndMigratesExistingYearSelection() {
        let defaults = TestFixtures.isolatedUserDefaults()
        defaults.set(2024, forKey: "festival/selectedYear/v1")
        let settings = UserSettings(userDefaults: defaults)
        #expect(settings.festivalEdition == .archive2024)
        #expect(FestivalEdition.current.id != FestivalEdition.ludwigsburg2026.id)
        #expect(FestivalEdition(year: 2026) == .current)
        settings.festivalEdition = .ludwigsburg2026
        #expect(UserSettings(userDefaults: defaults).festivalEdition == .ludwigsburg2026)
        #expect(defaults.integer(forKey: "festival/selectedYear/v1") == 2024)
    }

    @Test
    func removedFestivalSelectionFallsBackWithoutDeletingPersonalData() {
        let defaults = TestFixtures.isolatedUserDefaults()
        defaults.set(2024, forKey: "festival/selectedYear/v1")
        defaults.set("removed-festival-2026", forKey: "festival/selectedEdition/v1")
        defaults.set([42], forKey: "2026/savedEvents")
        let before = defaults.dictionaryRepresentation() as NSDictionary
        #expect(UserSettings(userDefaults: defaults).festivalEdition == .current)
        #expect(before == defaults.dictionaryRepresentation() as NSDictionary)
    }

    @Test(arguments: FestivalEdition.availableEditions)
    func festivalEditionDefaultsToCurrentAndPersistsArchiveSelection(edition: FestivalEdition) {
        let defaults = TestFixtures.isolatedUserDefaults()
        let settings = UserSettings(userDefaults: defaults)
        #expect(settings.festivalEdition == .current)

        settings.festivalEdition = edition

        #expect(UserSettings(userDefaults: defaults).festivalEdition == edition)
        settings.festivalEdition = .current
        #expect(UserSettings(userDefaults: defaults).festivalEdition == .current)
    }

    @Test
    func unsupportedFestivalEditionFallsBackWithoutChangingExistingPreferences() {
        let defaults = TestFixtures.isolatedUserDefaults()
        defaults.set(2021, forKey: "festival/selectedYear/v1")
        defaults.set([42], forKey: "2026/readNews")
        let settings = UserSettings(userDefaults: defaults)

        #expect(settings.festivalEdition == .current)
        settings.festivalEdition = .archive2024

        #expect(settings.readNews == [42])
        #expect(defaults.array(forKey: "2026/readNews") as? [Int] == [42])
    }

    @Test
    func screenshotPreferencesStartWithCurrentEdition() {
        let settings = TestFixtures.userSettings()
        settings.festivalEdition = .archive2024

        ScreenshotRuntime.configure(userSettings: settings)

        #expect(settings.festivalEdition == .current)
    }

    @Test
    func writesOnlyToInjectedUserDefaults() {
        let key = "view/schedule/viewtype"
        let standardValue = UserDefaults.standard.object(forKey: key) as? Int
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let settings = UserSettings(userDefaults: userDefaults)
        let newValue = standardValue == 1 ? 0 : 1

        settings.scheduleViewType = newValue

        #expect(userDefaults.integer(forKey: key) == newValue)
        #expect(UserDefaults.standard.object(forKey: key) as? Int == standardValue)
    }

    @Test
    func storesUsingDifferentSuitesDoNotShareState() {
        let first = TestFixtures.userSettings()
        let second = TestFixtures.userSettings()

        first.readNews = [42]

        #expect(first.readNews == [42])
        #expect(second.readNews.isEmpty)
    }

    @Test
    func storesUsingTheSameSuiteSharePersistedState() {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let first = UserSettings(userDefaults: userDefaults)
        let second = UserSettings(userDefaults: userDefaults)

        first.notificationPromptState = .deferred

        #expect(second.notificationPromptState == .deferred)
    }

    @Test
    func persistsArtistGridColumnCount() {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let first = UserSettings(userDefaults: userDefaults)

        #expect(first.artistGridColumnCount == 2)

        first.artistGridColumnCount = 3

        let second = UserSettings(userDefaults: userDefaults)
        #expect(second.artistGridColumnCount == 3)
    }

    @Test
    func artistLayoutReadsExistingPreferencesWithoutCopyingState() {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        userDefaults.set(0, forKey: "view/artist/viewtype/v2")
        userDefaults.set(3, forKey: "view/artist/grid-columns/v1")
        let settings = UserSettings(userDefaults: userDefaults)

        #expect(settings.artistPresentationMode == .list)
        #expect(settings.artistGridDensity == .compact)

        userDefaults.set(1, forKey: "view/artist/viewtype/v2")
        userDefaults.set(2, forKey: "view/artist/grid-columns/v1")

        #expect(settings.artistPresentationMode == .grid)
        #expect(settings.artistGridDensity == .comfortable)
    }

    @Test
    func switchingArtistLayoutPreservesGridDensityInInjectedSuite() {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let settings = UserSettings(userDefaults: userDefaults)
        settings.artistGridDensity = .compact
        settings.artistPresentationMode = .list

        let restoredSettings = UserSettings(userDefaults: userDefaults)
        #expect(restoredSettings.artistPresentationMode == .list)
        #expect(restoredSettings.artistGridDensity == .compact)
        #expect(userDefaults.integer(forKey: "view/artist/viewtype/v2") == 0)
        #expect(userDefaults.integer(forKey: "view/artist/grid-columns/v1") == 3)

        restoredSettings.artistPresentationMode = .grid

        #expect(settings.artistPresentationMode == .grid)
        #expect(settings.artistGridDensity == .compact)
        #expect(TestFixtures.userSettings().artistGridDensity == .comfortable)
    }

    @Test
    func marksMultipleNewsItemsAsReadWithoutDuplicates() {
        let settings = TestFixtures.userSettings()
        settings.readNews = [7]

        settings.markNewsAsRead([
            newsItem(id: 7),
            newsItem(id: 8),
            newsItem(id: 8),
        ])

        #expect(settings.readNews == [7, 8])
    }

    private func newsItem(id: Int) -> NewsItem {
        NewsItem(
            id: id,
            languageCode: "en",
            dateAsString: "",
            timeAsString: "",
            shortDescription: "",
            longDescription: "",
            content: ""
        )
    }
}
