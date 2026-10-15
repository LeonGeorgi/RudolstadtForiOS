import Foundation
import Testing
@testable import Rudolstadt

@MainActor
struct UserPreferencesStoreTests {
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
