#if os(iOS)
    import CloudKit
    import Foundation
    import RudolstadtCore

    enum FestivalProfileCloudRecordPayload: Equatable, Sendable {
        case profile(
            festivalYear: Int,
            title: String,
            badgeName: String?,
            badgeColorHex: String
        )
        case change(FestivalProfileChange)
    }

    enum FestivalProfileCloudRecordMapper {
        private typealias Constants = FestivalProfileStore.Constants

        static func payload(from record: CKRecord) -> FestivalProfileCloudRecordPayload? {
        let legacyDate = (record["updatedAt"] as? Date) ?? record.modificationDate ?? .distantPast
            let userDate = record["userModifiedAt"] as? Date
            // An old writer may update a record without knowing the new fields.
            let hasUserVersion = userDate.map { $0 >= legacyDate } ?? false
            let isDeleted = hasUserVersion && (record["isDeleted"] as? Bool == true)
            let value: FestivalProfileRecordValue
            switch record.recordType {
            case Constants.profileRecordType:
                return .profile(
                    festivalYear: (record["festivalYear"] as? Int) ?? DataStore.year,
                    title: (record["profileName"] as? String)
                        ?? Constants.profileName,
                    badgeName: FestivalProfileBadge.normalizedName(record["badgeName"] as? String),
                    badgeColorHex: FestivalProfileBadge.resolvedColorHex(
                        record["badgeColorHex"] as? String
                    )
                )
            case Constants.savedEventRecordType:
                value = .savedEvent(
                    eventID: (record["eventID"] as? Int)
                        ?? numericID(from: record.recordID.recordName),
                    isSaved: !isDeleted
                )
            case Constants.artistPreferenceRecordType:
                value = .artistPreference(
                    FestivalArtistPreference(
                        artistID: (record["artistID"] as? Int)
                            ?? numericID(from: record.recordID.recordName),
                        rating: isDeleted ? 0 : (record["rating"] as? Int) ?? 0,
                        iconName: isDeleted ? nil : record["iconName"] as? String
                    )
                )
            case Constants.artistNoteRecordType:
                value = .artistNote(
                    FestivalArtistNote(
                        artistID: (record["artistID"] as? Int)
                            ?? numericID(from: record.recordID.recordName),
                        noteText: isDeleted ? "" : (record["noteText"] as? String) ?? ""
                    )
                )
            default:
                return nil
            }
        return .change(FestivalProfileChange(
                    value: value,
                    version: FestivalProfileChangeVersion(
                        modifiedAt: hasUserVersion ? (userDate ?? legacyDate) : legacyDate,
                        changeID: hasUserVersion
                            ? (record["changeID"] as? String) ?? value.legacyChangeID
                            : value.legacyChangeID
                    )
                ))
        }

        static func recordID(
            for record: FestivalProfileSyncRecord,
            profileZoneID: CKRecordZone.ID = FestivalProfileCloudRecordMapper.profileZoneID,
            notesZoneID: CKRecordZone.ID = FestivalProfileCloudRecordMapper.notesZoneID,
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
            let change = profile.change(for: syncRecord)
            if syncRecord != .profile, change == nil { return nil }
            if let change {
                record["userModifiedAt"] = change.version.date as CKRecordValue
                record["changeID"] = change.version.changeID as CKRecordValue
                record["isDeleted"] = change.value.isDeleted as CKRecordValue
                // Keep legacy readers' timestamp meaningful; retries never advance it.
                record["updatedAt"] = change.version.date as CKRecordValue
            }
            switch syncRecord {
            case .profile:
                record["festivalYear"] = DataStore.year as CKRecordValue
                record["schemaVersion"] = Constants.schemaVersion as CKRecordValue
                record["updatedAt"] = updatedAt as CKRecordValue
                record["profileName"] = Constants.profileName as CKRecordValue
            record["badgeName"] = FestivalProfileBadge.normalizedName(profile.badgeName)
                    as CKRecordValue?
            record["badgeColorHex"] = FestivalProfileBadge.resolvedColorHex(
                        profile.badgeColorHex
                    ) as CKRecordValue

            case .savedEvent(let eventID):
                record["festivalYear"] = DataStore.year as CKRecordValue
                record["eventID"] = eventID as CKRecordValue
                record.setParent(profileRootRecordID)

            case .artistPreference(let artistID):
                let preference = profile.artistPreferences.first(where: {
                    $0.artistID == artistID
                })
                record["festivalYear"] = DataStore.year as CKRecordValue
                record["artistID"] = artistID as CKRecordValue
                record["rating"] = (preference?.rating ?? 0) as CKRecordValue
                record["iconName"] = preference?.iconName as CKRecordValue?
                record.setParent(profileRootRecordID)

            case .artistNote(let artistID):
                let note = profile.artistNotes.first(where: {
                    $0.artistID == artistID
                })
                record["festivalYear"] = DataStore.year as CKRecordValue
                record["artistID"] = artistID as CKRecordValue
                record["noteText"] = (note?.noteText ?? "") as CKRecordValue
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

        static func restoreChangeVersions(in profile: inout CachedOwnerFestivalProfile) {
            for record in profile.syncRecords {
                guard profile.changeVersions?[record.key] == nil,
                  let value = record.value(in: profile) else { continue }
                let fields = cachedRecordInfo(for: record, in: profile).systemFields
            let historicalDate = fields.flatMap { restoreSystemFieldsRecord(from: $0)?.modificationDate }
                profile.changeVersions = profile.changeVersions ?? [:]
                profile.changeVersions?[record.key] = CachedProfileChangeVersion(
                    modifiedAt: historicalDate ?? .distantPast, changeID: value.legacyChangeID
                )
            }
        }

        static func recordToUpload(
            for syncRecord: FestivalProfileSyncRecord,
            from profile: CachedOwnerFestivalProfile,
            updatedAt: Date
        ) -> CKRecord? {
            let info = cachedRecordInfo(for: syncRecord, in: profile)
            let record = restoreRecord(
                from: info.systemFields, recordType: info.type, recordID: recordID(for: syncRecord)
            )
            return populate(
                record, for: syncRecord, from: profile, updatedAt: updatedAt,
                profileRootRecordID: recordID(for: .profile)
            )
        }

        private static func cachedRecordInfo(
            for record: FestivalProfileSyncRecord,
            in profile: CachedOwnerFestivalProfile
        ) -> (type: String, systemFields: Data?) {
            let name = recordID(for: record).recordName
            switch record {
            case .profile:
                return (Constants.profileRecordType, profile.rootRecordSystemFieldsData)
            case .savedEvent:
            return (Constants.savedEventRecordType, profile.savedEventRecordSystemFieldsByName[name])
            case .artistPreference:
            return (Constants.artistPreferenceRecordType, profile.artistPreferenceRecordSystemFieldsByName[name])
            case .artistNote:
            return (Constants.artistNoteRecordType, profile.artistNoteRecordSystemFieldsByName[name])
            }
        }

    static func updateSystemFields(from record: CKRecord, in profile: inout CachedOwnerFestivalProfile) {
            switch record.recordType {
            case Constants.profileRecordType:
                profile.rootRecordSystemFieldsData = encodeSystemFields(for: record)
                profile.shareRecordName = record.share?.recordID.recordName
            case Constants.savedEventRecordType:
            profile.savedEventRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
            case Constants.artistPreferenceRecordType:
            profile.artistPreferenceRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
            case Constants.artistNoteRecordType:
            profile.artistNoteRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
            default:
                break
            }
        }

    static func clearSystemFields(for recordID: CKRecord.ID, in profile: inout CachedOwnerFestivalProfile) {
            switch recordID.zoneID {
            case profileZoneID:
                if recordID == self.recordID(for: .profile) {
                    profile.rootRecordSystemFieldsData = nil
                } else {
                profile.savedEventRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
                profile.artistPreferenceRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
                }
            case notesZoneID:
                profile.artistNoteRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
            default:
                break
            }
        }

    static func mergeSharedRecord(_ record: CKRecord, into profiles: inout [CachedSharedFestivalProfile]) {
            guard let payload = payload(from: record) else {
                return
            }
            let sharedProfileID = sharedProfileID(for: record.recordID.zoneID)
        var sharedProfile = profiles.first(where: { $0.id == sharedProfileID })
                ?? CachedSharedFestivalProfile(
                    id: sharedProfileID,
                    title: Constants.profileName,
                ownerName: record.recordID.zoneID.ownerName == CKCurrentUserDefaultName ? nil : record.recordID.zoneID.ownerName,
                    badgeName: nil,
                    badgeColorHex: FestivalProfileBadge.defaultColorHex,
                    festivalYear: DataStore.year,
                    savedEventIDs: [],
                    artistPreferences: []
                )

            switch payload {
            case .profile(let festivalYear, let title, let badgeName, let badgeColorHex):
                sharedProfile.title = title
                sharedProfile.badgeName = badgeName
                sharedProfile.badgeColorHex = badgeColorHex
                sharedProfile.festivalYear = festivalYear
            case .change(let change):
                sharedProfile = CachedSharedFestivalProfile(
                    ProfileRecords.shared.applyShared(
                        profile: sharedProfile.domain, value: change.value))
            }

            profiles.removeAll { $0.id == sharedProfileID }
            profiles.append(sharedProfile)
        }

    static func removeSharedRecord(_ recordID: CKRecord.ID, from profiles: inout [CachedSharedFestivalProfile]) {
            let profileID = sharedProfileID(for: recordID.zoneID)
            guard var profile = profiles.first(where: { $0.id == profileID }) else { return }
            if recordID == self.recordID(for: .profile, profileZoneID: recordID.zoneID) {
                profiles.removeAll { $0.id == profileID }
                return
            }
            if let key = syncRecord(for: recordID)?.key {
                profile = CachedSharedFestivalProfile(
                    ProfileRecords.shared.removeShared(profile: profile.domain, key: key))
            }
            profiles.removeAll { $0.id == profileID }
            profiles.append(profile)
        }

        static func sharedProfileID(for zoneID: CKRecordZone.ID) -> String {
            "\(zoneID.ownerName)|\(zoneID.zoneName)"
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

    // System-field and engine-state coding is shared by sync and sharing.
    extension FestivalProfileCloudRecordMapper {
        static var profileZoneID: CKRecordZone.ID {
            CKRecordZone.ID(
                zoneName: Constants.profileZoneName,
                ownerName: CKCurrentUserDefaultName
            )
        }

        static var notesZoneID: CKRecordZone.ID {
            CKRecordZone.ID(
                zoneName: Constants.notesZoneName,
                ownerName: CKCurrentUserDefaultName
            )
        }

        static func encodeStateSerialization(
            _ serialization: CKSyncEngine.State.Serialization
        ) -> Data? {
            try? JSONEncoder().encode(serialization)
        }

        static func decodeStateSerialization(
            from data: Data?
        ) -> CKSyncEngine.State.Serialization? {
            guard let data else {
                return nil
            }
            return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
        }

        static func encodeSystemFields(for record: CKRecord) -> Data? {
            let archiver = NSKeyedArchiver(requiringSecureCoding: true)
            record.encodeSystemFields(with: archiver)
            archiver.finishEncoding()
            return archiver.encodedData
        }

        static func restoreRecord(
            from systemFieldsData: Data?,
            recordType: String,
            recordID: CKRecord.ID
        ) -> CKRecord {
            guard let systemFieldsData else {
                return CKRecord(recordType: recordType, recordID: recordID)
            }

            if let restoredRecord = restoreSystemFieldsRecord(from: systemFieldsData) {
                return restoredRecord
            }

            return CKRecord(recordType: recordType, recordID: recordID)
        }

        static func restoreSystemFieldsRecord(from systemFieldsData: Data) -> CKRecord? {
            guard
                let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: systemFieldsData)
            else {
                return nil
            }

            unarchiver.requiresSecureCoding = true
            if let record = CKRecord(coder: unarchiver) {
                unarchiver.finishDecoding()
                return record
            }

            unarchiver.finishDecoding()
            return nil
        }
    }
#endif
