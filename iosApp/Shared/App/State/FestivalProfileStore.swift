import Combine
import Foundation
import OSLog
import RudolstadtCore
#if os(iOS)
    import CloudKit
#endif

@MainActor
final class FestivalProfileStore: ObservableObject {
    // MARK: - Constants

    enum Constants {
        static let legacyCacheKey = "festival-profile-cache-v1"
        static let migrationVersion = 1
        static let schemaVersion = 3
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

    var state: ProfileState { viewModel.current }
    // Foundation values are produced only for persistence and native service boundaries.
    var savedEvents: [Int] { state.profile.savedEventIDs.map(\.intValue) }
    var ratings: [String: Int] { state.ratings.mapValues(\.intValue) }
    var artistNotes: [String: String] { state.notes }
    var badgeName: String { FestivalProfileBadge.normalizedName(state.profile.badgeName) ?? "" }
    var badgeColorHex: String { FestivalProfileBadge.resolvedColorHex(state.profile.badgeColorHex) }
    let syncStore = FestivalProfileSyncStore()
    let friendProfilesStore = FriendProfilesStore()
    private var profileObservation: StateSubscription?

    let userDataPolicy: FestivalUserDataPolicy
    let isReadOnly: Bool
    private let cloudKitEnabled: Bool
    private let persistence: any FestivalProfilePersisting
    private let waitBeforePersisting: @Sendable () async -> Void
    private let now: () -> Date
    private var listeners: [FestivalProfileStoreChange: [() -> Void]] = [:]
    private var watchSyncObservations: [StateSubscription] = []
    private var cache: FestivalProfileCache
    private var pendingPersistTask: Task<Void, Never>?
    var syncFailureGeneration: Int { Int(syncStore.viewModel.current.failureGeneration) }
    private let viewModel: ProfileViewModel

    #if os(iOS)
        private lazy var syncCoordinator = FestivalProfileSyncCoordinator(
            store: self, isEnabled: cloudKitEnabled, now: now
        )
        private lazy var sharingService = FestivalProfileSharingService(
            store: self,
            syncCoordinator: syncCoordinator,
            isEnabled: cloudKitEnabled
        )
    #endif

    init(
        userDefaults: UserDefaults = .standard,
        readOnlyFestivalYear: Int? = nil,
        cloudKitEnabled: Bool = FestivalProfileStore.defaultCloudKitEnabled,
        now: @escaping () -> Date = { .now },
        persistence: (any FestivalProfilePersisting)? = nil,
        userDataPolicy: FestivalUserDataPolicy? = nil,
        waitBeforePersisting: @escaping @Sendable () async -> Void = {
            try? await Task.sleep(for: .milliseconds(250))
        }
    ) {
        let resolvedPersistence: any FestivalProfilePersisting
        if let readOnlyFestivalYear {
            resolvedPersistence = UserDefaultsFestivalProfilePersistence(
                userDefaults: userDefaults, festivalYear: readOnlyFestivalYear, isReadOnly: true
            )
        } else {
            resolvedPersistence = persistence ?? UserDefaultsFestivalProfilePersistence(
                    userDefaults: userDefaults, festivalYear: DataStore.year
                )
        }
        let access: FestivalUserDataAccess = readOnlyFestivalYear == nil ? .editable : .readOnly
        self.userDataPolicy = userDataPolicy ?? FestivalUserDataPolicy(savedEvents: access, artistRatings: access, artistNotes: access)
        self.isReadOnly = readOnlyFestivalYear != nil || (self.userDataPolicy.savedEvents != .editable
            && self.userDataPolicy.artistRatings != .editable && self.userDataPolicy.artistNotes != .editable)
        self.cloudKitEnabled = cloudKitEnabled && !self.isReadOnly
        self.now = now
        self.persistence = resolvedPersistence
        self.waitBeforePersisting = waitBeforePersisting
        self.cache = resolvedPersistence.loadCache()
            ?? FestivalProfileCache(
                currentProfile: resolvedPersistence.loadLegacyOwnerProfile(),
                sharedProfiles: [],
                migrationVersion: 0,
                lastSuccessfulRefreshDate: nil,
                privateStateSerializationData: nil,
                sharedStateSerializationData: nil
            )
        self.viewModel = ProfileViewModel(
            savedEditable: self.userDataPolicy.savedEvents == .editable,
            ratingsEditable: self.userDataPolicy.artistRatings == .editable,
            notesEditable: self.userDataPolicy.artistNotes == .editable, readOnly: self.isReadOnly)
        restoreDomainProfile()
        var previous = viewModel.current.profile
        profileObservation = viewModel.observe { [weak self] value in
            defer { previous = value.profile }
            if previous != value.profile { self?.objectWillChange.send() }
        }
        observeSyncStore()
        applyCurrentProfile(cache.currentProfile)
        applyAcceptedFriendProfiles()
        syncStore.lastSuccessfulRefreshDate = cache.lastSuccessfulRefreshDate
        syncStore.shareState = cache.currentProfile.shareRecordName == nil ? .notShared : .shared
        #if os(iOS)
            syncCoordinator.restoreCachedState()
            sharingService.restoreCachedState()
        #endif
        AppLog.sync.info(
            "Loaded festival profile cache with \(self.savedEvents.count) saved events, \(self.ratings.count) ratings, and \(self.acceptedFriendProfiles.count) shared profiles"
        )

        #if os(iOS)
            syncCoordinator.start(sharingService: sharingService)
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
        profileObservation?.cancel()
        watchSyncObservations.forEach { $0.cancel() }
        pendingPersistTask?.cancel()
    }

    // MARK: - Public API

    func onChange(
        of change: FestivalProfileStoreChange,
        perform listener: @escaping () -> Void
    ) {
        listeners[change, default: []].append(listener)
    }

    private func observeSyncStore() {
        var previous = syncStore.state
        watchSyncObservations = [
            friendProfilesStore.viewModel.observe { [weak self] _ in self?.notifyWatchInputs() },
            syncStore.viewModel.observe { [weak self] value in
                defer { previous = value }
                if previous.account != value.account || previous.accountReason != value.accountReason
                    || previous.refreshedAt != value.refreshedAt
                {
                    self?.notifyWatchInputs()
                }
            }
        ]
    }

    private func notifyWatchInputs() {
        listeners[.watchSnapshotInputs]?.forEach { $0() }
    }

    func toggleSavedEvent(_ event: Event) {
        updateCurrentProfile(.toggleSavedEvent(eventID: event.id))
    }

    func idFor(event: Event) -> String {
        "\(event.id)-\(isEventSaved(event.id))"
    }

    func isEventSaved(_ eventID: Int) -> Bool {
        viewModel.isSaved(id: Int64(eventID))
    }

    func rating(for artistID: Int) -> Int {
        Int(viewModel.rating(id: Int64(artistID)))
    }

    func iconName(forArtistID artistID: Int) -> String? {
        viewModel.icon(id: Int64(artistID))
    }

    var acceptedFriendProfiles: [SharedFestivalProfile] {
        friendProfilesStore.state.profiles
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
        updateCurrentProfile(
            .setArtistRating(artistID: artist.id, rating: rating),
            metadataAvailable: artist.isMetadataAvailable)
    }

    func getArtistIcon(for artist: Artist) -> String? {
        iconName(forArtistID: artist.id)
    }

    func setArtistIcon(for artist: Artist, icon: String) {
        updateCurrentProfile(
            .setArtistIcon(artistID: artist.id, iconName: icon), metadataAvailable: artist.isMetadataAvailable
        )
    }

    func noteText(for artist: Artist) -> String? {
        viewModel.note(id: artist.artistID)
    }

    func setArtistNote(for artist: Artist, note: String) {
        updateCurrentProfile(
            .setArtistNote(artistID: artist.id, noteText: note), metadataAvailable: artist.isMetadataAvailable
        )
    }

    func setArtistNote(forArtistID artistID: Int, note: String) {
        updateCurrentProfile(.setArtistNote(artistID: artistID, noteText: note))
    }

    func refreshFromCloud(reason: String = "manual") async {
        #if os(iOS)
            await syncCoordinator.refresh(reason: reason)
        #endif
    }

    #if os(iOS)
        func prepareShare() async throws -> CKShare {
            try await sharingService.prepareShare()
        }

        func prepareOneTimeShareURL() async throws -> URL {
            try await sharingService.prepareOneTimeShareURL()
        }

        func refreshShareParticipants() async {
            await sharingService.refreshShareParticipants()
        }

        func acceptShare(metadata: CKShare.Metadata) async {
            await sharingService.acceptShare(metadata: metadata)
        }

        func acceptShare(url: URL) async throws {
            try await sharingService.acceptShare(url: url)
        }

        func cachedShare() -> CKShare? {
            sharingService.cachedShare()
        }
    #endif

    // MARK: - Local State

    // Internal sync/sharing access. Mutations stay on the main actor; callers
    // publish and persist at the existing transaction boundaries.
    var cacheSnapshot: FestivalProfileCache { cache }

    func updateCache(_ update: (inout FestivalProfileCache) -> Void) {
        update(&cache)
        // Import native persistence/CloudKit payloads at this boundary. Local actions
        // mutate the shared state directly and only export a transport snapshot.
        restoreDomainProfile()
    }

    func publishOwnerProfile() {
        applyCurrentProfile(cache.currentProfile)
    }

    func publishSharedProfiles() {
        applyAcceptedFriendProfiles()
    }

    private func restoreDomainProfile() {
        let profile = cache.currentProfile
        viewModel.restore(
            profile: profile.domainProfile,
            changes: profile.domainChanges,
            pending: Set((cache.pendingProfileRecords ?? []).map(\.key)))
    }

    private func storeDomainProfile() {
        let state = viewModel.current
        cache.currentProfile.applyDomainProfile(state.profile)
        cache.currentProfile.changeVersions = Dictionary(
            uniqueKeysWithValues: state.changes.map {
                ($0.key, CachedProfileChangeVersion($0.version))
            })
        cache.pendingProfileRecords = Set(
            state.pending.compactMap {
                $0 == "profile" ? .profile : FestivalProfileSyncRecord(key: $0)
            })
    }

    private func updateCurrentProfile(_ mutation: FestivalProfileMutation, metadataAvailable: Bool = true) {
        let previous = viewModel.current
        guard
            viewModel.mutate(
                mutation: mutation,
                metadataAvailable: metadataAvailable, now: now().timeIntervalSince1970,
                changeID: UUID().uuidString)
        else { return }
        storeDomainProfile()
        applyCurrentProfile(cache.currentProfile)
        persistCache()
        #if os(iOS)
            syncCoordinator.profileDidChange(changes: viewModel.syncChanges(previous: previous))
        #endif
    }

    func prepareFullUpload() -> [ProfileSyncAction] {
        let changes = viewModel.beginFullUpload()
        storeDomainProfile()
        return changes
    }

    var pendingProfileRecords: Set<FestivalProfileSyncRecord> {
        Set(
            viewModel.current.pending.compactMap {
                $0 == "profile" ? .profile : FestivalProfileSyncRecord(key: $0)
            })
    }

    @discardableResult
    func mergeRemoteChange(_ change: FestivalProfileChange) -> Bool {
        let localWins = viewModel.merge(
            change: change)
        storeDomainProfile()
        applyCurrentProfile(cache.currentProfile)
        persistCache()
        return localWins
    }

    func acknowledgeUploadedChange(_ change: FestivalProfileChange) {
        viewModel.acknowledge(
            change: change)
        storeDomainProfile()
        persistCache()
    }

    func recordUploadFailure(for record: FestivalProfileSyncRecord, message: String) {
        viewModel.uploadFailed(key: record.key)
        storeDomainProfile()
        setSyncState(.error(message))
        persistCache()
    }

    @discardableResult
    func mergeLegacyDeletion(for record: FestivalProfileSyncRecord) -> Bool {
        let retained = viewModel.legacyDeleted(key: record.key)
        storeDomainProfile()
        applyCurrentProfile(cache.currentProfile)
        persistCache()
        return retained
    }

    private func applyCurrentProfile(_ profile: CachedOwnerFestivalProfile) {
        syncStore.shareState = profile.shareRecordName == nil ? .notShared : .shared
        if viewModel.consumeRecommendationChange() {
            listeners[.recommendationInputs]?.forEach { $0() }
            listeners[.watchSnapshotInputs]?.forEach { $0() }
        }
    }

    func persistCache(immediately: Bool = false) {
        guard !isReadOnly else { return }
        let cacheSnapshot = cache
        pendingPersistTask?.cancel()
        pendingPersistTask = Task { [persistence, waitBeforePersisting] in
            if !immediately {
                await waitBeforePersisting()
            }
            guard !Task.isCancelled else { return }
            persistence.persist(cacheSnapshot)
        }
    }

    func flushPendingPersistence() async {
        await pendingPersistTask?.value
    }

    private func applyAcceptedFriendProfiles() {
        let updatedProfiles = cache.sharedProfiles
            .map(Self.makeSharedProfile)
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        if friendProfilesStore.state.profiles != updatedProfiles {
            friendProfilesStore.viewModel.restore(profiles: updatedProfiles)
            AppLog.sync.info(
                "Accepted shared profiles updated to \(updatedProfiles.count) profiles"
            )
        }
    }

    func setICloudStatus(_ newStatus: FestivalProfileICloudStatus) {
        if syncStore.iCloudStatus != newStatus {
            syncStore.iCloudStatus = newStatus
            AppLog.sync.info(
                "iCloud status changed to \(newStatus.logDescription, privacy: .public)"
            )
        }
    }

    func setSyncState(_ newState: FestivalProfileSyncState) {
        let phase: String
        let message: String?
        switch newState {
        case .idle: phase = "idle"; message = nil
        case .syncing: phase = "syncing"; message = nil
        case .error(let value): phase = "error"; message = value
        }
        syncStore.viewModel.sync(phase: phase, message: message, pending: !pendingProfileRecords.isEmpty)
    }

}
