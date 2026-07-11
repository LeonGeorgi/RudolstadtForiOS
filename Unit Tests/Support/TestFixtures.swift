import Foundation
@testable import Rudolstadt

enum TestFixtures {
    static func festivalData(events: [Event]) -> FestivalData {
        FestivalData(
            artists: unique(events.map(\.artist), by: \.id),
            areas: unique(events.map(\.stage.area), by: \.id),
            stages: unique(events.map(\.stage), by: \.id),
            events: events
        )
    }

    @MainActor
    static func festivalProfileStore() -> FestivalProfileStore {
        FestivalProfileStore(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            cloudKitEnabled: false
        )
    }

    static func sharedFestivalProfile(
        id: String = "friend-profile",
        savedEventIDs: [Int] = [],
        artistPreferences: [FestivalArtistPreference] = []
    ) -> SharedFestivalProfile {
        SharedFestivalProfile(
            id: id,
            title: "Friend Profile",
            ownerName: "Friend",
            badgeName: nil,
            badgeColorHex: nil,
            festivalYear: DataStore.year,
            savedEventIDs: savedEventIDs,
            artistPreferences: artistPreferences
        )
    }

    static func artist(id: Int, name: String? = nil) -> Artist {
        Artist(
            id: id,
            hiddenFromArtistList: false,
            artistType: .stage,
            someNumber: 0,
            name: name ?? "Artist \(id)",
            countries: "Germany",
            countryCodes: ["DEU"],
            url: nil,
            facebookID: nil,
            youtubeID: nil,
            instagram: nil,
            descriptionGerman: nil,
            descriptionEnglish: nil,
            thumbImageUrlString: "https://example.com/thumb.jpg",
            fullImageUrlString: "https://example.com/full.jpg",
            ai: nil
        )
    }

    static func stage(id: Int, stageNumber: Int? = nil) -> Stage {
        Stage(
            id: id,
            germanName: "Stage \(id)",
            englishName: "Stage \(id)",
            germanDescription: nil,
            englishDescription: nil,
            stageNumber: stageNumber,
            latitude: 50.0 + Double(id) * 0.001,
            longitude: 11.0 + Double(id) * 0.001,
            area: .example,
            stageType: .festivalTicket
        )
    }

    static func event(
        id: Int,
        dayInJuly: Int,
        timeAsString: String,
        stage: Stage,
        artist: Artist,
        tag: Tag? = nil
    ) -> Event {
        Event(
            id: id,
            dayInJuly: dayInJuly,
            timeAsString: timeAsString,
            stage: stage,
            artist: artist,
            tag: tag
        )
    }

    static func date(dayInJuly: Int, hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(
                year: DataStore.year,
                month: 7,
                day: dayInJuly,
                hour: hour,
                minute: minute
            )
        )!
    }

    static func apiNewsItem(id: Int, language: String) -> APINewsItem {
        APINewsItem(
            id: id,
            title: "Title \(id)",
            language: language,
            teaser: "Teaser \(id)",
            text: "Text \(id)",
            time: APITime(
                date: "2025-07-06 14:00:00.000000",
                timezoneType: 3,
                timezone: "Europe/Berlin"
            )
        )
    }

    static func newsItem(id: Int, languageCode: String) -> NewsItem {
        NewsItem(
            id: id,
            languageCode: languageCode,
            dateAsString: "06.07.2025",
            timeAsString: "14:00",
            shortDescription: "Short \(id)",
            longDescription: "Long \(id)",
            content: "Content \(id)"
        )
    }

    private static func unique<T, Key: Hashable>(
        _ values: [T],
        by keyPath: KeyPath<T, Key>
    ) -> [T] {
        var seen = Set<Key>()
        return values.filter { value in
            seen.insert(value[keyPath: keyPath]).inserted
        }
    }
}
