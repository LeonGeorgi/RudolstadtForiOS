#if os(iOS)
import CloudKit
import Foundation
import OSLog

@MainActor
final class FestivalProfileSharingService {
    private typealias Constants = FestivalProfileStore.Constants
    private weak var store: FestivalProfileStore?
    private let syncCoordinator: FestivalProfileSyncCoordinator
    private var container: CKContainer { syncCoordinator.container }
    private let isEnabled: Bool

    init(
        store: FestivalProfileStore,
        syncCoordinator: FestivalProfileSyncCoordinator,
        isEnabled: Bool
    ) {
        self.store = store
        self.syncCoordinator = syncCoordinator
        self.isEnabled = isEnabled
    }

    func restoreCachedState() {
        if let share = cachedShare() {
            applyAcceptedShareParticipants(from: share)
        }
    }

    private var profileZoneID: CKRecordZone.ID {
        FestivalProfileCloudRecordMapper.profileZoneID
    }

    private func profileRootRecordID() -> CKRecord.ID {
        FestivalProfileCloudRecordMapper.recordID(
            for: .profile,
            profileZoneID: profileZoneID,
            notesZoneID: FestivalProfileCloudRecordMapper.notesZoneID
        )
    }

    func prepareShare() async throws -> CKShare {
        guard let store else { throw CancellationError() }
        guard isEnabled else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cloud sync is disabled."]
            )
        }

        AppLog.sync.info("Preparing CloudKit share for the current festival profile")

        await syncCoordinator.refreshAccountStatus()
        guard case .available = store.iCloudStatus else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "iCloud is not available."]
            )
        }

        store.syncStore.isPreparingShare = true
        defer {
            store.syncStore.isPreparingShare = false
        }

        try await syncCoordinator.ensureCurrentProfileExistsOnServer()

        if let shareRecordName = store.cacheSnapshot.currentProfile.shareRecordName {
            let shareRecordID = CKRecord.ID(
                recordName: shareRecordName,
                zoneID: profileZoneID
            )
            if let existingShare = try await fetchShare(recordID: shareRecordID) {
                cacheCurrentShare(existingShare)
                AppLog.sync.info("Loaded existing CloudKit share")
                return existingShare
            }
        }

        guard let rootRecord = try await fetchPrivateRecord(recordID: profileRootRecordID()) else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "The festival profile is not available in CloudKit yet."]
            )
        }

        let share = CKShare(rootRecord: rootRecord)
        share[CKShare.SystemFieldKey.title] = Constants.profileName as CKRecordValue
        share.publicPermission = .none

        let savedRecords = try await modifyRecords(
            in: container.privateCloudDatabase,
            saving: [rootRecord, share],
            deleting: []
        )
        guard let savedShare = savedRecords.compactMap({ $0 as? CKShare }).first else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create the CloudKit share."]
            )
        }

        cacheCurrentShare(savedShare)
        AppLog.sync.info("Created new CloudKit share")
        return savedShare
    }

    func prepareOneTimeShareURL() async throws -> URL {
        AppLog.sync.info("Generating one-time share URL")
        let share = try await prepareShare()
        let participant = CKShare.Participant.oneTimeURLParticipant()
        participant.permission = .readOnly
        share.addParticipant(participant)

        let savedRecords = try await modifyRecords(
            in: container.privateCloudDatabase,
            saving: [share],
            deleting: []
        )
        guard let savedShare = savedRecords.compactMap({ $0 as? CKShare }).first else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create a QR invite for your profile."]
            )
        }

        cacheCurrentShare(savedShare)

        guard let inviteURL = oneTimeInviteURL(for: participant.participantID, in: savedShare) else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "CloudKit did not return a QR invite URL."]
            )
        }

        AppLog.sync.info("Generated one-time share URL")
        return inviteURL
    }

    func refreshShareParticipants() async {
        guard let store else { return }
        guard isEnabled else {
            return
        }

        await syncCoordinator.refreshAccountStatus()
        guard case .available = store.iCloudStatus else {
            return
        }

        do {
            try await refreshCurrentShareParticipants()
        } catch {
            AppLog.sync.error(
                "Failed to refresh CloudKit share participants: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func acceptShare(metadata: CKShare.Metadata) async {
        guard let store else { return }
        do {
            AppLog.sync.info("Accepting CloudKit share from system handoff")
            store.setSyncState(.syncing)
            try await acceptShares([metadata])
            try await syncCoordinator.fetchSharedChanges()
            store.setSyncState(.idle)
            AppLog.sync.info("Accepted CloudKit share successfully")
        } catch {
            store.setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "Failed to accept CloudKit share: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func acceptShare(url: URL) async throws {
        guard let store else { throw CancellationError() }
        guard isEnabled else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Cloud sync is disabled."]
            )
        }

        await syncCoordinator.refreshAccountStatus()
        guard case .available = store.iCloudStatus else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "iCloud is not available."]
            )
        }

        AppLog.sync.info("Accepting CloudKit share from URL")
        store.setSyncState(.syncing)

        do {
            let metadataResults = try await container.shareMetadatas(for: [url])
            guard let metadataResult = metadataResults[url] ?? metadataResults.first?.value else {
                throw NSError(
                    domain: "FestivalProfileStore",
                    code: 9,
                    userInfo: [NSLocalizedDescriptionKey: "That QR code is not a valid festival profile invite."]
                )
            }

            let metadata = try metadataResult.get()
            try await acceptShares([metadata])

            try await syncCoordinator.fetchSharedChanges()

            store.setSyncState(.idle)
            AppLog.sync.info("Accepted CloudKit share URL successfully")
        } catch {
            store.setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "Failed to accept CloudKit share URL: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    private func cacheCurrentShare(_ share: CKShare) {
        guard let store else { return }
        store.updateCache { cache in
            cache.currentProfile.shareRecordName = share.recordID.recordName
            cache.currentProfile.shareRecordSystemFieldsData = FestivalProfileCloudRecordMapper.encodeSystemFields(for: share)
        }
        applyAcceptedShareParticipants(from: share)
        store.persistCache(immediately: true)
        if store.syncStore.shareState != .shared {
            store.syncStore.shareState = .shared
        }
        AppLog.sync.info("Cached CloudKit share \(share.recordID.recordName, privacy: .public)")
    }

    func refreshCurrentShareParticipants() async throws {
        guard let store else { throw CancellationError() }
        guard let shareRecordName = store.cacheSnapshot.currentProfile.shareRecordName else {
            applyAcceptedShareParticipantCount(0)
            return
        }

        let shareRecordID = CKRecord.ID(
            recordName: shareRecordName,
            zoneID: profileZoneID
        )
        guard let share = try await fetchShare(recordID: shareRecordID) else {
            store.updateCache { cache in
                cache.currentProfile.shareRecordName = nil
                cache.currentProfile.shareRecordSystemFieldsData = nil
            }
            store.syncStore.shareState = .notShared
            applyAcceptedShareParticipantCount(0)
            store.persistCache(immediately: true)
            return
        }

        cacheCurrentShare(share)
    }

    private func applyAcceptedShareParticipants(from share: CKShare) {
        let count = share.participants.filter { participant in
            participant.role != .owner
                && participant.acceptanceStatus == .accepted
        }.count
        applyAcceptedShareParticipantCount(count)
    }

    private func applyAcceptedShareParticipantCount(_ count: Int) {
        guard let store else { return }
        guard store.syncStore.acceptedShareParticipantCount != count else {
            return
        }

        store.syncStore.acceptedShareParticipantCount = count
        AppLog.sync.info(
            "Accepted share participants updated to \(count) participants"
        )
    }

    func cachedShare() -> CKShare? {
        guard let store else { return nil }
        guard let shareSystemFieldsData = store.cacheSnapshot.currentProfile.shareRecordSystemFieldsData else {
            return nil
        }
        return FestivalProfileCloudRecordMapper.restoreSystemFieldsRecord(from: shareSystemFieldsData) as? CKShare
    }

    private func oneTimeInviteURL(for participantID: CKShare.Participant.ID, in share: CKShare) -> URL? {
        if #available(iOS 26.0, *) {
            return share.oneTimeURL(for: participantID)
        }

        let selector = NSSelectorFromString("oneTimeURLForParticipantID:")
        guard share.responds(to: selector) else {
            return nil
        }

        return share.perform(selector, with: participantID)?
            .takeUnretainedValue() as? URL
    }

    private func fetchPrivateRecord(recordID: CKRecord.ID) async throws -> CKRecord? {
        try await fetchRecord(
            in: container.privateCloudDatabase,
            recordID: recordID
        )
    }

    private func fetchShare(recordID: CKRecord.ID) async throws -> CKShare? {
        try await fetchRecord(
            in: container.privateCloudDatabase,
            recordID: recordID
        ) as? CKShare
    }

    private func fetchRecord(
        in database: CKDatabase,
        recordID: CKRecord.ID
    ) async throws -> CKRecord? {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: [recordID])
            operation.desiredKeys = nil
            var fetchedRecord: CKRecord?
            operation.perRecordResultBlock = { matchedRecordID, result in
                guard matchedRecordID == recordID else {
                    return
                }
                if case .success(let record) = result {
                    fetchedRecord = record
                }
            }
            operation.fetchRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: fetchedRecord)
                case .failure(let error):
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        continuation.resume(returning: nil)
                    } else {
                        AppLog.sync.error(
                            "Failed to fetch CloudKit record \(recordID.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)"
                        )
                        continuation.resume(throwing: error)
                    }
                }
            }
            database.add(operation)
        }
    }

    private func modifyRecords(
        in database: CKDatabase,
        saving recordsToSave: [CKRecord],
        deleting recordIDsToDelete: [CKRecord.ID]
    ) async throws -> [CKRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(
                recordsToSave: recordsToSave,
                recordIDsToDelete: recordIDsToDelete
            )
            operation.savePolicy = .ifServerRecordUnchanged
            var savedRecords: [CKRecord.ID: CKRecord] = [:]
            operation.perRecordSaveBlock = { recordID, result in
                if case .success(let record) = result {
                    savedRecords[recordID] = record
                }
            }
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(
                        returning: recordsToSave.compactMap { record in
                            savedRecords[record.recordID] ?? record
                        }
                    )
                case .failure(let error):
                    AppLog.sync.error(
                        "CloudKit modifyRecords failed: \(error.localizedDescription, privacy: .public)"
                    )
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private func acceptShares(_ metadatas: [CKShare.Metadata]) async throws {
        AppLog.sync.info("Accepting \(metadatas.count) CloudKit share metadata objects")
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: metadatas)
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    AppLog.sync.info("Accepted CloudKit shares successfully")
                    continuation.resume()
                case .failure(let error):
                    AppLog.sync.error(
                        "CKAcceptSharesOperation failed: \(error.localizedDescription, privacy: .public)"
                    )
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }
}
#endif
