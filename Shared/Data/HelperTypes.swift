import Foundation
import SwiftUI

enum FileLoadingResult<T> {
    case loaded(T)
    case stale(T)
    case notFound
    case unparsable
}

struct EntityHelper<T, S> where S: StringProtocol {
    let filename: String
    let converter: ([S]) -> [T]
}

struct FestivalData {
    let artists: [Artist]
    let areas: [Area]
    let stages: [Stage]
    let events: [Event]
}

private struct FestivalDataEnvironmentKey: EnvironmentKey {
    static let defaultValue: FestivalData? = nil
}

extension EnvironmentValues {
    var festivalData: FestivalData {
        get {
            self[FestivalDataEnvironmentKey.self]
                ?? FestivalData(artists: [], areas: [], stages: [], events: [])
        }
        set {
            self[FestivalDataEnvironmentKey.self] = newValue
        }
    }
}

enum LoadingEntity<T> {
    case loading
    case success(T)
    case failure(FailureReason)

    init(from result: LoadingResult<T>) {
        switch result {
        case .failure(let reason):
            self = .failure(reason)
        case .success(let value):
            self = .success(value)
        }
    }

    func map<R>(mapper: (T) -> R) -> LoadingEntity<R> {
        switch self {
        case .loading:
            return .loading
        case .success(let t):
            return .success(mapper(t))
        case .failure(let failureReason):
            return .failure(failureReason)
        }
    }
}

enum LoadingResult<T> {
    case success(T)
    case failure(FailureReason)
}

enum FailureReason: String {
    case noConnection
    case apiNotResponding
    case festivalServerError
    case couldNotLoadFromFile
}

struct FestivalDataFallbackStatus {
    let source: FestivalDataFallbackSource
    let failure: FestivalDataDownloadFailure
    let checkedAt: Date
}

enum FestivalDataFallbackSource {
    case staleCache
    case bundledBackup
}

struct FestivalDataDownloadFailure {
    let owner: FestivalDataDownloadFailureOwner
    let httpStatusCode: Int?

    init(
        owner: FestivalDataDownloadFailureOwner,
        httpStatusCode: Int? = nil
    ) {
        self.owner = owner
        self.httpStatusCode = httpStatusCode
    }
}

enum FestivalDataDownloadFailureOwner {
    case festivalSide
    case appSide
    case connection
    case unknown
}

enum DownloadResult {
    case success
    case failure(DownloadFailureReason)
}

enum DownloadFailureReason {
    case downloadError
    case unableToSave
}

#if DEBUG
struct PreviewAppEnvironment {
    let settings: UserSettings
    let profile: FestivalProfileStore
    let dataStore: DataStore
    let festivalData: FestivalData
}

private struct PreviewProfileSeed: Decodable {
    let badgeName: String
    let badgeColorHex: String
    let savedEventIDs: [Int]
    let artistPreferences: [FestivalArtistPreference]
    let artistNotes: [FestivalArtistNote]
    let friendProfiles: [SharedFestivalProfile]
}

@MainActor
enum PreviewMockData {
    private static let featuredArtistID = 176

    static let festivalData: FestivalData = {
        guard let apiData = loadAPIFestivalData() else {
            return fallbackFestivalData
        }

        return convertAPIRudolstadtDataToEntities(
            apiData: apiData,
            extraData: loadExtraDataFromResource(fileName: "extra_data")
                ?? ExtraDataCollection.empty()
        )
    }()

    static var featuredArtist: Artist {
        festivalData.artists.first { $0.id == featuredArtistID }
            ?? festivalData.artists.first
            ?? Artist.example
    }

    static var mainStage: Stage {
        festivalData.stages.first { stage in
            festivalData.events.contains { event in
                event.artist.id == featuredArtist.id && event.stage.id == stage.id
            }
        } ?? festivalData.stages.first ?? .example
    }

    static var highlightedArtistEventID: Int? {
        festivalData.events.first { $0.artist.id == featuredArtist.id }?.id
    }

    static var featuredArtistEvent: Event {
        festivalData.events.first { $0.artist.id == featuredArtist.id }
            ?? .example
    }

    static func makeEnvironment(
        suiteName: String = "PreviewMockData"
    ) -> PreviewAppEnvironment {
        let settings = UserSettings()
        let profile = makeProfile(suiteName: suiteName)
        let dataStore = DataStore(
            festivalProfileStore: profile,
            userSettings: settings
        )
        dataStore.festivalData = .success(festivalData)
        dataStore.estimatedEventDurationsByEventID = estimatedEventDurations

        return PreviewAppEnvironment(
            settings: settings,
            profile: profile,
            dataStore: dataStore,
            festivalData: festivalData
        )
    }

    private static var estimatedEventDurations: [Int: Int] {
        Dictionary(
            uniqueKeysWithValues: festivalData.events.map { event in
                (event.id, defaultDuration(for: event))
            }
        )
    }

    private static func defaultDuration(for event: Event) -> Int {
        switch event.artist.artistType {
        case .dance:
            return 75
        case .street:
            return 35
        case .stage:
            return 70
        case .other:
            return 50
        }
    }

    private static func makeProfile(suiteName: String) -> FestivalProfileStore {
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)

        let profile = FestivalProfileStore(
            userDefaults: userDefaults,
            cloudKitEnabled: false
        )
        let seed = loadProfileSeed()

        profile.updateBadge(
            name: seed?.badgeName ?? "Preview",
            colorHex: seed?.badgeColorHex ?? FestivalProfileBadge.defaultColorHex
        )

        for preference in seed?.artistPreferences ?? [] {
            guard let artist = artist(withID: preference.artistID) else {
                continue
            }

            if let iconName = preference.iconName, preference.rating < 0 {
                profile.setArtistIcon(for: artist, icon: iconName)
            } else {
                profile.setArtistRating(for: artist, rating: preference.rating)
            }
        }

        for note in seed?.artistNotes ?? [] {
            profile.setArtistNote(forArtistID: note.artistID, note: note.noteText)
        }

        for eventID in seed?.savedEventIDs ?? [] {
            guard let event = event(withID: eventID) else {
                continue
            }
            profile.toggleSavedEvent(event)
        }

        profile.syncStore.acceptedFriendProfiles = seed?.friendProfiles ?? []
        return profile
    }

    private static func artist(withID id: Int) -> Artist? {
        festivalData.artists.first { $0.id == id }
    }

    private static func event(withID id: Int) -> Event? {
        festivalData.events.first { $0.id == id }
    }

    private static func loadAPIFestivalData() -> APIRudolstadtData? {
        guard
            let areas = loadJSON([APIArea].self, at: festivalDataURL("areas.json")),
            let artists = loadJSON([APIArtist].self, at: festivalDataURL("artists.json")),
            let events = loadJSON([APIEvent].self, at: festivalDataURL("events.json")),
            let stages = loadJSON([APIStage].self, at: festivalDataURL("stages.json")),
            let tags = loadJSON([APITag].self, at: festivalDataURL("tags.json"))
        else {
            return nil
        }

        return APIRudolstadtData(
            areas: areas,
            artists: artists,
            events: events,
            stages: stages,
            tags: tags
        )
    }

    private static func loadProfileSeed() -> PreviewProfileSeed? {
        loadJSON(
            PreviewProfileSeed.self,
            at: previewDataDirectory.appendingPathComponent("profile.json")
        )
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, at url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            assertionFailure("Failed to load preview data at \(url.path): \(error)")
            return nil
        }
    }

    private static func festivalDataURL(_ fileName: String) -> URL {
        previewDataDirectory
            .appendingPathComponent("Festival")
            .appendingPathComponent(fileName)
    }

    private static var previewDataDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PreviewData")
    }

    private static let fallbackFestivalData = FestivalData(
        artists: [.example],
        areas: [.example],
        stages: [.example],
        events: [.example]
    )
}

extension View {
    func previewEnvironment(_ environment: PreviewAppEnvironment) -> some View {
        self
            .environmentObject(environment.dataStore)
            .environmentObject(environment.settings)
            .environmentObject(environment.profile)
            .environmentObject(environment.profile.syncStore)
            .environment(\.festivalData, environment.festivalData)
    }

    @MainActor
    func previewMockEnvironment(
        suiteName: String = "PreviewMockData"
    ) -> some View {
        previewEnvironment(
            PreviewMockData.makeEnvironment(suiteName: suiteName)
        )
    }
}
#endif
