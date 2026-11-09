import Foundation
import Combine
import RudolstadtCore

enum FestivalProfileStoreChange: Hashable {
    case recommendationInputs
    case watchSnapshotInputs
}

struct FestivalArtistPreference: Codable, Hashable, Identifiable, Sendable {
    let artistID: Int
    var rating: Int
    var iconName: String?

    var id: Int {
        artistID
    }
}

struct FestivalProfileBadge: Hashable, Sendable {
    static let defaultHue = ProfileReducer.shared.resolvedHue(value: nil)

    var displayName: String
    var hue: Double

    var initials: String {
        Self.initials(from: displayName)
    }

    static func normalizedName(_ rawName: String?) -> String? {
        guard let rawName else {
            return nil
        }
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }
        return String(trimmedName.prefix(40))
    }

    static func resolvedHue(_ rawHue: Double?) -> Double {
        ProfileReducer.shared.resolvedHue(value: rawHue.map { KotlinDouble(value: $0) })
    }

    static func ownerBadge(
        rawName: String?,
        rawHue: Double?
    ) -> FestivalProfileBadge {
        FestivalProfileBadge(
            displayName: normalizedName(rawName) ?? "You",
            hue: resolvedHue(rawHue)
        )
    }

    static func sharedBadge(
        rawName: String?,
        rawHue: Double?,
        ownerName: String?,
        title: String
    ) -> FestivalProfileBadge {
        FestivalProfileBadge(
            displayName: normalizedName(rawName)
                ?? normalizedName(ownerName)
                ?? normalizedName(title)
                ?? "Friend",
            hue: resolvedHue(rawHue)
        )
    }

    static func initials(from displayName: String) -> String {
        let components = displayName
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .filter { !$0.isEmpty }

        if components.count >= 2 {
            return String(components.prefix(2).compactMap { component in
                    component.first.map { Character(String($0).uppercased()) }
                })
        }

        let compactCharacters = displayName.filter { $0.isLetter || $0.isNumber }
        if compactCharacters.count >= 2 {
            return String(compactCharacters.prefix(2)).uppercased()
        }

        if let firstCharacter = compactCharacters.first {
            return String(firstCharacter).uppercased()
        }

        return "?"
    }
}

typealias SharedFestivalProfile = SharedProfile

extension SharedProfile: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public var id: String { profileID }
    var badge: FestivalProfileBadge {
        .sharedBadge(rawName: badgeName, rawHue: badgeHue, ownerName: ownerName, title: title)
    }
    convenience init(
        id: String, title: String, ownerName: String?, badgeName: String?,
        badgeHue: Double?, festivalYear: Int, savedEventIDs: [Int],
        artistPreferences: [FestivalArtistPreference]
    ) {
        self.init(
            profileID: id, title: title, ownerName: ownerName, badgeName: badgeName,
            badgeHue: FestivalProfileBadge.resolvedHue(badgeHue), year: Int32(festivalYear), saved: KotlinCore.ids(savedEventIDs),
            preferences: artistPreferences.map(\.core))
    }
}

enum FestivalProfileAccountStatus: Equatable, Sendable {
    case local
    case checking
    case available
    case unavailable(String)
}

enum FestivalProfileSyncState: Equatable, Sendable {
    case idle
    case syncing
    case error(String)
}

enum FestivalProfileShareState: Equatable, Sendable {
    case notShared
    case shared
}

@MainActor
final class FestivalProfileSyncStore: KotlinStateStore<SyncState> {
    let viewModel: SyncViewModel
    var acceptedShareParticipantCount: Int {
        get { Int(viewModel.current.participantCount) }
        set {
            viewModel.sharing(
                shared: viewModel.current.shared, preparing: viewModel.current.preparingShare,
                participants: Int32(newValue))
        }
    }
    var accountStatus: FestivalProfileAccountStatus {
        get {
            switch state.account {
            case "local": return .local
            case "available": return .available
            case "unavailable": return .unavailable(state.accountReason ?? "")
            default: return .checking
            }
        }
        set {
            switch newValue {
            case .local: viewModel.account(status: "local", reason: nil)
            case .checking: viewModel.account(status: "checking", reason: nil)
            case .available: viewModel.account(status: "available", reason: nil)
            case .unavailable(let reason): viewModel.account(status: "unavailable", reason: reason)
            }
        }
    }
    var syncState: FestivalProfileSyncState {
        get {
            switch viewModel.current.phase {
            case "syncing": return .syncing
            case "error": return .error(viewModel.current.message ?? "")
            default: return .idle
            }
        }
        set {
            switch newValue {
            case .idle: viewModel.assign(phase: "idle", message: nil)
            case .syncing: viewModel.assign(phase: "syncing", message: nil)
            case .error(let message): viewModel.assign(phase: "error", message: message)
            }
        }
    }
    var shareState: FestivalProfileShareState {
        get { viewModel.current.shared ? .shared : .notShared }
        set {
            viewModel.sharing(
                shared: newValue == .shared, preparing: viewModel.current.preparingShare,
                participants: viewModel.current.participantCount)
        }
    }
    var isPreparingShare: Bool {
        get { viewModel.current.preparingShare }
        set {
            viewModel.sharing(
                shared: viewModel.current.shared, preparing: newValue,
                participants: viewModel.current.participantCount)
        }
    }
    var lastSuccessfulRefreshDate: Date? {
        get { state.refreshedAt?.date }
        set { viewModel.refreshed(at: newValue.map { KotlinDouble(value: $0.timeIntervalSince1970) }) }
    }
    var lastSyncError: String? { viewModel.current.lastError }
    var shouldWarnBeforeEditing: Bool { viewModel.current.shouldWarn }
    init() {
        let model = SyncViewModel()
        viewModel = model
        super.init(current: { model.current }, observe: model.observe)
    }
    func recordFailure(_ message: String) { viewModel.sync(phase: "error", message: message, pending: false) }
    func confirmSuccess() { viewModel.confirmSuccess() }
}

extension FestivalProfileShareState {
    var logDescription: String {
        switch self {
        case .notShared:
            return "notShared"
        case .shared:
            return "shared"
        }
    }
}

extension FestivalProfileAccountStatus {
    var logDescription: String {
        switch self {
        case .local: return "local"
        case .checking:
            return "checking"
        case .available:
            return "available"
        case .unavailable(let reason):
            return "unavailable (\(reason))"
        }
    }
}

extension FestivalProfileSyncState {
    var logDescription: String {
        switch self {
        case .idle:
            return "idle"
        case .syncing:
            return "syncing"
        case .error(let reason):
            return "error (\(reason))"
        }
    }
}

struct FestivalArtistNote: Codable, Hashable, Identifiable, Sendable {
    let artistID: Int
    var noteText: String

    var id: Int {
        artistID
    }
}

// Legacy system-field bytes below are retained only for decoding/backing up old local caches.
// They are never interpreted or sent to a system cloud service.
struct CachedOwnerFestivalProfile: Codable, Equatable, Sendable {
    var festivalYear: Int
    var badgeName: String?
    var badgeHue: Double?
    var savedEventIDs: [Int]
    var artistPreferences: [FestivalArtistPreference]
    var artistNotes: [FestivalArtistNote]
    var shareRecordName: String?
    var shareRecordSystemFieldsData: Data?
    var rootRecordSystemFieldsData: Data?
    var savedEventRecordSystemFieldsByName: [String: Data]
    var artistPreferenceRecordSystemFieldsByName: [String: Data]
    var artistNoteRecordSystemFieldsByName: [String: Data]
    // Optional so caches written before change tracking remain decodable.
    var changeVersions: [String: CachedProfileChangeVersion]? = nil
}

struct CachedSharedFestivalProfile: Codable, Equatable, Sendable {
    var id: String
    var title: String
    var ownerName: String?
    var badgeName: String?
    var badgeHue: Double?
    var festivalYear: Int
    var savedEventIDs: [Int]
    var artistPreferences: [FestivalArtistPreference]
}

struct FestivalProfileCache: Codable, Equatable, Sendable {
    var currentProfile: CachedOwnerFestivalProfile
    var sharedProfiles: [CachedSharedFestivalProfile]
    var migrationVersion: Int
    var lastSuccessfulRefreshDate: Date?
    var privateStateSerializationData: Data?
    var sharedStateSerializationData: Data?
    // Retained with the values so old local pending changes remain recoverable.
    var pendingProfileRecords: Set<FestivalProfileSyncRecord>? = nil
}

protocol FestivalProfilePersisting: Sendable {
    func loadCache() -> FestivalProfileCache?
    func loadLegacyOwnerProfile() -> CachedOwnerFestivalProfile
    func persist(_ cache: FestivalProfileCache)
}

final class UserDefaultsFestivalProfilePersistence: FestivalProfilePersisting, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let festivalYear: Int
    private let isReadOnly: Bool
    private let isArchive: Bool
    private let namespace: String?

    init(userDefaults: UserDefaults, festivalYear: Int, isReadOnly: Bool = false, isArchive: Bool = false, namespace: String? = nil) {
        self.userDefaults = userDefaults
        self.festivalYear = festivalYear
        self.isReadOnly = isReadOnly
        self.isArchive = isArchive
        self.namespace = namespace
    }

    private func scopedKey(_ key: String) -> String {
        namespace.map { "festival/\($0)/\(key)" } ?? key
    }

    func loadCache() -> FestivalProfileCache? {
        // Archives may read the old global cache without moving or removing it.
        if !isReadOnly && !isArchive && namespace == nil { migrateLegacyCacheIfNeeded() }
        let cacheKey = scopedKey(FestivalProfileStore.Constants.cacheKey(for: festivalYear))
        if let cache = decodedCache(forKey: cacheKey, expectedFestivalYear: festivalYear) {
            return cache
        }
        guard (isReadOnly || isArchive) && namespace == nil else { return nil }
        return decodedCache(
            forKey: FestivalProfileStore.Constants.legacyCacheKey,
            expectedFestivalYear: festivalYear
        )
    }

    private func migrateLegacyCacheIfNeeded() {
        guard let legacyData = userDefaults.data(
                forKey: FestivalProfileStore.Constants.legacyCacheKey
            ),
            let legacyCache = try? JSONDecoder().decode(
                FestivalProfileCache.self,
                from: legacyData
            )
        else {
            return
        }

        let legacyFestivalYear = legacyCache.currentProfile.festivalYear
        let destinationKey = FestivalProfileStore.Constants.cacheKey(
            for: legacyFestivalYear
        )
        if let destinationData = userDefaults.data(forKey: destinationKey) {
            guard let destinationCache = try? JSONDecoder().decode(
                    FestivalProfileCache.self,
                    from: destinationData
            ), destinationCache.currentProfile.festivalYear == legacyFestivalYear else {
                return
            }
            userDefaults.removeObject(forKey: FestivalProfileStore.Constants.legacyCacheKey)
            return
        }

        userDefaults.set(legacyData, forKey: destinationKey)
        guard userDefaults.data(forKey: destinationKey) == legacyData else {
            return
        }
        userDefaults.removeObject(forKey: FestivalProfileStore.Constants.legacyCacheKey)
    }

    func loadLegacyOwnerProfile() -> CachedOwnerFestivalProfile {
        let savedEventIDs = (
            userDefaults.array(
                forKey: scopedKey(FestivalProfileStore.Constants.legacySavedEventsKey(for: festivalYear))
            ) as? [Int]
                ?? []
        )
            .sorted()
        let ratings = userDefaults.dictionary(
            forKey: scopedKey(FestivalProfileStore.Constants.legacyRatingsKey(for: festivalYear))
            ) as? [String: Int] ?? [:]
        let icons = userDefaults.dictionary(
            forKey: scopedKey(FestivalProfileStore.Constants.legacyArtistIconsKey(for: festivalYear))
            ) as? [String: String] ?? [:]
        let notes = userDefaults.dictionary(
            forKey: scopedKey(FestivalProfileStore.Constants.legacyArtistNotesKey(for: festivalYear))
            ) as? [String: String] ?? [:]

        let preferences = ratings.compactMap { entry -> FestivalArtistPreference? in
            guard let artistID = Int(entry.key) else {
                return nil
            }
            return FestivalArtistPreference(
                artistID: artistID,
                rating: entry.value,
                iconName: icons[entry.key]
            )
        }
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }

        let artistNotes = notes.compactMap { entry -> FestivalArtistNote? in
            guard let artistID = Int(entry.key) else {
                return nil
            }
            return FestivalArtistNote(artistID: artistID, noteText: entry.value)
        }
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }

        return CachedOwnerFestivalProfile(
            festivalYear: festivalYear,
            badgeName: nil,
            badgeHue: FestivalProfileBadge.defaultHue,
            savedEventIDs: savedEventIDs,
            artistPreferences: preferences,
            artistNotes: artistNotes,
            shareRecordName: nil,
            shareRecordSystemFieldsData: nil,
            rootRecordSystemFieldsData: nil,
            savedEventRecordSystemFieldsByName: [:],
            artistPreferenceRecordSystemFieldsByName: [:],
            artistNoteRecordSystemFieldsByName: [:]
        )
    }

    func persist(_ cache: FestivalProfileCache) {
        guard !isReadOnly, cache.currentProfile.festivalYear == festivalYear else {
            return
        }
        guard let encodedCache = try? JSONEncoder().encode(cache) else {
            return
        }
        userDefaults.set(
            encodedCache,
            forKey: scopedKey(FestivalProfileStore.Constants.cacheKey(for: festivalYear))
        )
    }

    private func decodedCache(
        forKey key: String,
        expectedFestivalYear: Int
    ) -> FestivalProfileCache? {
        guard let data = userDefaults.data(forKey: key),
            let cache = try? JSONDecoder().decode(FestivalProfileCache.self, from: data),
            cache.currentProfile.festivalYear == expectedFestivalYear
        else {
            return nil
        }
        return cache
    }
}
