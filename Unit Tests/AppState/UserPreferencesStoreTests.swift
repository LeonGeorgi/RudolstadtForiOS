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
