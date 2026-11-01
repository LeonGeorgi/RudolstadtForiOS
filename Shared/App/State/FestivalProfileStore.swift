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

    @Published private(set) var savedEvents: [Int] = []
    @Published private(set) var ratings: [String: Int] = [:]
    @Published private(set) var artistNotes: [String: String] = [:]
    @Published private(set) var badgeName: String = ""
    @Published private(set) var badgeColorHex: String = FestivalProfileBadge.defaultColorHex
    let syncStore = FestivalProfileSyncStore()
    let friendProfilesStore = FriendProfilesStore()
    private var savedEventIDSet = Set<Int>()
    @Published private var artistIconsByID: [String: String] = [:]

    let userDataPolicy: FestivalUserDataPolicy
    let isReadOnly: Bool
    private let cloudKitEnabled: Bool
    private let persistence: any FestivalProfilePersisting
    private let waitBeforePersisting: @Sendable () async -> Void
    private let now: () -> Date
    private var listeners: [FestivalProfileStoreChange: [() -> Void]] = [:]
    private var watchSyncStoreObservation: AnyCancellable?
    private var cache: FestivalProfileCache
    private var pendingPersistTask: Task<Void, Never>?
    private(set) var syncFailureGeneration = 0

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
        watchSyncStoreObservation?.cancel()
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
        watchSyncStoreObservation = Publishers.CombineLatest3(
            friendProfilesStore.$profiles.removeDuplicates(),
            syncStore.$iCloudStatus.removeDuplicates(),
            syncStore.$lastSuccessfulRefreshDate.removeDuplicates()
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.listeners[.watchSnapshotInputs]?.forEach { listener in
                listener()
            }
        }
    }

    func toggleSavedEvent(_ event: Event) {
        guard userDataPolicy.savedEvents == .editable else { return }
        updateCurrentProfile(.toggleSavedEvent(eventID: event.id))
    }

    func idFor(event: Event) -> String {
        "\(event.id)-\(isEventSaved(event.id))"
    }

    func isEventSaved(_ eventID: Int) -> Bool {
        savedEventIDSet.contains(eventID)
    }

    func rating(for artistID: Int) -> Int {
        ratings[String(artistID)] ?? 0
    }

    func iconName(forArtistID artistID: Int) -> String? {
        artistIconsByID[String(artistID)]
    }

    var acceptedFriendProfiles: [SharedFestivalProfile] {
        friendProfilesStore.profiles
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
        guard userDataPolicy.artistRatings == .editable else { return }
        guard artist.isMetadataAvailable else { return }
        updateCurrentProfile(.setArtistRating(artistID: artist.id, rating: rating))
    }

    func getArtistIcon(for artist: Artist) -> String? {
        iconName(forArtistID: artist.id)
    }

    func setArtistIcon(for artist: Artist, icon: String) {
        guard userDataPolicy.artistRatings == .editable else { return }
        guard artist.isMetadataAvailable else { return }
        updateCurrentProfile(.setArtistIcon(artistID: artist.id, iconName: icon))
    }

    func noteText(for artist: Artist) -> String? {
        artistNotes[String(artist.id)]
    }

    func setArtistNote(for artist: Artist, note: String) {
        guard artist.isMetadataAvailable else { return }
        setArtistNote(forArtistID: artist.id, note: note)
    }

    func setArtistNote(forArtistID artistID: Int, note: String) {
        guard userDataPolicy.artistNotes == .editable else { return }
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
    }

    func publishOwnerProfile() {
        applyCurrentProfile(cache.currentProfile)
    }

    func publishSharedProfiles() {
        applyAcceptedFriendProfiles()
    }

    private func updateCurrentProfile(_ mutation: FestivalProfileMutation) {
        guard !isReadOnly else { return }
        let oldProfile = cache.currentProfile
        var updatedProfile = FestivalProfileReducer.applying(
            mutation,
            to: oldProfile
        )
        guard updatedProfile != oldProfile else { return }
        let record = mutation.record
        if record != .profile, record.value(in: updatedProfile) != record.value(in: oldProfile) {
            let editDate = max(now(), (oldProfile.changeVersions?[record.key]?.modifiedAt ?? .distantPast)
                .addingTimeInterval(0.001))
            updatedProfile.changeVersions = updatedProfile.changeVersions ?? [:]
            updatedProfile.changeVersions?[record.key] = FestivalProfileChangeVersion(
                modifiedAt: editDate, changeID: UUID().uuidString
            )
        }
        cache.currentProfile = updatedProfile
        cache.pendingProfileRecords = pendingProfileRecords.union([record])
        applyCurrentProfile(cache.currentProfile)
        persistCache()

#if os(iOS)
        syncCoordinator.profileDidChange(from: oldProfile, to: cache.currentProfile)
#endif
    }

    var pendingProfileRecords: Set<FestivalProfileSyncRecord> {
        cache.pendingProfileRecords ?? []
    }

    // The same domain entry point handles fetched records and upload conflicts.
    // Returning true means the local winner still needs to reach the server.
    @discardableResult
    func mergeRemoteChange(_ change: FestivalProfileChange) -> Bool {
        let record = change.value.record
        let localChange = cache.currentProfile.change(for: record)
        let localWins = localChange.map { $0.version > change.version } ?? false
        if localWins {
            cache.pendingProfileRecords = pendingProfileRecords.union([record])
        } else {
            cache.currentProfile = change.value.applying(to: cache.currentProfile)
            cache.currentProfile.changeVersions = cache.currentProfile.changeVersions ?? [:]
            cache.currentProfile.changeVersions?[record.key] = change.version
            cache.pendingProfileRecords?.remove(record)
            applyCurrentProfile(cache.currentProfile)
        }
        persistCache()
        return localWins
    }

    func acknowledgeUploadedChange(_ change: FestivalProfileChange) {
        // An edit made while an older version was in flight must remain pending.
        if cache.currentProfile.change(for: change.value.record) == change {
            cache.pendingProfileRecords?.remove(change.value.record)
            persistCache()
        }
    }

    func recordUploadFailure(for record: FestivalProfileSyncRecord, message: String) {
        cache.pendingProfileRecords = pendingProfileRecords.union([record])
        setSyncState(.error(message))
        persistCache()
    }

    @discardableResult
    func mergeLegacyDeletion(for record: FestivalProfileSyncRecord) -> Bool {
        guard let local = cache.currentProfile.change(for: record) else { return false }
        // Physical deletions from old clients carry no user-edit date. They
        // cannot establish that a known, versioned local action is older.
        if !local.version.isLegacy || pendingProfileRecords.contains(record) {
            cache.pendingProfileRecords = pendingProfileRecords.union([record])
            persistCache()
            return true
        }
        let deletedValue: FestivalProfileRecordValue
        switch record {
        case .profile: return false
        case .savedEvent(let id): deletedValue = .savedEvent(eventID: id, isSaved: false)
        case .artistPreference(let id):
            deletedValue = .artistPreference(FestivalArtistPreference(artistID: id, rating: 0, iconName: nil))
        case .artistNote(let id):
            deletedValue = .artistNote(FestivalArtistNote(artistID: id, noteText: ""))
        }
        return mergeRemoteChange(FestivalProfileChange(
            value: deletedValue,
            version: FestivalProfileChangeVersion(
                modifiedAt: local.version.modifiedAt, changeID: "legacy:~deleted"
            )
        ))
    }

    private func applyCurrentProfile(_ profile: CachedOwnerFestivalProfile) {
        let previousSavedEvents = savedEvents
        let previousRatings = ratings
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

        if previousSavedEvents != savedEvents || previousRatings != ratings {
            listeners[.recommendationInputs]?.forEach { listener in
                listener()
            }
            listeners[.watchSnapshotInputs]?.forEach { listener in
                listener()
            }
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
        if friendProfilesStore.profiles != updatedProfiles {
            friendProfilesStore.updateProfiles(updatedProfiles)
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
        if case .error(let reason) = newState {
            syncFailureGeneration += 1
            syncStore.recordFailure(reason)
            AppLog.sync.error("Cloud sync failed: \(reason, privacy: .public)")
            return
        }
        if newState == .idle, let error = syncStore.lastSyncError {
            syncStore.syncState = .error(error)
            return
        }
        let resolvedState: FestivalProfileSyncState =
            newState == .idle && !pendingProfileRecords.isEmpty ? .syncing : newState
        if syncStore.syncState != resolvedState {
            syncStore.syncState = resolvedState
        }
    }

}
