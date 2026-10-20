import Foundation
import CryptoKit

struct FestivalProfileChangeVersion: Codable, Equatable, Comparable, Sendable {
    let modifiedAt: Date
    let changeID: String

    init(modifiedAt: Date, changeID: String) {
        // Use a transport-stable precision for persisted and CloudKit dates.
        self.modifiedAt = Date(timeIntervalSince1970:
            (modifiedAt.timeIntervalSince1970 * 1_000).rounded() / 1_000
        )
        self.changeID = changeID
    }

    var isLegacy: Bool { changeID.hasPrefix("legacy:") }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt {
            return lhs.modifiedAt < rhs.modifiedAt
        }
        return lhs.changeID < rhs.changeID
    }
}

enum FestivalProfileRecordValue: Equatable, Sendable {
    case savedEvent(eventID: Int, isSaved: Bool)
    case artistPreference(FestivalArtistPreference)
    case artistNote(FestivalArtistNote)

    var record: FestivalProfileSyncRecord {
        switch self {
        case .savedEvent(let id, _): return .savedEvent(eventID: id)
        case .artistPreference(let preference): return .artistPreference(artistID: preference.artistID)
        case .artistNote(let note): return .artistNote(artistID: note.artistID)
        }
    }

    var isDeleted: Bool {
        switch self {
        case .savedEvent(_, let isSaved): return !isSaved
        case .artistPreference(let preference): return preference.rating == 0
        case .artistNote(let note): return note.noteText.isEmpty
        }
    }

    // Stable ordering for old values with equal or missing historical dates.
    var legacyChangeID: String {
        let content: String
        switch self {
        case .savedEvent(_, let isSaved): content = "event:\(isSaved)"
        case .artistPreference(let preference):
            content = "rating:\(preference.rating):\(preference.iconName ?? "")"
        case .artistNote(let note): content = "note:\(note.noteText)"
        }
        return "legacy:" + SHA256.hash(data: Data(content.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    func applying(to profile: CachedOwnerFestivalProfile) -> CachedOwnerFestivalProfile {
        var profile = profile
        switch self {
        case .savedEvent(let eventID, let isSaved):
            profile.savedEventIDs.removeAll { $0 == eventID }
            if isSaved { profile.savedEventIDs.append(eventID) }
        case .artistPreference(let preference):
            profile.artistPreferences.removeAll { $0.artistID == preference.artistID }
            if !isDeleted { profile.artistPreferences.append(preference) }
        case .artistNote(let note):
            profile.artistNotes.removeAll { $0.artistID == note.artistID }
            if !isDeleted { profile.artistNotes.append(note) }
        }
        return FestivalProfileReducer.normalized(profile)
    }
}

struct FestivalProfileChange: Equatable, Sendable {
    let value: FestivalProfileRecordValue
    let version: FestivalProfileChangeVersion
}

enum FestivalProfileMutation: Equatable, Sendable {
    case toggleSavedEvent(eventID: Int)
    case updateBadge(name: String, colorHex: String)
    case setArtistRating(artistID: Int, rating: Int)
    case setArtistIcon(artistID: Int, iconName: String)
    case setArtistNote(artistID: Int, noteText: String)

    var record: FestivalProfileSyncRecord {
        switch self {
        case .toggleSavedEvent(let id): return .savedEvent(eventID: id)
        case .updateBadge: return .profile
        case .setArtistRating(let id, _), .setArtistIcon(let id, _):
            return .artistPreference(artistID: id)
        case .setArtistNote(let id, _): return .artistNote(artistID: id)
        }
    }
}

enum FestivalProfileReducer {
    static func applying(
        _ mutation: FestivalProfileMutation,
        to profile: CachedOwnerFestivalProfile
    ) -> CachedOwnerFestivalProfile {
        var profile = profile

        switch mutation {
        case .toggleSavedEvent(let eventID):
            var savedEventIDs = Set(profile.savedEventIDs)
            if savedEventIDs.contains(eventID) {
                savedEventIDs.remove(eventID)
            } else {
                savedEventIDs.insert(eventID)
            }
            profile.savedEventIDs = Array(savedEventIDs)

        case .updateBadge(let name, let colorHex):
            profile.badgeName = FestivalProfileBadge.normalizedName(name)
            profile.badgeColorHex = FestivalProfileBadge.resolvedColorHex(colorHex)

        case .setArtistRating(let artistID, let rating):
            var preferences = preferencesByArtistID(profile.artistPreferences)
            if rating == 0 {
                preferences.removeValue(forKey: artistID)
            } else {
                var preference = preferences[artistID] ?? FestivalArtistPreference(
                    artistID: artistID,
                    rating: rating,
                    iconName: nil
                )
                preference.rating = rating
                if rating > 0 {
                    preference.iconName = nil
                }
                preferences[artistID] = preference
            }
            profile.artistPreferences = Array(preferences.values)

        case .setArtistIcon(let artistID, let iconName):
            var preferences = preferencesByArtistID(profile.artistPreferences)
            preferences[artistID] = FestivalArtistPreference(
                artistID: artistID,
                rating: -1,
                iconName: iconName
            )
            profile.artistPreferences = Array(preferences.values)

        case .setArtistNote(let artistID, let noteText):
            let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            var notes = Dictionary(
                uniqueKeysWithValues: profile.artistNotes.map { note in
                    (note.artistID, note)
                }
            )
            if trimmedNote.isEmpty {
                notes.removeValue(forKey: artistID)
            } else {
                notes[artistID] = FestivalArtistNote(
                    artistID: artistID,
                    noteText: trimmedNote
                )
            }
            profile.artistNotes = Array(notes.values)
        }

        return normalized(profile)
    }

    static func normalized(
        _ profile: CachedOwnerFestivalProfile
    ) -> CachedOwnerFestivalProfile {
        var normalizedProfile = profile
        normalizedProfile.badgeName = FestivalProfileBadge.normalizedName(profile.badgeName)
        normalizedProfile.badgeColorHex = FestivalProfileBadge.resolvedColorHex(
            profile.badgeColorHex
        )
        normalizedProfile.savedEventIDs = Array(Set(profile.savedEventIDs)).sorted()
        normalizedProfile.artistPreferences = Array(
            preferencesByArtistID(profile.artistPreferences).values
        )
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }
        normalizedProfile.artistNotes = Array(
            Dictionary(
                uniqueKeysWithValues: profile.artistNotes.map { note in
                    (note.artistID, note)
                }
            )
            .values
        )
        .sorted { lhs, rhs in
            lhs.artistID < rhs.artistID
        }
        return normalizedProfile
    }

    private static func preferencesByArtistID(
        _ preferences: [FestivalArtistPreference]
    ) -> [Int: FestivalArtistPreference] {
        Dictionary(
            uniqueKeysWithValues: preferences.map { preference in
                (preference.artistID, preference)
            }
        )
    }
}

enum FestivalProfileSyncRecord: Codable, Equatable, Hashable, Sendable {
    case profile
    case savedEvent(eventID: Int)
    case artistPreference(artistID: Int)
    case artistNote(artistID: Int)

    var key: String {
        switch self {
        case .profile: return "profile"
        case .savedEvent(let id): return "event:\(id)"
        case .artistPreference(let id): return "rating:\(id)"
        case .artistNote(let id): return "note:\(id)"
        }
    }

    init?(key: String) {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let id = Int(parts[1]) else { return nil }
        switch parts[0] {
        case "event": self = .savedEvent(eventID: id)
        case "rating": self = .artistPreference(artistID: id)
        case "note": self = .artistNote(artistID: id)
        default: return nil
        }
    }

    func value(in profile: CachedOwnerFestivalProfile) -> FestivalProfileRecordValue? {
        switch self {
        case .profile: return nil
        case .savedEvent(let id):
            return .savedEvent(eventID: id, isSaved: profile.savedEventIDs.contains(id))
        case .artistPreference(let id):
            return .artistPreference(profile.artistPreferences.first { $0.artistID == id }
                ?? FestivalArtistPreference(artistID: id, rating: 0, iconName: nil))
        case .artistNote(let id):
            return .artistNote(profile.artistNotes.first { $0.artistID == id }
                ?? FestivalArtistNote(artistID: id, noteText: ""))
        }
    }
}

extension CachedOwnerFestivalProfile {
    var syncRecords: Set<FestivalProfileSyncRecord> {
        Set(savedEventIDs.map { .savedEvent(eventID: $0) }
            + artistPreferences.map { .artistPreference(artistID: $0.artistID) }
            + artistNotes.map { .artistNote(artistID: $0.artistID) }
            + (changeVersions ?? [:]).keys.compactMap(FestivalProfileSyncRecord.init(key:)))
    }

    func change(for record: FestivalProfileSyncRecord) -> FestivalProfileChange? {
        guard let value = record.value(in: self),
              !value.isDeleted || changeVersions?[record.key] != nil else { return nil }
        return FestivalProfileChange(
            value: value,
            version: changeVersions?[record.key] ?? FestivalProfileChangeVersion(
                modifiedAt: .distantPast, changeID: value.legacyChangeID
            )
        )
    }
}

enum FestivalProfileSyncChange: Equatable, Hashable, Sendable {
    case save(FestivalProfileSyncRecord)
    case delete(FestivalProfileSyncRecord)
}

enum FestivalProfileSyncPlanner {
    static func changes(
        from oldProfile: CachedOwnerFestivalProfile,
        to newProfile: CachedOwnerFestivalProfile
    ) -> [FestivalProfileSyncChange] {
        var changes: [FestivalProfileSyncChange] = [.save(.profile)]
        for record in oldProfile.syncRecords.union(newProfile.syncRecords).sorted(by: { $0.key < $1.key }) {
            guard oldProfile.change(for: record) != newProfile.change(for: record) else { continue }
            changes.append(newProfile.change(for: record) == nil ? .delete(record) : .save(record))
        }
        return changes
    }

    static func fullUpload(
        for profile: CachedOwnerFestivalProfile
    ) -> [FestivalProfileSyncChange] {
        [.save(.profile)] + profile.syncRecords.sorted { $0.key < $1.key }.map { .save($0) }
    }
}
