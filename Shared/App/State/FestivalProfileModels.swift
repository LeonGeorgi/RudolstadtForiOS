import Foundation
import Combine

enum FestivalProfileStoreChange: Hashable {
    case recommendationInputs
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
    static let defaultColorHex = "#D75A3A"
    static let paletteColorHexes = [
        "#D75A3A",
        "#D49A1F",
        "#5E9F42",
        "#23867A",
        "#3D78E0",
        "#6B5AE0",
        "#B54E9B",
        "#8B5A3C"
    ]

    var displayName: String
    var colorHex: String

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

    static func resolvedColorHex(_ rawColorHex: String?) -> String {
        guard let rawColorHex else {
            return defaultColorHex
        }

        let uppercaseHex = rawColorHex.uppercased()
        if paletteColorHexes.contains(uppercaseHex) {
            return uppercaseHex
        }
        return defaultColorHex
    }

    static func ownerBadge(
        rawName: String?,
        rawColorHex: String?
    ) -> FestivalProfileBadge {
        FestivalProfileBadge(
            displayName: normalizedName(rawName) ?? "You",
            colorHex: resolvedColorHex(rawColorHex)
        )
    }

    static func sharedBadge(
        rawName: String?,
        rawColorHex: String?,
        ownerName: String?,
        title: String
    ) -> FestivalProfileBadge {
        FestivalProfileBadge(
            displayName: normalizedName(rawName)
                ?? normalizedName(ownerName)
                ?? normalizedName(title)
                ?? "Friend",
            colorHex: resolvedColorHex(rawColorHex)
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

struct SharedFestivalProfile: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var title: String
    var ownerName: String?
    var badgeName: String?
    var badgeColorHex: String?
    var festivalYear: Int
    var savedEventIDs: [Int]
    var artistPreferences: [FestivalArtistPreference]

    var badge: FestivalProfileBadge {
        .sharedBadge(
            rawName: badgeName,
            rawColorHex: badgeColorHex,
            ownerName: ownerName,
            title: title
        )
    }
}

enum FestivalProfileICloudStatus: Equatable, Sendable {
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
final class FestivalProfileSyncStore: ObservableObject {
    @Published var acceptedFriendProfiles: [SharedFestivalProfile] = []
    @Published var acceptedShareParticipantCount = 0
    @Published var iCloudStatus: FestivalProfileICloudStatus = .checking
    @Published var syncState: FestivalProfileSyncState = .idle
    @Published var shareState: FestivalProfileShareState = .notShared
    @Published var isPreparingShare = false
    @Published var lastSuccessfulRefreshDate: Date?
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

extension FestivalProfileICloudStatus {
    var logDescription: String {
        switch self {
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

struct CachedOwnerFestivalProfile: Codable, Sendable {
    var festivalYear: Int
    var badgeName: String?
    var badgeColorHex: String?
    var savedEventIDs: [Int]
    var artistPreferences: [FestivalArtistPreference]
    var artistNotes: [FestivalArtistNote]
    var shareRecordName: String?
    var shareRecordSystemFieldsData: Data?
    var rootRecordSystemFieldsData: Data?
    var savedEventRecordSystemFieldsByName: [String: Data]
    var artistPreferenceRecordSystemFieldsByName: [String: Data]
    var artistNoteRecordSystemFieldsByName: [String: Data]
}

struct CachedSharedFestivalProfile: Codable, Sendable {
    var id: String
    var title: String
    var ownerName: String?
    var badgeName: String?
    var badgeColorHex: String?
    var festivalYear: Int
    var savedEventIDs: [Int]
    var artistPreferences: [FestivalArtistPreference]
}

struct FestivalProfileCache: Codable, Sendable {
    var currentProfile: CachedOwnerFestivalProfile
    var sharedProfiles: [CachedSharedFestivalProfile]
    var migrationVersion: Int
    var lastSuccessfulRefreshDate: Date?
    var privateStateSerializationData: Data?
    var sharedStateSerializationData: Data?
}

actor FestivalProfileCachePersister {
    private let userDefaults: UserDefaults
    private let cacheKey: String

    init(userDefaults: UserDefaults, cacheKey: String) {
        self.userDefaults = userDefaults
        self.cacheKey = cacheKey
    }

    func persist(_ cache: FestivalProfileCache) {
        guard let encodedCache = try? JSONEncoder().encode(cache) else {
            return
        }
        userDefaults.set(encodedCache, forKey: cacheKey)
    }
}
