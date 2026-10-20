#if os(iOS)
import CloudKit
import Foundation
import OSLog

@MainActor
final class FestivalProfileSyncCoordinator: CKSyncEngineDelegate {
    private typealias Constants = FestivalProfileStore.Constants
    private weak var store: FestivalProfileStore?
    private weak var sharingService: FestivalProfileSharingService?
    private(set) lazy var container = CKContainer(identifier: Constants.cloudKitContainerIdentifier)
    private let isEnabled: Bool
    private let now: () -> Date
    private var privateSyncEngine: CKSyncEngine?
    private var sharedSyncEngine: CKSyncEngine?
    private var pendingOwnerSendTask: Task<Void, Never>?
    private var didObserveRemotePrivateDataDuringMigration = false
    private var didCompleteInitialPrivateFetch = false
    private var activeRefreshReason: String?

    init(store: FestivalProfileStore, isEnabled: Bool, now: @escaping () -> Date) {
        self.store = store
        self.isEnabled = isEnabled
        self.now = now
    }

    deinit {
        pendingOwnerSendTask?.cancel()
    }

    func start(sharingService: FestivalProfileSharingService) {
        self.sharingService = sharingService
        guard let store else { return }
        guard isEnabled else {
            store.setICloudStatus(.unavailable("Cloud sync disabled"))
            return
        }
        configureSyncEngines()
        Task { [weak self] in
            guard let self else { return }
            await refreshAccountStatus()
            await performInitialFetchIfNeeded()
        }
    }

    func profileDidChange(from oldProfile: CachedOwnerFestivalProfile, to newProfile: CachedOwnerFestivalProfile) {
        guard let store, isEnabled,
              store.cacheSnapshot.migrationVersion >= Constants.migrationVersion else { return }
        enqueuePendingChanges(forTransitionFrom: oldProfile, to: newProfile)
        store.setSyncState(.syncing)
        schedulePendingOwnerSend()
    }

    func fetchSharedChanges() async throws {
        if let sharedSyncEngine {
            try await sharedSyncEngine.fetchChanges()
        }
    }

    func refresh(reason: String = "manual") async {
        guard let store else { return }
        guard isEnabled else {
            AppLog.sync.info(
                "Skipped \(reason, privacy: .public) iCloud refresh because CloudKit is disabled"
            )
            return
        }
        guard activeRefreshReason == nil else {
            AppLog.sync.info(
                "Skipped \(reason, privacy: .public) iCloud refresh because \(self.activeRefreshReason ?? "another", privacy: .public) refresh is already running"
            )
            return
        }

        activeRefreshReason = reason
        defer {
            activeRefreshReason = nil
        }

        AppLog.sync.info("Starting \(reason, privacy: .public) iCloud refresh")
        await refreshAccountStatus()
        guard case .available = store.iCloudStatus else {
            AppLog.sync.info(
                "Skipped \(reason, privacy: .public) iCloud refresh because iCloud is \(store.iCloudStatus.logDescription, privacy: .public)"
            )
            return
        }
        store.setSyncState(.syncing)
        let failureGeneration = store.syncFailureGeneration
        do {
            enqueuePersistedChanges()
            if let privateSyncEngine {
                try await privateSyncEngine.sendChanges()
                try await privateSyncEngine.fetchChanges()
            }
            if let sharedSyncEngine {
                try await sharedSyncEngine.fetchChanges()
            }
            try await sharingService?.refreshCurrentShareParticipants()
            guard failureGeneration == store.syncFailureGeneration,
                  store.pendingProfileRecords.isEmpty,
                  privateSyncEngine?.state.pendingRecordZoneChanges.isEmpty != false
            else { return }
            let refreshDate = now()
            store.syncStore.lastSuccessfulRefreshDate = refreshDate
            store.updateCache { cache in
                cache.lastSuccessfulRefreshDate = refreshDate
            }
            store.persistCache()
            store.syncStore.confirmSuccess()
            AppLog.sync.info("Finished \(reason, privacy: .public) iCloud refresh")
        } catch {
            store.setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "\(reason, privacy: .public) iCloud refresh failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private enum DatabaseKind: String {
        case owner
        case shared
    }

    private func syncSnapshotSummary(for store: FestivalProfileStore) -> String {
        "savedEvents=\(store.cacheSnapshot.currentProfile.savedEventIDs.count), ratings=\(store.cacheSnapshot.currentProfile.artistPreferences.count), notes=\(store.cacheSnapshot.currentProfile.artistNotes.count), friends=\(store.cacheSnapshot.sharedProfiles.count), shareState=\(store.shareState.logDescription)"
    }

    private var profileZoneID: CKRecordZone.ID { FestivalProfileCloudRecordMapper.profileZoneID }

    private var notesZoneID: CKRecordZone.ID { FestivalProfileCloudRecordMapper.notesZoneID }

    private func profileRootRecordID() -> CKRecord.ID {
        recordID(for: .profile)
    }

    private func configureSyncEngines() {
        guard let store else { return }
        let privateConfiguration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: FestivalProfileCloudRecordMapper.decodeStateSerialization(from: store.cacheSnapshot.privateStateSerializationData),
            delegate: self
        )
        privateSyncEngine = CKSyncEngine(privateConfiguration)

        store.updateCache { cache in
            // Old builds queued physical deletions. Retain their intent without
            // inventing a current edit date, then send versioned deletion records.
            for pendingChange in privateSyncEngine?.state.pendingRecordZoneChanges ?? [] {
                if case .deleteRecord(let recordID) = pendingChange,
                   let record = FestivalProfileCloudRecordMapper.syncRecord(for: recordID),
                   record != .profile, let value = record.value(in: cache.currentProfile), value.isDeleted {
                    if cache.currentProfile.changeVersions?[record.key] == nil {
                        cache.currentProfile.changeVersions = cache.currentProfile.changeVersions ?? [:]
                        cache.currentProfile.changeVersions?[record.key] = FestivalProfileChangeVersion(
                            modifiedAt: cache.lastSuccessfulRefreshDate ?? .distantPast,
                            changeID: value.legacyChangeID
                        )
                    }
                    cache.pendingProfileRecords = (cache.pendingProfileRecords ?? []).union([record])
                    privateSyncEngine?.state.remove(pendingRecordZoneChanges: [pendingChange])
                }
            }
        }
        enqueuePersistedChanges()

        let sharedConfiguration = CKSyncEngine.Configuration(
            database: container.sharedCloudDatabase,
            stateSerialization: FestivalProfileCloudRecordMapper.decodeStateSerialization(from: store.cacheSnapshot.sharedStateSerializationData),
            delegate: self
        )
        sharedSyncEngine = CKSyncEngine(sharedConfiguration)
        AppLog.sync.info("Configured CloudKit sync engines")
    }

    func restoreCachedState() {
        store?.updateCache { cache in
            FestivalProfileCloudRecordMapper.restoreChangeVersions(in: &cache.currentProfile)
        }
    }

    private func enqueuePersistedChanges() {
        guard let store else { return }
        guard store.cacheSnapshot.migrationVersion >= Constants.migrationVersion, !store.pendingProfileRecords.isEmpty else { return }
        enqueueOwnerChanges(
            store.pendingProfileRecords.map { .saveRecord(recordID(for: $0)) }
        )
    }

    private func schedulePendingOwnerSend() {
        pendingOwnerSendTask?.cancel()
        pendingOwnerSendTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Constants.localMutationSyncDelayNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            await self?.sendPendingOwnerChanges()
        }
    }

    private func sendPendingOwnerChanges() async {
        guard let store, isEnabled, activeRefreshReason == nil,
              case .available = store.iCloudStatus,
              let privateSyncEngine else { return }

        do {
            store.setSyncState(.syncing)
            enqueuePersistedChanges()
            try await privateSyncEngine.sendChanges()
            store.setSyncState(.idle)
            AppLog.sync.info("Sent pending owner CloudKit changes")
        } catch {
            store.setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "Sending pending owner CloudKit changes failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func performInitialFetchIfNeeded() async {
        guard let store else { return }
        guard case .available = store.iCloudStatus else {
            return
        }
        await refresh(reason: "initial")
    }

    func refreshAccountStatus() async {
        guard let store else { return }
        do {
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available:
                store.setICloudStatus(.available)
            case .couldNotDetermine:
                store.setICloudStatus(.unavailable("Could not determine your iCloud status."))
            case .noAccount:
                store.setICloudStatus(.unavailable("Sign in to iCloud to sync your festival profile."))
            case .restricted:
                store.setICloudStatus(.unavailable("iCloud sync is restricted on this device."))
            case .temporarilyUnavailable:
                store.setICloudStatus(.unavailable("iCloud is temporarily unavailable."))
            @unknown default:
                store.setICloudStatus(.unavailable("iCloud is unavailable right now."))
            }
        } catch {
            store.setICloudStatus(.unavailable(error.localizedDescription))
        }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        guard let store else { return }
        let databaseKind = databaseKind(for: syncEngine)

        switch event {
        case .stateUpdate(let stateUpdate):
            handleStateUpdate(stateUpdate, databaseKind: databaseKind)
        case .accountChange(_):
            await refreshAccountStatus()
        case .fetchedDatabaseChanges(let fetchedDatabaseChanges):
            handleFetchedDatabaseChanges(
                fetchedDatabaseChanges,
                databaseKind: databaseKind
            )
        case .fetchedRecordZoneChanges(let fetchedRecordZoneChanges):
            handleFetchedRecordZoneChanges(
                fetchedRecordZoneChanges,
                databaseKind: databaseKind
            )
        case .sentRecordZoneChanges(let sentRecordZoneChanges):
            handleSentRecordZoneChanges(sentRecordZoneChanges)
        case .sentDatabaseChanges(let changes):
            if let failure = changes.failedZoneSaves.first {
                store.setSyncState(.error(failure.error.localizedDescription))
            }
            if let failure = changes.failedZoneDeletes.values.first {
                store.setSyncState(.error(failure.localizedDescription))
            }
            store.setSyncState(.idle)
        case .didFetchChanges(_):
            handleDidFetchChanges(databaseKind: databaseKind)
        case .willFetchChanges(_),
             .willFetchRecordZoneChanges(_),
             .willSendChanges(_):
            store.setSyncState(.syncing)
        case .didFetchRecordZoneChanges(let changes):
            if let error = changes.error {
                store.setSyncState(.error(error.localizedDescription))
            }
        case .didSendChanges(_):
            store.setSyncState(.idle)
        @unknown default:
            break
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { pendingChange in
            context.options.scope.contains(pendingChange)
        }

        guard !changes.isEmpty else {
            return nil
        }

        AppLog.sync.info(
            "Preparing CloudKit upload batch with \(changes.count) pending changes"
        )

        return await CKSyncEngine.RecordZoneChangeBatch(
            pendingChanges: changes
        ) { [weak self] recordID in
            await self?.recordToUpload(for: recordID)
        }
    }

    private func handleStateUpdate(
        _ event: CKSyncEngine.Event.StateUpdate,
        databaseKind: DatabaseKind
    ) {
        guard let store else { return }
        store.updateCache { cache in
            switch databaseKind {
            case .owner:
                cache.privateStateSerializationData = FestivalProfileCloudRecordMapper.encodeStateSerialization(event.stateSerialization)
            case .shared:
                cache.sharedStateSerializationData = FestivalProfileCloudRecordMapper.encodeStateSerialization(event.stateSerialization)
            }
        }
        store.persistCache(immediately: true)
    }

    private func handleDidFetchChanges(databaseKind: DatabaseKind) {
        guard let store else { return }
        guard databaseKind == .owner else {
            store.setSyncState(.idle)
            return
        }

        if store.cacheSnapshot.migrationVersion < Constants.migrationVersion && !didCompleteInitialPrivateFetch {
            didCompleteInitialPrivateFetch = true
            store.updateCache { cache in
                cache.migrationVersion = Constants.migrationVersion
            }
            if !didObserveRemotePrivateDataDuringMigration {
                enqueueFullUploadForCurrentProfile()
                AppLog.sync.info(
                    "No remote CloudKit data was found during migration; queued full profile upload"
                )
            }
            enqueuePersistedChanges()
            store.persistCache(immediately: true)
        }

        store.setSyncState(.idle)
    }

    private func handleFetchedDatabaseChanges(
        _ event: CKSyncEngine.Event.FetchedDatabaseChanges,
        databaseKind: DatabaseKind
    ) {
        guard let store else { return }
        switch databaseKind {
        case .owner:
            for deletion in event.deletions {
                if deletion.zoneID == profileZoneID {
                    store.updateCache { cache in
                        cache.currentProfile.rootRecordSystemFieldsData = nil
                        cache.currentProfile.savedEventRecordSystemFieldsByName = [:]
                        cache.currentProfile.artistPreferenceRecordSystemFieldsByName = [:]
                        cache.currentProfile.shareRecordName = nil
                        cache.currentProfile.shareRecordSystemFieldsData = nil
                    }
                    enqueueFullUploadForCurrentProfile()
                } else if deletion.zoneID == notesZoneID {
                    store.updateCache { cache in
                        cache.currentProfile.artistNoteRecordSystemFieldsByName = [:]
                    }
                    enqueueFullUploadForCurrentProfile()
                }
            }
            store.publishOwnerProfile()
            store.persistCache(immediately: true)
            if !event.deletions.isEmpty {
                AppLog.sync.info("Applied \(event.deletions.count) owner database deletions")
            }
        case .shared:
            guard !event.deletions.isEmpty else {
                return
            }
            let deletedSharedProfileIDs = Set(
                event.deletions.map { deletion in
                    FestivalProfileCloudRecordMapper.sharedProfileID(for: deletion.zoneID)
                }
            )
            store.updateCache { cache in
                cache.sharedProfiles.removeAll { sharedProfile in
                    deletedSharedProfileIDs.contains(sharedProfile.id)
                }
            }
            store.publishSharedProfiles()
            store.persistCache(immediately: true)
            AppLog.sync.info("Applied \(event.deletions.count) shared database deletions")
        }
    }

    private func handleFetchedRecordZoneChanges(
        _ event: CKSyncEngine.Event.FetchedRecordZoneChanges,
        databaseKind: DatabaseKind
    ) {
        guard let store else { return }
        guard !event.modifications.isEmpty || !event.deletions.isEmpty else {
            return
        }
        switch databaseKind {
        case .owner:
            didObserveRemotePrivateDataDuringMigration = true
            for modification in event.modifications {
                mergeOwnerRecordFromServer(modification.record)
            }
            for deletion in event.deletions {
                handleOwnerDeletion(recordID: deletion.recordID)
            }
            store.publishOwnerProfile()
        case .shared:
            store.updateCache { cache in
                for modification in event.modifications {
                    FestivalProfileCloudRecordMapper.mergeSharedRecord(modification.record, into: &cache.sharedProfiles)
                }
                for deletion in event.deletions {
                    FestivalProfileCloudRecordMapper.removeSharedRecord(deletion.recordID, from: &cache.sharedProfiles)
                }
            }
            store.publishSharedProfiles()
        }
        store.persistCache(immediately: true)
        AppLog.sync.info(
            "Applied \(event.modifications.count) \(databaseKind.rawValue, privacy: .public) record changes and \(event.deletions.count) deletions"
        )
    }

    private func handleSentRecordZoneChanges(
        _ event: CKSyncEngine.Event.SentRecordZoneChanges
    ) {
        guard let store else { return }
        AppLog.sync.info(
            "Uploaded \(event.savedRecords.count) CloudKit records with \(event.failedRecordSaves.count) failures"
        )
        for savedRecord in event.savedRecords {
            updateSystemFields(from: savedRecord)
            if case .change(let change) = FestivalProfileCloudRecordMapper.payload(from: savedRecord) {
                store.acknowledgeUploadedChange(change)
                if store.pendingProfileRecords.contains(change.value.record) {
                    privateSyncEngine?.state.add(pendingRecordZoneChanges: [.saveRecord(savedRecord.recordID)])
                }
            } else if savedRecord.recordType == Constants.profileRecordType {
                store.updateCache { cache in
                    cache.pendingProfileRecords?.remove(.profile)
                }
            }
        }

        for failedRecordSave in event.failedRecordSaves {
            if let record = FestivalProfileCloudRecordMapper.syncRecord(for: failedRecordSave.record.recordID) {
                store.updateCache { cache in
                    cache.pendingProfileRecords = (cache.pendingProfileRecords ?? []).union([record])
                }
            }
            AppLog.sync.error(
                "Failed to save CloudKit record \(failedRecordSave.record.recordID.recordName, privacy: .public): \(failedRecordSave.error.localizedDescription, privacy: .public)"
            )
            let action = FestivalProfileSyncConflictPolicy.action(for: failedRecordSave.error.code)
            switch action {
            case .mergeServerRecord:
                if let serverRecord = failedRecordSave.error.serverRecord {
                    mergeOwnerRecordFromServer(serverRecord)
                } else {
                    store.setSyncState(.error(failedRecordSave.error.localizedDescription))
                }
            case .recreateZoneAndRetry, .retryWithoutSystemFields:
                if action == .recreateZoneAndRetry {
                    privateSyncEngine?.state.add(pendingDatabaseChanges: [
                        .saveZone(CKRecordZone(zoneID: failedRecordSave.record.recordID.zoneID))
                    ])
                }
                clearSystemFields(for: failedRecordSave.record.recordID)
                privateSyncEngine?.state.add(pendingRecordZoneChanges: [
                    .saveRecord(failedRecordSave.record.recordID)
                ])
            case .waitForAutomaticRetry, .fail:
                recordUploadFailure(for: failedRecordSave.record.recordID, error: failedRecordSave.error)
            }
        }

        for (recordID, error) in event.failedRecordDeletes {
            recordUploadFailure(for: recordID, error: error)
        }

        store.publishOwnerProfile()
        store.persistCache(immediately: true)
        store.setSyncState(.idle)
        AppLog.sync.info("Finished CloudKit upload handling")
    }

    private func recordUploadFailure(for recordID: CKRecord.ID, error: CKError) {
        guard let store else { return }
        if let record = FestivalProfileCloudRecordMapper.syncRecord(for: recordID) {
            store.recordUploadFailure(for: record, message: error.localizedDescription)
        } else {
            store.setSyncState(.error(error.localizedDescription))
        }
    }

    private func databaseKind(for syncEngine: CKSyncEngine) -> DatabaseKind {
        if let privateSyncEngine, privateSyncEngine === syncEngine {
            return .owner
        }
        return .shared
    }

    private func enqueuePendingChanges(
        forTransitionFrom oldProfile: CachedOwnerFestivalProfile,
        to newProfile: CachedOwnerFestivalProfile
    ) {
        guard let store, privateSyncEngine != nil else { return }
        let plannedChanges = FestivalProfileSyncPlanner.changes(
            from: oldProfile,
            to: newProfile
        )
        let pendingChanges = plannedChanges.map(pendingRecordZoneChange)

        enqueueOwnerChanges(pendingChanges)
        AppLog.sync.info(
            "Queued \(pendingChanges.count) CloudKit pending changes from local mutation: \(store.profileTransitionSummary(from: oldProfile, to: newProfile), privacy: .public)"
        )
    }

    private func enqueueFullUploadForCurrentProfile() {
        guard let store, privateSyncEngine != nil else { return }
        let plannedChanges = FestivalProfileSyncPlanner.fullUpload(for: store.cacheSnapshot.currentProfile)
        store.updateCache { cache in
            cache.pendingProfileRecords = (cache.pendingProfileRecords ?? []).union(cache.currentProfile.syncRecords).union([.profile])
        }
        let pendingChanges = plannedChanges.map(pendingRecordZoneChange)
        enqueueOwnerChanges(pendingChanges)
        AppLog.sync.info(
            "Queued full CloudKit upload with \(pendingChanges.count) records for snapshot \(self.syncSnapshotSummary(for: store), privacy: .public)"
        )
    }

    private func enqueueOwnerChanges(_ changes: [CKSyncEngine.PendingRecordZoneChange]) {
        guard let privateSyncEngine else { return }
        privateSyncEngine.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: profileZoneID)),
            .saveZone(CKRecordZone(zoneID: notesZoneID))
        ])
        privateSyncEngine.state.add(pendingRecordZoneChanges: changes)
    }

    private func pendingRecordZoneChange(
        for change: FestivalProfileSyncChange
    ) -> CKSyncEngine.PendingRecordZoneChange {
        switch change {
        case .save(let record):
            return .saveRecord(recordID(for: record))
        case .delete(let record):
            return .deleteRecord(recordID(for: record))
        }
    }

    private func recordID(for record: FestivalProfileSyncRecord) -> CKRecord.ID {
        FestivalProfileCloudRecordMapper.recordID(for: record)
    }

    private func mergeOwnerRecordFromServer(_ record: CKRecord) {
        guard let store else { return }
        guard let payload = FestivalProfileCloudRecordMapper.payload(from: record) else {
            return
        }

        switch payload {
        case .profile(let festivalYear, _, let badgeName, let badgeColorHex):
            store.updateCache { cache in
                cache.currentProfile.festivalYear = festivalYear
                cache.currentProfile.badgeName = badgeName
                cache.currentProfile.badgeColorHex = badgeColorHex
                cache.currentProfile.shareRecordName = record.share?.recordID.recordName
                cache.currentProfile.rootRecordSystemFieldsData = FestivalProfileCloudRecordMapper.encodeSystemFields(for: record)
            }
        case .change(let change):
            updateSystemFields(from: record)
            if store.mergeRemoteChange(change) {
                privateSyncEngine?.state.add(pendingRecordZoneChanges: [.saveRecord(record.recordID)])
            }
        }
    }

    private func handleOwnerDeletion(recordID: CKRecord.ID) {
        guard let store else { return }
        switch recordID.recordName {
        case profileRootRecordID().recordName:
            store.updateCache { cache in
                cache.currentProfile.shareRecordName = nil
                cache.currentProfile.shareRecordSystemFieldsData = nil
                cache.currentProfile.rootRecordSystemFieldsData = nil
            }
        default:
            guard let record = FestivalProfileCloudRecordMapper.syncRecord(for: recordID) else { return }
            clearSystemFields(for: recordID)
            if store.mergeLegacyDeletion(for: record) {
                privateSyncEngine?.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }
        }
    }

    private func updateSystemFields(from record: CKRecord) {
        store?.updateCache { cache in
            FestivalProfileCloudRecordMapper.updateSystemFields(from: record, in: &cache.currentProfile)
        }
    }

    private func clearSystemFields(for recordID: CKRecord.ID) {
        store?.updateCache { cache in
            FestivalProfileCloudRecordMapper.clearSystemFields(for: recordID, in: &cache.currentProfile)
        }
    }

    private func recordToUpload(for recordID: CKRecord.ID) -> CKRecord? {
        guard let store,
              let syncRecord = FestivalProfileCloudRecordMapper.syncRecord(for: recordID),
              self.recordID(for: syncRecord) == recordID else { return nil }
        let record = FestivalProfileCloudRecordMapper.recordToUpload(
            for: syncRecord, from: store.cacheSnapshot.currentProfile, updatedAt: now()
        )
        if record == nil {
            privateSyncEngine?.state.remove(pendingRecordZoneChanges: [.saveRecord(recordID)])
        }
        return record
    }

    func ensureCurrentProfileExistsOnServer() async throws {
        AppLog.sync.info("Ensuring current festival profile exists on CloudKit server")
        enqueueFullUploadForCurrentProfile()
        if let privateSyncEngine {
            try await privateSyncEngine.sendChanges()
            try await privateSyncEngine.fetchChanges()
        }
        AppLog.sync.info("Confirmed current festival profile exists on CloudKit server")
    }

}
#endif
