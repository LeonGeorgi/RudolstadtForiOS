#if os(iOS)
import CloudKit
import Foundation

enum FestivalProfileCloudRecordPayload: Equatable, Sendable {
    case profile(
        festivalYear: Int,
        title: String,
        badgeName: String?,
        badgeColorHex: String
    )
    case savedEvent(eventID: Int)
    case artistPreference(FestivalArtistPreference)
    case artistNote(FestivalArtistNote)
}

enum FestivalProfileCloudRecordMapper {
    static func payload(from record: CKRecord) -> FestivalProfileCloudRecordPayload? {
        switch record.recordType {
        case FestivalProfileStore.Constants.profileRecordType:
            return .profile(
                festivalYear: (record["festivalYear"] as? Int) ?? DataStore.year,
                title: (record["profileName"] as? String)
                    ?? FestivalProfileStore.Constants.profileName,
                badgeName: FestivalProfileBadge.normalizedName(record["badgeName"] as? String),
                badgeColorHex: FestivalProfileBadge.resolvedColorHex(
                    record["badgeColorHex"] as? String
                )
            )
        case FestivalProfileStore.Constants.savedEventRecordType:
            return .savedEvent(
                eventID: (record["eventID"] as? Int)
                    ?? numericID(from: record.recordID.recordName)
            )
        case FestivalProfileStore.Constants.artistPreferenceRecordType:
            return .artistPreference(
                FestivalArtistPreference(
                    artistID: (record["artistID"] as? Int)
                        ?? numericID(from: record.recordID.recordName),
                    rating: (record["rating"] as? Int) ?? 0,
                    iconName: record["iconName"] as? String
                )
            )
        case FestivalProfileStore.Constants.artistNoteRecordType:
            return .artistNote(
                FestivalArtistNote(
                    artistID: (record["artistID"] as? Int)
                        ?? numericID(from: record.recordID.recordName),
                    noteText: (record["noteText"] as? String) ?? ""
                )
            )
        default:
            return nil
        }
    }

    static func recordID(
        for record: FestivalProfileSyncRecord,
        profileZoneID: CKRecordZone.ID,
        notesZoneID: CKRecordZone.ID,
        festivalYear: Int = DataStore.year
    ) -> CKRecord.ID {
        switch record {
        case .profile:
            return CKRecord.ID(
                recordName: "FestivalProfile-\(festivalYear)",
                zoneID: profileZoneID
            )
        case .savedEvent(let eventID):
            return CKRecord.ID(
                recordName: "SavedEvent-\(festivalYear)-\(eventID)",
                zoneID: profileZoneID
            )
        case .artistPreference(let artistID):
            return CKRecord.ID(
                recordName: "ArtistPreference-\(festivalYear)-\(artistID)",
                zoneID: profileZoneID
            )
        case .artistNote(let artistID):
            return CKRecord.ID(
                recordName: "ArtistNote-\(festivalYear)-\(artistID)",
                zoneID: notesZoneID
            )
        }
    }

    static func populate(
        _ record: CKRecord,
        for syncRecord: FestivalProfileSyncRecord,
        from profile: CachedOwnerFestivalProfile,
        updatedAt: Date,
        profileRootRecordID: CKRecord.ID
    ) -> CKRecord? {
        switch syncRecord {
        case .profile:
            record["festivalYear"] = DataStore.year as CKRecordValue
            record["schemaVersion"] = FestivalProfileStore.Constants.schemaVersion as CKRecordValue
            record["updatedAt"] = updatedAt as CKRecordValue
            record["profileName"] = FestivalProfileStore.Constants.profileName as CKRecordValue
            record["badgeName"] = FestivalProfileBadge.normalizedName(profile.badgeName)
                as CKRecordValue?
            record["badgeColorHex"] = FestivalProfileBadge.resolvedColorHex(
                profile.badgeColorHex
            ) as CKRecordValue

        case .savedEvent(let eventID):
            guard profile.savedEventIDs.contains(eventID) else {
                return nil
            }
            record["festivalYear"] = DataStore.year as CKRecordValue
            record["eventID"] = eventID as CKRecordValue
            record["updatedAt"] = updatedAt as CKRecordValue
            record.setParent(profileRootRecordID)

        case .artistPreference(let artistID):
            guard let preference = profile.artistPreferences.first(where: {
                $0.artistID == artistID
            }) else {
                return nil
            }
            record["festivalYear"] = DataStore.year as CKRecordValue
            record["artistID"] = artistID as CKRecordValue
            record["rating"] = preference.rating as CKRecordValue
            record["iconName"] = preference.iconName as CKRecordValue?
            record["updatedAt"] = updatedAt as CKRecordValue
            record.setParent(profileRootRecordID)

        case .artistNote(let artistID):
            guard let note = profile.artistNotes.first(where: {
                $0.artistID == artistID
            }) else {
                return nil
            }
            record["festivalYear"] = DataStore.year as CKRecordValue
            record["artistID"] = artistID as CKRecordValue
            record["noteText"] = note.noteText as CKRecordValue
            record["updatedAt"] = updatedAt as CKRecordValue
        }

        return record
    }

    static func syncRecord(for recordID: CKRecord.ID) -> FestivalProfileSyncRecord? {
        let recordName = recordID.recordName
        if recordName.hasPrefix("FestivalProfile-") {
            return .profile
        }
        if recordName.hasPrefix("SavedEvent-") {
            return .savedEvent(eventID: numericID(from: recordName))
        }
        if recordName.hasPrefix("ArtistPreference-") {
            return .artistPreference(artistID: numericID(from: recordName))
        }
        if recordName.hasPrefix("ArtistNote-") {
            return .artistNote(artistID: numericID(from: recordName))
        }
        return nil
    }

    private static func numericID(from recordName: String) -> Int {
        Int(recordName.split(separator: "-").last ?? "") ?? 0
    }
}

enum FestivalProfileSyncConflictAction: Equatable, Sendable {
    case mergeServerRecord
    case recreateZoneAndRetry
    case retryWithoutSystemFields
    case waitForAutomaticRetry
    case fail
}

enum FestivalProfileSyncConflictPolicy {
    static func action(for errorCode: CKError.Code) -> FestivalProfileSyncConflictAction {
        switch errorCode {
        case .serverRecordChanged:
            return .mergeServerRecord
        case .zoneNotFound:
            return .recreateZoneAndRetry
        case .unknownItem:
            return .retryWithoutSystemFields
        case .networkFailure,
             .networkUnavailable,
             .serviceUnavailable,
             .zoneBusy,
             .notAuthenticated,
             .operationCancelled:
            return .waitForAutomaticRetry
        default:
            return .fail
        }
    }
}
#endif
