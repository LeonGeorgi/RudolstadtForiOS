import Foundation
@testable import Rudolstadt

enum TestFixtures {
    static var festivalCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        return calendar
    }

    static func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "RudolstadtTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create isolated UserDefaults suite")
        }
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    @MainActor
    static func userSettings() -> UserSettings {
        UserSettings(userDefaults: isolatedUserDefaults())
    }

    static func festivalData(events: [Event]) -> FestivalData {
        FestivalData(
            artists: unique(events.map(\.artist), by: \.id),
            areas: unique(events.map(\.stage.area), by: \.id),
            stages: unique(events.map(\.stage), by: \.id),
            events: events
        )
    }

    static func cachedOwnerFestivalProfile(
        festivalYear: Int = DataStore.year,
        savedEventIDs: [Int] = [],
        artistPreferences: [FestivalArtistPreference] = [],
        artistNotes: [FestivalArtistNote] = []
    ) -> CachedOwnerFestivalProfile {
        CachedOwnerFestivalProfile(
            festivalYear: festivalYear,
            badgeName: nil,
            badgeColorHex: FestivalProfileBadge.defaultColorHex,
            savedEventIDs: savedEventIDs,
            artistPreferences: artistPreferences,
            artistNotes: artistNotes,
            shareRecordName: nil,
            shareRecordSystemFieldsData: nil,
            rootRecordSystemFieldsData: nil,
            savedEventRecordSystemFieldsByName: [:],
            artistPreferenceRecordSystemFieldsByName: [:],
            artistNoteRecordSystemFieldsByName: [:]
        )
    }

    static func festivalProfileCache(
        currentProfile: CachedOwnerFestivalProfile? = nil
    ) -> FestivalProfileCache {
        FestivalProfileCache(
            currentProfile: currentProfile ?? cachedOwnerFestivalProfile(),
            sharedProfiles: [],
            migrationVersion: FestivalProfileStore.Constants.migrationVersion,
            lastSuccessfulRefreshDate: nil,
            privateStateSerializationData: nil,
            sharedStateSerializationData: nil
        )
    }

    @MainActor
    static func festivalProfileStore() -> FestivalProfileStore {
        FestivalProfileStore(
            userDefaults: isolatedUserDefaults(),
            cloudKitEnabled: false,
            now: { date(dayInJuly: 3, hour: 12, minute: 0) }
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

    static func artist(
        id: Int,
        name: String? = nil,
        descriptionGerman: String? = nil,
        descriptionEnglish: String? = nil
    ) -> Artist {
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
            descriptionGerman: descriptionGerman,
            descriptionEnglish: descriptionEnglish,
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

    static func date(
        dayInJuly: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar = festivalCalendar
    ) -> Date {
        guard let date = calendar.date(
            from: DateComponents(
                year: DataStore.year,
                month: 7,
                day: dayInJuly,
                hour: hour,
                minute: minute
            )
        ) else {
            preconditionFailure("Could not create festival test date")
        }
        return date
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

    static func apiFestivalData(artistID: Int? = nil) -> APIRudolstadtData {
        APIRudolstadtData(
            areas: [],
            artists: artistID.map { id in
                [APIArtist(
                    id: id,
                    category: .concert,
                    hideArtist: false,
                    name: "API Artist \(id)",
                    country: "Germany",
                    website: nil,
                    video: nil,
                    facebook: nil,
                    instagram: nil,
                    soundcloud: nil,
                    imgThumb: "",
                    imgFull: "",
                    descriptionDE: "",
                    descriptionEN: ""
                )]
            } ?? [],
            events: [],
            stages: [],
            tags: []
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
