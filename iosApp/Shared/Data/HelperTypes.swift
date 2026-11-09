import RudolstadtCore
import Foundation
import OSLog
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

private struct FestivalEditionEnvironmentKey: EnvironmentKey {
    static let defaultValue = FestivalEdition.current
}

private struct FestivalDataEnvironmentKey: EnvironmentKey {
    static let defaultValue: FestivalData? = nil
}

extension EnvironmentValues {
    var festivalEdition: FestivalEdition {
        get { self[FestivalEditionEnvironmentKey.self] }
        set { self[FestivalEditionEnvironmentKey.self] = newValue }
    }

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
    let badgeHue: Double
    let savedEventIDs: [Int]
    let artistPreferences: [FestivalArtistPreference]
    let artistNotes: [FestivalArtistNote]
    let friendProfiles: [CachedSharedFestivalProfile]
}

@MainActor
enum PreviewMockData {
    private static let featuredArtistID = 176

    static let festivalData: FestivalData = {
        guard let apiData = loadAPIFestivalData() else {
            return fallbackFestivalData
        }

        do {
            let raw = try convertFestivalSourceToEntities(
                apiData: apiData,
                extraData: loadExtraDataFromResource(fileName: "extra_data")
                    ?? ExtraDataCollection.empty()
            )
            let adapter = FestivalRegistry.rudolstadt(year: raw.festivalYear,
                source: RudolstadtFestivalDataProvider(cache: DataStore.makeDefaultDataLoader()), archive: false)
            return try adapter.prepare(raw, source: .preview)
        } catch {
            AppLog.data.error("Invalid festival preview: \(error.localizedDescription)")
            return fallbackFestivalData
        }
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
        do { try dataStore.install(festivalData) }
        catch { preconditionFailure("Invalid preview program: \(error)") }
        dataStore.recommendationStore.update(
            RecommendationSnapshot(
                recommendedEventIds: [],
                estimatedEventDurations: estimatedEventDurations
            ),
            generatedAt: ScreenshotRuntime.referenceDate,
            savedEventIDs: profile.savedEvents
        )

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
            cloudSyncEnabled: false
        )
        let seed = loadProfileSeed()

        profile.updateBadge(
            name: seed?.badgeName ?? "Preview",
            hue: seed?.badgeHue ?? FestivalProfileBadge.defaultHue
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

        profile.friendProfilesStore.viewModel.restore(
            profiles: (seed?.friendProfiles ?? []).map(FestivalProfileStore.makeSharedProfile))
        return profile
    }

    private static func artist(withID id: Int) -> Artist? {
        festivalData.artists.first { $0.id == id }
    }

    private static func event(withID id: Int) -> Event? {
        festivalData.events.first { $0.id == id }
    }

    private static func loadAPIFestivalData() -> RudolstadtPayload? {
        func records(_ endpoint: String) throws -> RudolstadtRecords {
            try KotlinCore.bridge.rudolstadtRecords(endpoint: endpoint,
                sourceJSON: String(contentsOf: festivalDataURL(endpoint + ".json"), encoding: .utf8))
        }
        return try? KotlinCore.bridge.assembleRudolstadtPayload(
            areas: records("areas"), artists: records("artists"), events: records("events"),
            stages: records("stages"), tags: records("tags"))
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
            .environmentObject(environment.profile.friendProfilesStore)
            .environmentObject(environment.dataStore.newsStore)
            .environmentObject(environment.dataStore.recommendationStore)
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


extension FestivalData {
    var programDetails: ProgramDetailCatalog {
        detailCatalog ?? makeDetailCatalog()
    }

    func makeDetailCatalog() -> ProgramDetailCatalog {
        let similarities: ProgramSimilarityCatalog?
        if let source = artistSimilarities, source.festivalYear != festivalYear {
            similarities = nil
        } else if metadata != nil {
            similarities = features.similarities.value as? ProgramSimilarityCatalog
        } else {
            similarities = artistSimilarities?.coreCatalog(for: festivalYear)
        }
        return ProgramDetailCatalog(
            artists: artists, places: stages, events: events, transfer: coreWalkingTransfers,
            similarities: similarities)
    }

    var coreWalkingTransfers: any TransferSource {
        if metadata != nil, let catalog = features.distances.value as? ProgramDistanceCatalog {
            return catalog.walkingSource
        }
        return transitionEvaluator().coreTransfers
    }

    func transitionEvaluator() -> ScheduleTransitionEvaluator {
        let transfer: (@Sendable (FestivalPlaceID, FestivalPlaceID) -> StageTransferEstimate?)?
        if metadata != nil {
            let provider = features.distances.value
            transfer = { source, destination in provider?.walkingTransfer(from: source, to: destination).map(StageTransferEstimate.init) }
        } else { transfer = nil }
        return ScheduleTransitionEvaluator(transferEstimator: StageTransferEstimator(stages: stages, matrix: walkingDistanceMatrix),
            calendar: metadata?.calendar ?? FestivalDateUtilities.festivalCalendar, transferProvider: transfer)
    }
}
