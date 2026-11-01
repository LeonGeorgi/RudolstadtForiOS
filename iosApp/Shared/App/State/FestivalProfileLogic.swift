import Foundation
import CryptoKit
import RudolstadtCore

typealias FestivalProfileRecordValue = ProfileRecordValue
typealias FestivalProfileChange = ProfileRecordChange
typealias FestivalProfileChangeVersion = ProfileVersion
typealias FestivalProfileMutation = ProfileMutation

/// Existing JSON representation, including Foundation's Date encoding, stays at the storage boundary.
struct CachedProfileChangeVersion: Codable, Equatable, Sendable {
    let modifiedAt: Date
    let changeID: String
    init(modifiedAt: Date, changeID: String) {
        self.modifiedAt = Date(
            timeIntervalSince1970: (modifiedAt.timeIntervalSince1970 * 1_000).rounded() / 1_000)
        self.changeID = changeID
    }
    init(_ value: ProfileVersion) { self.init(modifiedAt: value.date, changeID: value.changeID) }
    var core: ProfileVersion {
        ProfileVersion(modifiedAt: modifiedAt.timeIntervalSince1970, changeID: changeID)
    }
}
extension ProfileVersion: @unchecked @retroactive Sendable {
    convenience init(modifiedAt: Date, changeID: String) {
        self.init(
            modifiedAt: (modifiedAt.timeIntervalSince1970 * 1_000).rounded() / 1_000,
            changeID: changeID)
    }
    var date: Date { Date(timeIntervalSince1970: modifiedAt) }
}
extension ProfileRecordChange: @unchecked @retroactive Sendable {
    convenience init(value: ProfileRecordValue, version: ProfileVersion) {
        self.init(key: value.key, value: value, version: version)
    }
}
extension ProfileRecordValue: @unchecked @retroactive Sendable {
    static func savedEvent(eventID: Int, isSaved: Bool) -> ProfileRecordValue {
        ProfileRecordValue(
            kind: "event", id: Int64(eventID), isSaved: isSaved, rating: 0, iconName: nil,
            noteText: "")
    }
    static func artistPreference(_ value: FestivalArtistPreference) -> ProfileRecordValue {
        ProfileRecordValue(
            kind: "rating", id: Int64(value.artistID), isSaved: false, rating: Int32(value.rating),
            iconName: value.iconName, noteText: "")
    }
    static func artistNote(_ value: FestivalArtistNote) -> ProfileRecordValue {
        ProfileRecordValue(
            kind: "note", id: Int64(value.artistID), isSaved: false, rating: 0, iconName: nil,
            noteText: value.noteText)
    }
    var record: FestivalProfileSyncRecord {
        guard let value = FestivalProfileSyncRecord(key: key) else {
            preconditionFailure("Invalid shared record key")
        }
        return value
    }
    var legacyChangeID: String { "legacy:" + profileContentHash(legacyContent) }
}
private func profileContentHash(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}
extension ProfileMutation {
    static func toggleSavedEvent(eventID: Int) -> ProfileMutation {
        ProfileMutation(
            kind: "toggleSavedEvent", id: Int64(eventID), rating: 0, text: "", color: "")
    }
    static func updateBadge(name: String, colorHex: String) -> ProfileMutation {
        ProfileMutation(
            kind: "updateBadge", id: 0, rating: 0,
            text: FestivalProfileBadge.normalizedName(name) ?? "",
            color: FestivalProfileBadge.resolvedColorHex(colorHex))
    }
    static func setArtistRating(artistID: Int, rating: Int) -> ProfileMutation {
        ProfileMutation(
            kind: "setArtistRating", id: Int64(artistID), rating: Int32(rating), text: "", color: ""
        )
    }
    static func setArtistIcon(artistID: Int, iconName: String) -> ProfileMutation {
        ProfileMutation(
            kind: "setArtistIcon", id: Int64(artistID), rating: 0, text: iconName, color: "")
    }
    static func setArtistNote(artistID: Int, noteText: String) -> ProfileMutation {
        ProfileMutation(
            kind: "setArtistNote", id: Int64(artistID), rating: 0, text: noteText, color: "")
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
        if key == "profile" { self = .profile; return }
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
        ProfileRecords.shared.value(profile: profile.domainProfile, key: key)
    }
}

extension CachedOwnerFestivalProfile {
    var domainProfile: PersonalProfile {
        PersonalProfile(
            badgeName: badgeName, badgeColorHex: badgeColorHex,
            savedEventIDs: KotlinCore.ids(savedEventIDs),
            artistPreferences: artistPreferences.map(\.core), artistNotes: artistNotes.map(\.core))
    }
    mutating func applyDomainProfile(_ profile: PersonalProfile) {
        badgeName = profile.badgeName; badgeColorHex = profile.badgeColorHex
        savedEventIDs = profile.savedEventIDs.map(\.intValue)
        artistPreferences = profile.artistPreferences.map(\.native)
        artistNotes = profile.artistNotes.map {
            FestivalArtistNote(artistID: Int($0.artistID), noteText: $0.noteText)
        }
    }
    var domainChanges: [ProfileRecordChange] {
        ProfileRecords.shared.changes(
            profile: domainProfile,
            versions: (changeVersions ?? [:]).map {
                ProfileRecordVersion(key: $0.key, version: $0.value.core)
            },
            legacyDate: Date.distantPast.timeIntervalSince1970, hash: profileContentHash)
    }
    var syncRecords: Set<FestivalProfileSyncRecord> {
        Set(
            ProfileRecords.shared.keys(
                profile: domainProfile, versionKeys: Set((changeVersions ?? [:]).keys)
            ).compactMap(FestivalProfileSyncRecord.init(key:)))
    }
    func change(for record: FestivalProfileSyncRecord) -> FestivalProfileChange? {
        domainChanges.first { $0.key == record.key }
    }
}
extension CachedSharedFestivalProfile {
    var domain: SharedProfile {
        SharedProfile(
            id: id, title: title, ownerName: ownerName, badgeName: badgeName,
            badgeColorHex: badgeColorHex,
            festivalYear: festivalYear, savedEventIDs: savedEventIDs,
            artistPreferences: artistPreferences
        ).ordered()
    }
    init(_ value: SharedProfile) {
        self.init(
            id: value.profileID, title: value.title, ownerName: value.ownerName,
            badgeName: value.badgeName,
            badgeColorHex: value.badgeColor, festivalYear: Int(value.year),
            savedEventIDs: value.saved.map(\.intValue),
            artistPreferences: value.preferences.map(\.native)
        )
    }
}
