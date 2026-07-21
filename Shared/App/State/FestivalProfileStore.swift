import Combine
import Foundation
import OSLog
#if os(iOS)
import CloudKit
#endif

@MainActor
final class FestivalProfileStore: ObservableObject {
    // MARK: - Constants

    enum Constants {
        static let legacyCacheKey = "festival-profile-cache-v1"
        static let migrationVersion = 1
        static let schemaVersion = 2
        static let localMutationSyncDelayNanoseconds: UInt64 = 750_000_000
        static let cloudKitContainerIdentifier = "iCloud.de.leongeorgi.RudolstadtForiOS"
        static let profileRecordType = "FestivalProfile"
        static let savedEventRecordType = "SavedEventPreference"
        static let artistPreferenceRecordType = "ArtistPreference"
        static let artistNoteRecordType = "ArtistNote"
        static let profileName = "My Festival Picks"
        static let profileZoneName = "FestivalProfileZone-\(DataStore.year)"
        static let notesZoneName = "FestivalProfileNotesZone-\(DataStore.year)"

        nonisolated static func cacheKey(for festivalYear: Int) -> String {
            "festival-profile-cache-\(festivalYear)-v1"
        }

        nonisolated static func legacySavedEventsKey(for festivalYear: Int) -> String {
            "\(festivalYear)/savedEvents"
        }

        nonisolated static func legacyRatingsKey(for festivalYear: Int) -> String {
            "\(festivalYear)/ratings"
        }

        nonisolated static func legacyArtistIconsKey(for festivalYear: Int) -> String {
            "\(festivalYear)/artistIcons"
        }

        nonisolated static func legacyArtistNotesKey(for festivalYear: Int) -> String {
            "\(festivalYear)/artistNotes"
        }
    }

    @Published private(set) var savedEvents: [Int] = []
    @Published private(set) var ratings: [String: Int] = [:]
    @Published private(set) var artistNotes: [String: String] = [:]
    @Published private(set) var badgeName: String = ""
    @Published private(set) var badgeColorHex: String = FestivalProfileBadge.defaultColorHex
    let syncStore = FestivalProfileSyncStore()
    private var savedEventIDSet = Set<Int>()
    @Published private var artistIconsByID: [String: String] = [:]

    private let cloudKitEnabled: Bool
    private let persistence: any FestivalProfilePersisting
    private let waitBeforePersisting: @Sendable () async -> Void
    private let now: () -> Date
    private var listeners: [FestivalProfileStoreChange: [() -> Void]] = [:]
    private var syncStoreObservation: AnyCancellable?
    private var cache: FestivalProfileCache
    private var pendingPersistTask: Task<Void, Never>?
    private var pendingOwnerSendTask: Task<Void, Never>?
    private var didObserveRemotePrivateDataDuringMigration = false
    private var didCompleteInitialPrivateFetch = false
    private var activeRefreshReason: String?

#if os(iOS)
    private lazy var container = CKContainer(identifier: Constants.cloudKitContainerIdentifier)
    private var privateSyncEngine: CKSyncEngine?
    private var sharedSyncEngine: CKSyncEngine?
#endif

    init(
        userDefaults: UserDefaults = .standard,
        cloudKitEnabled: Bool = FestivalProfileStore.defaultCloudKitEnabled,
        now: @escaping () -> Date = { .now },
        persistence: (any FestivalProfilePersisting)? = nil,
        waitBeforePersisting: @escaping @Sendable () async -> Void = {
            try? await Task.sleep(for: .milliseconds(250))
        }
    ) {
        let persistence = persistence
            ?? UserDefaultsFestivalProfilePersistence(
                userDefaults: userDefaults,
                festivalYear: DataStore.year
            )
        self.cloudKitEnabled = cloudKitEnabled
        self.now = now
        self.persistence = persistence
        self.waitBeforePersisting = waitBeforePersisting
        self.cache = persistence.loadCache()
            ?? FestivalProfileCache(
                currentProfile: persistence.loadLegacyOwnerProfile(),
                sharedProfiles: [],
                migrationVersion: 0,
                lastSuccessfulRefreshDate: nil,
                privateStateSerializationData: nil,
                sharedStateSerializationData: nil
            )
        observeSyncStore()
        applyCurrentProfile(cache.currentProfile)
        applyAcceptedFriendProfiles()
        syncStore.lastSuccessfulRefreshDate = cache.lastSuccessfulRefreshDate
        syncStore.shareState = cache.currentProfile.shareRecordName == nil ? .notShared : .shared
#if os(iOS)
        if let cachedShare = cachedShare() {
            applyAcceptedShareParticipants(from: cachedShare)
        }
#endif
        AppLog.sync.info(
            "Loaded festival profile cache with \(self.savedEvents.count) saved events, \(self.ratings.count) ratings, and \(self.acceptedFriendProfiles.count) shared profiles"
        )

#if os(iOS)
        if cloudKitEnabled {
            configureSyncEngines()
            Task {
                await refreshAccountStatus()
                await performInitialFetchIfNeeded()
            }
        } else {
            setICloudStatus(.unavailable("Cloud sync disabled"))
        }
#else
        setICloudStatus(.unavailable("Cloud sync is only available on iOS"))
#endif
    }

    nonisolated static var defaultCloudKitEnabled: Bool {
        !ScreenshotRuntime.isEnabled
            && ProcessInfo.processInfo.environment[
                "XCTestConfigurationFilePath"
            ] == nil
            && ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
    }

    deinit {
        syncStoreObservation?.cancel()
        pendingPersistTask?.cancel()
        pendingOwnerSendTask?.cancel()
    }

    // MARK: - Public API

    func onChange(
        of change: FestivalProfileStoreChange,
        perform listener: @escaping () -> Void
    ) {
        listeners[change, default: []].append(listener)
    }

    private func observeSyncStore() {
        syncStoreObservation = syncStore.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func toggleSavedEvent(_ event: Event) {
        updateCurrentProfile(.toggleSavedEvent(eventID: event.id))
    }

    func idFor(event: Event) -> String {
        "\(event.id)-\(isEventSaved(event.id))"
    }

    func isEventSaved(_ eventID: Int) -> Bool {
        savedEventIDSet.contains(eventID)
    }

    func friendProfilesSavingEvent(_ eventID: Int) -> [SharedFestivalProfile] {
        acceptedFriendProfiles
            .filter { $0.savedEventIDs.contains(eventID) }
            .sorted { lhs, rhs in
                lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }
    }

    func friendArtistRatingSummary(for artistID: Int) -> FriendArtistRatingSummary? {
        let entries = acceptedFriendProfiles
            .sorted { lhs, rhs in
                lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }
            .compactMap { sharedProfile -> FriendArtistRatingSummary.Entry? in
                guard let preference = sharedProfile.artistPreferences.first(where: { preference in
                    preference.artistID == artistID && preference.rating != 0
                }) else {
                    return nil
                }

                return FriendArtistRatingSummary.Entry(
                    profileID: sharedProfile.id,
                    badge: sharedProfile.badge,
                    preference: preference
                )
            }

        guard !entries.isEmpty else {
            return nil
        }

        return FriendArtistRatingSummary(entries: entries)
    }

    func rating(for artistID: Int) -> Int {
        ratings[String(artistID)] ?? 0
    }

    func iconName(forArtistID artistID: Int) -> String? {
        artistIconsByID[String(artistID)]
    }

    var acceptedFriendProfiles: [SharedFestivalProfile] {
        syncStore.acceptedFriendProfiles
    }

    var iCloudStatus: FestivalProfileICloudStatus {
        syncStore.iCloudStatus
    }

    var syncState: FestivalProfileSyncState {
        syncStore.syncState
    }

    var shareState: FestivalProfileShareState {
        syncStore.shareState
    }

    var isPreparingShare: Bool {
        syncStore.isPreparingShare
    }

    var ownerBadge: FestivalProfileBadge {
        FestivalProfileBadge.ownerBadge(
            rawName: badgeName,
            rawColorHex: badgeColorHex
        )
    }

    func updateBadge(name: String, colorHex: String) {
        updateCurrentProfile(.updateBadge(name: name, colorHex: colorHex))
    }

    func setArtistRating(for artist: Artist, rating: Int) {
        updateCurrentProfile(.setArtistRating(artistID: artist.id, rating: rating))
    }

    func getArtistIcon(for artist: Artist) -> String? {
        iconName(forArtistID: artist.id)
    }

    func setArtistIcon(for artist: Artist, icon: String) {
        updateCurrentProfile(.setArtistIcon(artistID: artist.id, iconName: icon))
    }

    func noteText(for artist: Artist) -> String? {
        artistNotes[String(artist.id)]
    }

    func setArtistNote(for artist: Artist, note: String) {
        setArtistNote(forArtistID: artist.id, note: note)
    }

    func setArtistNote(forArtistID artistID: Int, note: String) {
        updateCurrentProfile(.setArtistNote(artistID: artistID, noteText: note))
    }

    func refreshFromCloud(reason: String = "manual") async {
#if os(iOS)
        guard cloudKitEnabled else {
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
        guard case .available = iCloudStatus else {
            AppLog.sync.info(
                "Skipped \(reason, privacy: .public) iCloud refresh because iCloud is \(self.iCloudStatus.logDescription, privacy: .public)"
            )
            return
        }
        setSyncState(.syncing)
        do {
            if let privateSyncEngine {
                try await privateSyncEngine.sendChanges()
                try await privateSyncEngine.fetchChanges()
            }
            if let sharedSyncEngine {
                try await sharedSyncEngine.fetchChanges()
            }
            try await refreshCurrentShareParticipants()
            let refreshDate = now()
            syncStore.lastSuccessfulRefreshDate = refreshDate
            cache.lastSuccessfulRefreshDate = refreshDate
            persistCache()
            setSyncState(.idle)
            AppLog.sync.info("Finished \(reason, privacy: .public) iCloud refresh")
        } catch {
            setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "\(reason, privacy: .public) iCloud refresh failed: \(error.localizedDescription, privacy: .public)"
            )
        }
#endif
    }

#if os(iOS)
    // MARK: - Sharing

    func prepareShare() async throws -> CKShare {
        guard cloudKitEnabled else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cloud sync is disabled."]
            )
        }

        AppLog.sync.info("Preparing CloudKit share for the current festival profile")

        await refreshAccountStatus()
        guard case .available = iCloudStatus else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "iCloud is not available."]
            )
        }

        syncStore.isPreparingShare = true
        defer {
            syncStore.isPreparingShare = false
        }

        try await ensureCurrentProfileExistsOnServer()

        if let shareRecordName = cache.currentProfile.shareRecordName {
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
        guard cloudKitEnabled else {
            return
        }

        await refreshAccountStatus()
        guard case .available = iCloudStatus else {
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
        do {
            AppLog.sync.info("Accepting CloudKit share from system handoff")
            setSyncState(.syncing)
            try await acceptShares([metadata])
            if let sharedSyncEngine {
                try await sharedSyncEngine.fetchChanges()
            }
            setSyncState(.idle)
            AppLog.sync.info("Accepted CloudKit share successfully")
        } catch {
            setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "Failed to accept CloudKit share: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func acceptShare(url: URL) async throws {
        guard cloudKitEnabled else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Cloud sync is disabled."]
            )
        }

        await refreshAccountStatus()
        guard case .available = iCloudStatus else {
            throw NSError(
                domain: "FestivalProfileStore",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "iCloud is not available."]
            )
        }

        AppLog.sync.info("Accepting CloudKit share from URL")
        setSyncState(.syncing)

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

            if let sharedSyncEngine {
                try await sharedSyncEngine.fetchChanges()
            }

            setSyncState(.idle)
            AppLog.sync.info("Accepted CloudKit share URL successfully")
        } catch {
            setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "Failed to accept CloudKit share URL: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }
#endif

    // MARK: - Local State

    private func updateCurrentProfile(_ mutation: FestivalProfileMutation) {
        let oldProfile = cache.currentProfile
        cache.currentProfile = FestivalProfileReducer.applying(
            mutation,
            to: oldProfile
        )
        applyCurrentProfile(cache.currentProfile)
        persistCache()
        notifyRecommendationInputsChangedIfNeeded(old: oldProfile, new: cache.currentProfile)

#if os(iOS)
        guard cloudKitEnabled, cache.migrationVersion >= Constants.migrationVersion else {
            return
        }
        enqueuePendingChanges(forTransitionFrom: oldProfile, to: cache.currentProfile)
        schedulePendingOwnerSend()
#endif
    }

    private func applyCurrentProfile(_ profile: CachedOwnerFestivalProfile) {
        let updatedBadgeName = profile.badgeName ?? ""
        if badgeName != updatedBadgeName {
            badgeName = updatedBadgeName
        }

        let updatedBadgeColorHex = FestivalProfileBadge.resolvedColorHex(profile.badgeColorHex)
        if badgeColorHex != updatedBadgeColorHex {
            badgeColorHex = updatedBadgeColorHex
        }

        let updatedSavedEvents = profile.savedEventIDs
        savedEventIDSet = Set(updatedSavedEvents)
        if savedEvents != updatedSavedEvents {
            savedEvents = updatedSavedEvents
        }

        let updatedRatings = Dictionary(
            uniqueKeysWithValues: profile.artistPreferences.map { preference in
                (String(preference.artistID), preference.rating)
            }
        )
        if ratings != updatedRatings {
            ratings = updatedRatings
        }

        let updatedArtistIconsByID: [String: String] = Dictionary(
            uniqueKeysWithValues: profile.artistPreferences.compactMap { preference in
                guard let iconName = preference.iconName else {
                    return nil
                }
                return (String(preference.artistID), iconName)
            }
        )
        if artistIconsByID != updatedArtistIconsByID {
            artistIconsByID = updatedArtistIconsByID
        }

        let updatedArtistNotes = Dictionary(
            uniqueKeysWithValues: profile.artistNotes.map { note in
                (String(note.artistID), note.noteText)
            }
        )
        if artistNotes != updatedArtistNotes {
            artistNotes = updatedArtistNotes
        }

        let updatedShareState: FestivalProfileShareState =
            profile.shareRecordName == nil ? .notShared : .shared
        if syncStore.shareState != updatedShareState {
            syncStore.shareState = updatedShareState
        }
    }

    private func persistCache(immediately: Bool = false) {
        let cacheSnapshot = cache
        pendingPersistTask?.cancel()
        pendingPersistTask = Task { [persistence, waitBeforePersisting] in
            if !immediately {
                await waitBeforePersisting()
                guard !Task.isCancelled else {
                    return
                }
            }
            persistence.persist(cacheSnapshot)
        }
    }

    func flushPendingPersistence() async {
        await pendingPersistTask?.value
    }

    private func notifyRecommendationInputsChangedIfNeeded(
        old: CachedOwnerFestivalProfile,
        new: CachedOwnerFestivalProfile
    ) {
        guard
            old.savedEventIDs != new.savedEventIDs
                || old.artistPreferences != new.artistPreferences
        else {
            return
        }
        listeners[.recommendationInputs]?.forEach { listener in
            listener()
        }
    }

    private func cacheCurrentShare(_ share: CKShare) {
        cache.currentProfile.shareRecordName = share.recordID.recordName
        cache.currentProfile.shareRecordSystemFieldsData = encodeSystemFields(for: share)
        applyAcceptedShareParticipants(from: share)
        persistCache(immediately: true)
        if syncStore.shareState != .shared {
            syncStore.shareState = .shared
        }
        AppLog.sync.info("Cached CloudKit share \(share.recordID.recordName, privacy: .public)")
    }

    private func refreshCurrentShareParticipants() async throws {
        guard let shareRecordName = cache.currentProfile.shareRecordName else {
            applyAcceptedShareParticipantCount(0)
            return
        }

        let shareRecordID = CKRecord.ID(
            recordName: shareRecordName,
            zoneID: profileZoneID
        )
        guard let share = try await fetchShare(recordID: shareRecordID) else {
            cache.currentProfile.shareRecordName = nil
            cache.currentProfile.shareRecordSystemFieldsData = nil
            syncStore.shareState = .notShared
            applyAcceptedShareParticipantCount(0)
            persistCache(immediately: true)
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
        guard syncStore.acceptedShareParticipantCount != count else {
            return
        }

        syncStore.acceptedShareParticipantCount = count
        AppLog.sync.info(
            "Accepted share participants updated to \(count) participants"
        )
    }

    private func applyAcceptedFriendProfiles() {
        let updatedProfiles = cache.sharedProfiles
            .map(Self.makeSharedProfile)
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        if syncStore.acceptedFriendProfiles != updatedProfiles {
            syncStore.acceptedFriendProfiles = updatedProfiles
            AppLog.sync.info(
                "Accepted shared profiles updated to \(updatedProfiles.count) profiles"
            )
        }
    }

    private func setICloudStatus(_ newStatus: FestivalProfileICloudStatus) {
        if syncStore.iCloudStatus != newStatus {
            syncStore.iCloudStatus = newStatus
            AppLog.sync.info(
                "iCloud status changed to \(newStatus.logDescription, privacy: .public)"
            )
        }
    }

    private func setSyncState(_ newState: FestivalProfileSyncState) {
        if syncStore.syncState != newState {
            syncStore.syncState = newState
            if case .error(let reason) = newState {
                AppLog.sync.error(
                    "Cloud sync state changed to error: \(reason, privacy: .public)"
                )
            }
        }
    }

}

#if os(iOS)
@MainActor
extension FestivalProfileStore: CKSyncEngineDelegate {
    // MARK: - CloudKit Sync

    private enum DatabaseKind {
        case owner
        case shared

        var logDescription: String {
            switch self {
            case .owner:
                return "owner"
            case .shared:
                return "shared"
            }
        }
    }

    private func syncSnapshotSummary() -> String {
        "savedEvents=\(cache.currentProfile.savedEventIDs.count), ratings=\(cache.currentProfile.artistPreferences.count), notes=\(cache.currentProfile.artistNotes.count), friends=\(cache.sharedProfiles.count), shareState=\(shareState.logDescription)"
    }

    private var profileZoneID: CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: Constants.profileZoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    private var notesZoneID: CKRecordZone.ID {
        CKRecordZone.ID(
            zoneName: Constants.notesZoneName,
            ownerName: CKCurrentUserDefaultName
        )
    }

    private func profileRootRecordID(
        zoneID: CKRecordZone.ID? = nil
    ) -> CKRecord.ID {
        FestivalProfileCloudRecordMapper.recordID(
            for: .profile,
            profileZoneID: zoneID ?? profileZoneID,
            notesZoneID: notesZoneID
        )
    }

    private func savedEventRecordID(
        eventID: Int,
        zoneID: CKRecordZone.ID? = nil
    ) -> CKRecord.ID {
        FestivalProfileCloudRecordMapper.recordID(
            for: .savedEvent(eventID: eventID),
            profileZoneID: zoneID ?? profileZoneID,
            notesZoneID: notesZoneID
        )
    }

    private func artistPreferenceRecordID(
        artistID: Int,
        zoneID: CKRecordZone.ID? = nil
    ) -> CKRecord.ID {
        FestivalProfileCloudRecordMapper.recordID(
            for: .artistPreference(artistID: artistID),
            profileZoneID: zoneID ?? profileZoneID,
            notesZoneID: notesZoneID
        )
    }

    private func artistNoteRecordID(artistID: Int) -> CKRecord.ID {
        FestivalProfileCloudRecordMapper.recordID(
            for: .artistNote(artistID: artistID),
            profileZoneID: profileZoneID,
            notesZoneID: notesZoneID
        )
    }

    private func configureSyncEngines() {
        let privateConfiguration = CKSyncEngine.Configuration(
            database: container.privateCloudDatabase,
            stateSerialization: decodeStateSerialization(from: cache.privateStateSerializationData),
            delegate: self
        )
        privateSyncEngine = CKSyncEngine(privateConfiguration)

        let sharedConfiguration = CKSyncEngine.Configuration(
            database: container.sharedCloudDatabase,
            stateSerialization: decodeStateSerialization(from: cache.sharedStateSerializationData),
            delegate: self
        )
        sharedSyncEngine = CKSyncEngine(sharedConfiguration)
        AppLog.sync.info("Configured CloudKit sync engines")
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
        guard cloudKitEnabled else {
            return
        }
        guard activeRefreshReason == nil else {
            return
        }
        guard case .available = iCloudStatus else {
            return
        }
        guard let privateSyncEngine else {
            return
        }

        do {
            setSyncState(.syncing)
            try await privateSyncEngine.sendChanges()
            setSyncState(.idle)
            AppLog.sync.info("Sent pending owner CloudKit changes")
        } catch {
            setSyncState(.error(error.localizedDescription))
            AppLog.sync.error(
                "Sending pending owner CloudKit changes failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func performInitialFetchIfNeeded() async {
        guard case .available = iCloudStatus else {
            return
        }
        await refreshFromCloud(reason: "initial")
    }

    private func refreshAccountStatus() async {
        do {
            let accountStatus = try await fetchAccountStatus()
            switch accountStatus {
            case .available:
                setICloudStatus(.available)
            case .couldNotDetermine:
                setICloudStatus(.unavailable("Could not determine your iCloud status."))
            case .noAccount:
                setICloudStatus(.unavailable("Sign in to iCloud to sync your festival profile."))
            case .restricted:
                setICloudStatus(.unavailable("iCloud sync is restricted on this device."))
            case .temporarilyUnavailable:
                setICloudStatus(.unavailable("iCloud is temporarily unavailable."))
            @unknown default:
                setICloudStatus(.unavailable("iCloud is unavailable right now."))
            }
        } catch {
            setICloudStatus(.unavailable(error.localizedDescription))
        }
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
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
        case .sentDatabaseChanges(_):
            setSyncState(.idle)
        case .didFetchChanges(_):
            handleDidFetchChanges(databaseKind: databaseKind)
        case .willFetchChanges(_),
             .willFetchRecordZoneChanges(_),
             .didFetchRecordZoneChanges(_),
             .willSendChanges(_),
             .didSendChanges(_):
            setSyncState(.syncing)
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
            guard let self else {
                return nil
            }
            return await self.recordToUpload(for: recordID)
        }
    }

    private func handleStateUpdate(
        _ event: CKSyncEngine.Event.StateUpdate,
        databaseKind: DatabaseKind
    ) {
        switch databaseKind {
        case .owner:
            cache.privateStateSerializationData = encodeStateSerialization(event.stateSerialization)
        case .shared:
            cache.sharedStateSerializationData = encodeStateSerialization(event.stateSerialization)
        }
        persistCache(immediately: true)
    }

    private func handleDidFetchChanges(databaseKind: DatabaseKind) {
        guard databaseKind == .owner else {
            setSyncState(.idle)
            return
        }

        if cache.migrationVersion < Constants.migrationVersion && !didCompleteInitialPrivateFetch {
            didCompleteInitialPrivateFetch = true
            if !didObserveRemotePrivateDataDuringMigration {
                cache.migrationVersion = Constants.migrationVersion
                enqueueFullUploadForCurrentProfile()
                AppLog.sync.info(
                    "No remote CloudKit data was found during migration; queued full profile upload"
                )
            } else {
                cache.migrationVersion = Constants.migrationVersion
            }
            persistCache(immediately: true)
        }

        setSyncState(.idle)
    }

    private func handleFetchedDatabaseChanges(
        _ event: CKSyncEngine.Event.FetchedDatabaseChanges,
        databaseKind: DatabaseKind
    ) {
        switch databaseKind {
        case .owner:
            for deletion in event.deletions {
                if deletion.zoneID == profileZoneID {
                    cache.currentProfile.rootRecordSystemFieldsData = nil
                    cache.currentProfile.savedEventRecordSystemFieldsByName = [:]
                    cache.currentProfile.artistPreferenceRecordSystemFieldsByName = [:]
                    cache.currentProfile.shareRecordName = nil
                    cache.currentProfile.shareRecordSystemFieldsData = nil
                    enqueueFullUploadForCurrentProfile()
                } else if deletion.zoneID == notesZoneID {
                    cache.currentProfile.artistNoteRecordSystemFieldsByName = [:]
                    enqueueFullUploadForCurrentProfile()
                }
            }
            applyCurrentProfile(cache.currentProfile)
            persistCache(immediately: true)
            if !event.deletions.isEmpty {
                AppLog.sync.info("Applied \(event.deletions.count) owner database deletions")
            }
        case .shared:
            guard !event.deletions.isEmpty else {
                return
            }
            let deletedSharedProfileIDs = Set(
                event.deletions.map { deletion in
                    self.sharedProfileID(for: deletion.zoneID)
                }
            )
            cache.sharedProfiles.removeAll { sharedProfile in
                deletedSharedProfileIDs.contains(sharedProfile.id)
            }
            applyAcceptedFriendProfiles()
            persistCache(immediately: true)
            AppLog.sync.info("Applied \(event.deletions.count) shared database deletions")
        }
    }

    private func handleFetchedRecordZoneChanges(
        _ event: CKSyncEngine.Event.FetchedRecordZoneChanges,
        databaseKind: DatabaseKind
    ) {
        guard !event.modifications.isEmpty || !event.deletions.isEmpty else {
            return
        }
        switch databaseKind {
        case .owner:
            for modification in event.modifications {
                didObserveRemotePrivateDataDuringMigration = true
                mergeOwnerRecordFromServer(modification.record)
            }
            for deletion in event.deletions {
                didObserveRemotePrivateDataDuringMigration = true
                handleOwnerDeletion(recordID: deletion.recordID)
            }
            applyCurrentProfile(cache.currentProfile)
            persistCache(immediately: true)
            AppLog.sync.info(
                "Applied \(event.modifications.count) owner record changes and \(event.deletions.count) deletions"
            )
        case .shared:
            for modification in event.modifications {
                mergeSharedRecordFromServer(modification.record)
            }
            for deletion in event.deletions {
                handleSharedDeletion(recordID: deletion.recordID)
            }
            applyAcceptedFriendProfiles()
            persistCache(immediately: true)
            AppLog.sync.info(
                "Applied \(event.modifications.count) shared record changes and \(event.deletions.count) deletions"
            )
        }
    }

    private func handleSentRecordZoneChanges(
        _ event: CKSyncEngine.Event.SentRecordZoneChanges
    ) {
        AppLog.sync.info(
            "Uploaded \(event.savedRecords.count) CloudKit records with \(event.failedRecordSaves.count) failures"
        )
        for savedRecord in event.savedRecords {
            updateSystemFields(forSavedRecord: savedRecord)
        }

        for failedRecordSave in event.failedRecordSaves {
            AppLog.sync.error(
                "Failed to save CloudKit record \(failedRecordSave.record.recordID.recordName, privacy: .public): \(failedRecordSave.error.localizedDescription, privacy: .public)"
            )
            switch FestivalProfileSyncConflictPolicy.action(
                for: failedRecordSave.error.code
            ) {
            case .mergeServerRecord:
                if let serverRecord = failedRecordSave.error.serverRecord {
                    mergeOwnerRecordFromServer(serverRecord)
                }
            case .recreateZoneAndRetry:
                privateSyncEngine?.state.add(pendingDatabaseChanges: [
                    .saveZone(CKRecordZone(zoneID: failedRecordSave.record.recordID.zoneID))
                ])
                clearSystemFields(for: failedRecordSave.record.recordID)
                privateSyncEngine?.state.add(pendingRecordZoneChanges: [
                    .saveRecord(failedRecordSave.record.recordID)
                ])
            case .retryWithoutSystemFields:
                clearSystemFields(for: failedRecordSave.record.recordID)
                privateSyncEngine?.state.add(pendingRecordZoneChanges: [
                    .saveRecord(failedRecordSave.record.recordID)
                ])
            case .waitForAutomaticRetry:
                break
            case .fail:
                setSyncState(.error(failedRecordSave.error.localizedDescription))
            }
        }

        applyCurrentProfile(cache.currentProfile)
        persistCache(immediately: true)
        setSyncState(.idle)
        AppLog.sync.info("Finished CloudKit upload handling")
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
        guard let privateSyncEngine else {
            return
        }

        privateSyncEngine.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: profileZoneID)),
            .saveZone(CKRecordZone(zoneID: notesZoneID))
        ])

        let plannedChanges = FestivalProfileSyncPlanner.changes(
            from: oldProfile,
            to: newProfile
        )
        let pendingChanges = plannedChanges.map(pendingRecordZoneChange)

        privateSyncEngine.state.add(pendingRecordZoneChanges: pendingChanges)
        AppLog.sync.info(
            "Queued \(pendingChanges.count) CloudKit pending changes from local mutation: \(self.profileTransitionSummary(from: oldProfile, to: newProfile), privacy: .public)"
        )
    }

    private func enqueueFullUploadForCurrentProfile() {
        guard let privateSyncEngine else {
            return
        }

        privateSyncEngine.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: profileZoneID)),
            .saveZone(CKRecordZone(zoneID: notesZoneID))
        ])

        let plannedChanges = FestivalProfileSyncPlanner.fullUpload(for: cache.currentProfile)
        let pendingChanges = plannedChanges.map(pendingRecordZoneChange)
        privateSyncEngine.state.add(pendingRecordZoneChanges: pendingChanges)
        AppLog.sync.info(
            "Queued full CloudKit upload with \(pendingChanges.count) records for snapshot \(self.syncSnapshotSummary(), privacy: .public)"
        )
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
        FestivalProfileCloudRecordMapper.recordID(
            for: record,
            profileZoneID: profileZoneID,
            notesZoneID: notesZoneID
        )
    }

    private func mergeOwnerRecordFromServer(_ record: CKRecord) {
        guard let payload = FestivalProfileCloudRecordMapper.payload(from: record) else {
            return
        }

        switch payload {
        case .profile(let festivalYear, _, let badgeName, let badgeColorHex):
            cache.currentProfile.festivalYear = festivalYear
            cache.currentProfile.badgeName = badgeName
            cache.currentProfile.badgeColorHex = badgeColorHex
            cache.currentProfile.shareRecordName = record.share?.recordID.recordName
            cache.currentProfile.rootRecordSystemFieldsData = encodeSystemFields(for: record)
        case .savedEvent(let eventID):
            if !cache.currentProfile.savedEventIDs.contains(eventID) {
                cache.currentProfile.savedEventIDs.append(eventID)
                cache.currentProfile.savedEventIDs.sort()
            }
            cache.currentProfile.savedEventRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
        case .artistPreference(let preference):
            var preferences = Self.artistPreferencesDictionary(from: cache.currentProfile.artistPreferences)
            preferences[String(preference.artistID)] = preference
            cache.currentProfile.artistPreferences = preferences.values.sorted { lhs, rhs in
                lhs.artistID < rhs.artistID
            }
            cache.currentProfile.artistPreferenceRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
        case .artistNote(let note):
            var notes = Dictionary(
                uniqueKeysWithValues: cache.currentProfile.artistNotes.map { note in
                    (note.artistID, note)
                }
            )
            notes[note.artistID] = note
            cache.currentProfile.artistNotes = notes.values.sorted { lhs, rhs in
                lhs.artistID < rhs.artistID
            }
            cache.currentProfile.artistNoteRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
        }
    }

    private func mergeSharedRecordFromServer(_ record: CKRecord) {
        guard let payload = FestivalProfileCloudRecordMapper.payload(from: record) else {
            return
        }
        let sharedProfileID = sharedProfileID(for: record.recordID.zoneID)
        var sharedProfile = cache.sharedProfiles.first(where: { $0.id == sharedProfileID })
            ?? CachedSharedFestivalProfile(
                id: sharedProfileID,
                title: Constants.profileName,
                ownerName: friendlyOwnerName(for: record.recordID.zoneID),
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
        case .savedEvent(let eventID):
            if !sharedProfile.savedEventIDs.contains(eventID) {
                sharedProfile.savedEventIDs.append(eventID)
                sharedProfile.savedEventIDs.sort()
            }
        case .artistPreference(let preference):
            var preferences = Dictionary(
                uniqueKeysWithValues: sharedProfile.artistPreferences.map { preference in
                    (preference.artistID, preference)
                }
            )
            preferences[preference.artistID] = preference
            sharedProfile.artistPreferences = preferences.values.sorted { lhs, rhs in
                lhs.artistID < rhs.artistID
            }
        case .artistNote:
            break
        }

        cache.sharedProfiles.removeAll { $0.id == sharedProfileID }
        cache.sharedProfiles.append(sharedProfile)
    }

    private func handleOwnerDeletion(recordID: CKRecord.ID) {
        switch recordID.recordName {
        case profileRootRecordID().recordName:
            cache.currentProfile.shareRecordName = nil
            cache.currentProfile.shareRecordSystemFieldsData = nil
            cache.currentProfile.rootRecordSystemFieldsData = nil
        default:
            if recordID.zoneID == profileZoneID {
                if isSavedEventRecord(recordID.recordName) {
                    let eventID = eventIDFromRecordName(recordID.recordName)
                    cache.currentProfile.savedEventIDs.removeAll { $0 == eventID }
                    cache.currentProfile.savedEventRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
                } else if isArtistPreferenceRecord(recordID.recordName) {
                    let artistID = artistIDFromRecordName(recordID.recordName)
                    cache.currentProfile.artistPreferences.removeAll { preference in
                        preference.artistID == artistID
                    }
                    cache.currentProfile.artistPreferenceRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
                }
            } else if recordID.zoneID == notesZoneID, isArtistNoteRecord(recordID.recordName) {
                let artistID = artistIDFromRecordName(recordID.recordName)
                cache.currentProfile.artistNotes.removeAll { note in
                    note.artistID == artistID
                }
                cache.currentProfile.artistNoteRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
            }
        }
    }

    private func handleSharedDeletion(recordID: CKRecord.ID) {
        let sharedProfileID = sharedProfileID(for: recordID.zoneID)
        guard var sharedProfile = cache.sharedProfiles.first(where: { $0.id == sharedProfileID }) else {
            return
        }

        switch recordID.recordName {
        case profileRootRecordID(zoneID: recordID.zoneID).recordName:
            cache.sharedProfiles.removeAll { $0.id == sharedProfileID }
            return
        default:
            if isSavedEventRecord(recordID.recordName) {
                let eventID = eventIDFromRecordName(recordID.recordName)
                sharedProfile.savedEventIDs.removeAll { $0 == eventID }
            } else if isArtistPreferenceRecord(recordID.recordName) {
                let artistID = artistIDFromRecordName(recordID.recordName)
                sharedProfile.artistPreferences.removeAll { preference in
                    preference.artistID == artistID
                }
            }
        }

        cache.sharedProfiles.removeAll { $0.id == sharedProfileID }
        cache.sharedProfiles.append(sharedProfile)
    }

    private func updateSystemFields(forSavedRecord record: CKRecord) {
        switch record.recordType {
        case Constants.profileRecordType:
            cache.currentProfile.rootRecordSystemFieldsData = encodeSystemFields(for: record)
            cache.currentProfile.shareRecordName = record.share?.recordID.recordName
        case Constants.savedEventRecordType:
            cache.currentProfile.savedEventRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
        case Constants.artistPreferenceRecordType:
            cache.currentProfile.artistPreferenceRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
        case Constants.artistNoteRecordType:
            cache.currentProfile.artistNoteRecordSystemFieldsByName[record.recordID.recordName] = encodeSystemFields(for: record)
        default:
            break
        }
    }

    private func clearSystemFields(for recordID: CKRecord.ID) {
        switch recordID.zoneID {
        case profileZoneID:
            if recordID == profileRootRecordID() {
                cache.currentProfile.rootRecordSystemFieldsData = nil
            } else {
                cache.currentProfile.savedEventRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
                cache.currentProfile.artistPreferenceRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
            }
        case notesZoneID:
            cache.currentProfile.artistNoteRecordSystemFieldsByName.removeValue(forKey: recordID.recordName)
        default:
            break
        }
    }

    private func recordToUpload(for recordID: CKRecord.ID) -> CKRecord? {
        if recordID.zoneID == profileZoneID {
            if recordID == profileRootRecordID() {
                return makeProfileRootRecord(recordID: recordID)
            }

            if let eventID = cache.currentProfile.savedEventIDs.first(where: { candidate in
                savedEventRecordID(eventID: candidate).recordName == recordID.recordName
            }) {
                return makeSavedEventRecord(eventID: eventID, recordID: recordID)
            }

            if let preference = cache.currentProfile.artistPreferences.first(where: { candidate in
                artistPreferenceRecordID(artistID: candidate.artistID).recordName == recordID.recordName
            }) {
                return makeArtistPreferenceRecord(preference: preference, recordID: recordID)
            }
        }

        if recordID.zoneID == notesZoneID,
           let note = cache.currentProfile.artistNotes.first(where: { candidate in
               artistNoteRecordID(artistID: candidate.artistID).recordName == recordID.recordName
           }) {
            return makeArtistNoteRecord(note: note, recordID: recordID)
        }

        privateSyncEngine?.state.remove(pendingRecordZoneChanges: [
            .saveRecord(recordID)
        ])
        return nil
    }

    private func makeProfileRootRecord(recordID: CKRecord.ID) -> CKRecord {
        let record = restoreRecord(
            from: cache.currentProfile.rootRecordSystemFieldsData,
            recordType: Constants.profileRecordType,
            recordID: recordID
        )
        return FestivalProfileCloudRecordMapper.populate(
            record,
            for: .profile,
            from: cache.currentProfile,
            updatedAt: now(),
            profileRootRecordID: recordID
        ) ?? record
    }

    private func makeSavedEventRecord(eventID: Int, recordID: CKRecord.ID) -> CKRecord {
        let record = restoreRecord(
            from: cache.currentProfile.savedEventRecordSystemFieldsByName[recordID.recordName],
            recordType: Constants.savedEventRecordType,
            recordID: recordID
        )
        return FestivalProfileCloudRecordMapper.populate(
            record,
            for: .savedEvent(eventID: eventID),
            from: cache.currentProfile,
            updatedAt: now(),
            profileRootRecordID: profileRootRecordID()
        ) ?? record
    }

    private func makeArtistPreferenceRecord(
        preference: FestivalArtistPreference,
        recordID: CKRecord.ID
    ) -> CKRecord {
        let record = restoreRecord(
            from: cache.currentProfile.artistPreferenceRecordSystemFieldsByName[recordID.recordName],
            recordType: Constants.artistPreferenceRecordType,
            recordID: recordID
        )
        return FestivalProfileCloudRecordMapper.populate(
            record,
            for: .artistPreference(artistID: preference.artistID),
            from: cache.currentProfile,
            updatedAt: now(),
            profileRootRecordID: profileRootRecordID()
        ) ?? record
    }

    private func makeArtistNoteRecord(
        note: FestivalArtistNote,
        recordID: CKRecord.ID
    ) -> CKRecord {
        let record = restoreRecord(
            from: cache.currentProfile.artistNoteRecordSystemFieldsByName[recordID.recordName],
            recordType: Constants.artistNoteRecordType,
            recordID: recordID
        )
        return FestivalProfileCloudRecordMapper.populate(
            record,
            for: .artistNote(artistID: note.artistID),
            from: cache.currentProfile,
            updatedAt: now(),
            profileRootRecordID: profileRootRecordID()
        ) ?? record
    }

    private func friendlyOwnerName(for zoneID: CKRecordZone.ID) -> String? {
        zoneID.ownerName == CKCurrentUserDefaultName ? nil : zoneID.ownerName
    }

    private func sharedProfileID(for zoneID: CKRecordZone.ID) -> String {
        "\(zoneID.ownerName)|\(zoneID.zoneName)"
    }

    private func isSavedEventRecord(_ recordName: String) -> Bool {
        recordName.hasPrefix("SavedEvent-")
    }

    private func isArtistPreferenceRecord(_ recordName: String) -> Bool {
        recordName.hasPrefix("ArtistPreference-")
    }

    private func isArtistNoteRecord(_ recordName: String) -> Bool {
        recordName.hasPrefix("ArtistNote-")
    }

    private func eventIDFromRecordName(_ recordName: String) -> Int {
        Int(recordName.split(separator: "-").last ?? "") ?? 0
    }

    private func artistIDFromRecordName(_ recordName: String) -> Int {
        Int(recordName.split(separator: "-").last ?? "") ?? 0
    }

    private func encodeStateSerialization(
        _ serialization: CKSyncEngine.State.Serialization
    ) -> Data? {
        try? JSONEncoder().encode(serialization)
    }

    private func decodeStateSerialization(
        from data: Data?
    ) -> CKSyncEngine.State.Serialization? {
        guard let data else {
            return nil
        }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func encodeSystemFields(for record: CKRecord) -> Data? {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: archiver)
        archiver.finishEncoding()
        return archiver.encodedData
    }

    private func restoreRecord(
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

    private func restoreSystemFieldsRecord(from systemFieldsData: Data) -> CKRecord? {
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

    func cachedShare() -> CKShare? {
        guard let shareSystemFieldsData = cache.currentProfile.shareRecordSystemFieldsData else {
            return nil
        }
        return restoreSystemFieldsRecord(from: shareSystemFieldsData) as? CKShare
    }

    private func fetchAccountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { accountStatus, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: accountStatus)
                }
            }
        }
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

    private func ensureCurrentProfileExistsOnServer() async throws {
        AppLog.sync.info("Ensuring current festival profile exists on CloudKit server")
        privateSyncEngine?.state.add(pendingDatabaseChanges: [
            .saveZone(CKRecordZone(zoneID: profileZoneID)),
            .saveZone(CKRecordZone(zoneID: notesZoneID))
        ])
        enqueueFullUploadForCurrentProfile()
        if let privateSyncEngine {
            try await privateSyncEngine.sendChanges()
            try await privateSyncEngine.fetchChanges()
        }
        AppLog.sync.info("Confirmed current festival profile exists on CloudKit server")
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
