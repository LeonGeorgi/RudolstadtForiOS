import RudolstadtCore
import Combine
import Foundation
import Testing

@testable import Rudolstadt

@MainActor
struct FestivalProfileStoreTests {
    @Test
    func syncStatusChangesDoNotPublishProfileOrFriendData() {
        let store = TestFixtures.festivalProfileStore()
        var profileChanges = 0
        var friendChanges = 0
        var watchChanges = 0
        let profileObservation = store.objectWillChange.sink { profileChanges += 1 }
        let friendObservation = store.friendProfilesStore.objectWillChange
            .sink { friendChanges += 1 }
        defer {
            profileObservation.cancel()
            friendObservation.cancel()
        }
        store.onChange(of: .watchSnapshotInputs) { watchChanges += 1 }

        store.syncStore.syncState = .syncing
        store.syncStore.syncState = .idle
        store.syncStore.accountStatus = .available
        store.syncStore.accountStatus = .available
        let refreshDate = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        store.syncStore.lastSuccessfulRefreshDate = refreshDate
        store.syncStore.lastSuccessfulRefreshDate = refreshDate

        #expect(profileChanges == 0)
        #expect(friendChanges == 0)
        #expect(watchChanges == 2)
    }

    @Test
    func friendUpdatesPublishChangedProfilesWithoutPublishingOwnerChanges() {
        let store = TestFixtures.festivalProfileStore()
        var ownerChanges = 0
        var publishedProfiles: [[SharedFestivalProfile]] = []
        var watchChanges = 0
        let ownerObservation = store.objectWillChange.sink { ownerChanges += 1 }
        let friendObservation = store.friendProfilesStore.objectWillChange
            .sink { publishedProfiles.append(store.friendProfilesStore.state.profiles) }
        defer {
            ownerObservation.cancel()
            friendObservation.cancel()
        }
        store.onChange(of: .watchSnapshotInputs) { watchChanges += 1 }
        let friend = TestFixtures.sharedFestivalProfile(
            savedEventIDs: [Event.example.id],
            artistPreferences: [
                FestivalArtistPreference(artistID: Artist.example.id, rating: 3)
            ]
        )

        store.friendProfilesStore.viewModel.restore(profiles: [friend])
        store.friendProfilesStore.viewModel.restore(profiles: [friend])

        #expect(publishedProfiles == [[friend]])
        #expect(store.friendProfilesStore.state.profiles.first === friend)
        #expect(ownerChanges == 0)
        #expect(watchChanges == 1)
        #expect(store.friendProfilesStore.friendProfilesSavingEvent(Event.example.id) == [friend])
        #expect(
            store.friendProfilesStore.friendArtistRatingSummary(for: Artist.example.id)?
                .entries.first?.preference.rating == 3
        )

        store.friendProfilesStore.viewModel.restore(profiles: [])
        #expect(publishedProfiles == [[friend], []])
        #expect(store.friendProfilesStore.friendProfilesSavingEvent(Event.example.id).isEmpty)
        #expect(store.friendProfilesStore.friendArtistRatingSummary(for: Artist.example.id) == nil)
    }

    @Test
    func recommendationInputChangeFiresForSavedEventsAndRatings() {
        let profileStore = TestFixtures.festivalProfileStore()
        var callbackCount = 0
        var watchCallbackCount = 0
        profileStore.onChange(of: .recommendationInputs) {
            callbackCount += 1
        }
        profileStore.onChange(of: .watchSnapshotInputs) {
            watchCallbackCount += 1
        }

        profileStore.toggleSavedEvent(Event.example)
        profileStore.setArtistRating(for: Artist.example, rating: 2)
        profileStore.friendProfilesStore.viewModel.restore(profiles: [
            TestFixtures.sharedFestivalProfile(savedEventIDs: [Event.example.id])
        ])

        #expect(callbackCount == 2)
        #expect(watchCallbackCount == 3)
    }

    @Test
    func legacyUserDefaultsValuesAreLoadedIntoFestivalProfileStore() throws {
        let userDefaults = try #require(
            UserDefaults(suiteName: UUID().uuidString)
        )
        userDefaults.set([17, 19], forKey: "\(DataStore.year)/savedEvents")
        userDefaults.set(
            ["42": 3, "43": -1],
            forKey: "\(DataStore.year)/ratings"
        )
        userDefaults.set(
            ["43": "questionmark.circle.fill"],
            forKey: "\(DataStore.year)/artistIcons"
        )
        userDefaults.set(
            ["42": "Bring earplugs"],
            forKey: "\(DataStore.year)/artistNotes"
        )

        let profileStore = FestivalProfileStore(
            userDefaults: userDefaults,
            cloudSyncEnabled: false
        )

        #expect(profileStore.savedEvents == [17, 19])
        #expect(profileStore.ratings["42"] == 3)
        #expect(profileStore.ratings["43"] == -1)
        #expect(
            profileStore.getArtistIcon(for: TestFixtures.artist(id: 43))
                == "questionmark.circle.fill"
        )
        #expect(
            profileStore.noteText(for: TestFixtures.artist(id: 42))
                == "Bring earplugs"
        )
    }

    @Test
    func artistNotesAreRemovedWhenSavedAsEmpty() {
        let profileStore = TestFixtures.festivalProfileStore()

        profileStore.setArtistNote(for: Artist.example, note: "Test note")
        profileStore.setArtistNote(for: Artist.example, note: "")

        #expect(profileStore.noteText(for: Artist.example) == nil)
    }

    @Test
    func existingArtistNoteIsLoadedIntoEditorDraft() {
        let profileStore = TestFixtures.festivalProfileStore()
        profileStore.setArtistNote(for: Artist.example, note: "Meet at the stage")

        let draft = ArtistNoteDraft(
            noteText: profileStore.noteText(for: Artist.example)
        )

        #expect(draft.text == "Meet at the stage")
        #expect(!draft.hasChanges)
    }

    @Test
    func newlySavedArtistNoteIsLoadedWhenEditorReopens() {
        let profileStore = TestFixtures.festivalProfileStore()
        var draft = ArtistNoteDraft(
            noteText: profileStore.noteText(for: Artist.example)
        )

        #expect(draft.text.isEmpty)
        draft.text = "Listen from the front"
        #expect(draft.hasChanges)

        profileStore.setArtistNote(for: Artist.example, note: draft.text)
        let reopenedDraft = ArtistNoteDraft(
            noteText: profileStore.noteText(for: Artist.example)
        )

        #expect(reopenedDraft.text == "Listen from the front")
        #expect(!reopenedDraft.hasChanges)
    }

    @Test
    func deletedArtistNoteIsEmptyWhenEditorReopens() {
        let profileStore = TestFixtures.festivalProfileStore()
        profileStore.setArtistNote(for: Artist.example, note: "Remember this")
        var draft = ArtistNoteDraft(
            noteText: profileStore.noteText(for: Artist.example)
        )

        draft.text = ""
        profileStore.setArtistNote(for: Artist.example, note: draft.text)
        let reopenedDraft = ArtistNoteDraft(
            noteText: profileStore.noteText(for: Artist.example)
        )

        #expect(profileStore.noteText(for: Artist.example) == nil)
        #expect(reopenedDraft.text.isEmpty)
        #expect(!reopenedDraft.hasChanges)
    }

    @Test
    func objectWillChangePublishesWhenProfileChanges() {
        let profileStore = TestFixtures.festivalProfileStore()
        var cancellables = Set<AnyCancellable>()
        var changeCount = 0

        profileStore.objectWillChange
            .sink {
                changeCount += 1
            }
            .store(in: &cancellables)

        profileStore.toggleSavedEvent(Event.example)

        #expect(changeCount > 0)
    }

    @Test
    func badgeConfigurationUpdatesOwnerBadge() {
        let profileStore = TestFixtures.festivalProfileStore()

        profileStore.updateBadge(
            name: "Leon Georgi",
            hue: 255
        )

        #expect(profileStore.badgeName == "Leon Georgi")
        #expect(profileStore.badgeHue == 255)
        #expect(profileStore.ownerBadge.initials == "LG")
    }

    @Test
    func localMutationPersistsThroughInjectedAdapterWithoutDelay() async {
        let initialProfile = TestFixtures.cachedOwnerFestivalProfile()
        let persistence = FestivalProfilePersistenceSpy(
            loadedCache: TestFixtures.festivalProfileCache(
                currentProfile: initialProfile
            ),
            legacyProfile: initialProfile
        )
        let profileStore = FestivalProfileStore(
            cloudSyncEnabled: false,
            persistence: persistence,
            waitBeforePersisting: {}
        )

        profileStore.toggleSavedEvent(Event.example)
        await profileStore.flushPendingPersistence()

        #expect(persistence.persistedCaches.count == 1)
        #expect(
            persistence.persistedCaches.last?.currentProfile.savedEventIDs
                == [Event.example.id]
        )
        #expect(profileStore.accountStatus == .local)
    }

    @Test
    func profileReducerNormalizesLocalMutationsWithoutStoreOrSystemAdapters() {
        let profile = TestFixtures.cachedOwnerFestivalProfile(
            savedEventIDs: [9, 3]
        )

        let updatedProfile = ProfileReducer.shared.apply(
            profile: profile.domainProfile,
            mutation: FestivalProfileMutation.setArtistNote(
                artistID: 42, noteText: "  Bring earplugs  "))

        #expect(updatedProfile.savedEventIDs.map(\.intValue) == [3, 9])
        #expect(
            updatedProfile.artistNotes.map(\.noteText) == ["Bring earplugs"]
        )
    }

    @Test
    func syncPlannerDescribesChangedAndDeletedProfileRecords() {
        let oldProfile = TestFixtures.cachedOwnerFestivalProfile(
            savedEventIDs: [1],
            artistPreferences: [
                FestivalArtistPreference(artistID: 2, rating: 1, iconName: nil)
            ],
            artistNotes: [FestivalArtistNote(artistID: 3, noteText: "Old")]
        )
        let newProfile = TestFixtures.cachedOwnerFestivalProfile(
            savedEventIDs: [4],
            artistPreferences: [
                FestivalArtistPreference(artistID: 2, rating: 3, iconName: nil)
            ]
        )

        let changes = ProfileSync.shared.changes(
            old: oldProfile.domainChanges, new: newProfile.domainChanges)
        #expect(
            Dictionary(uniqueKeysWithValues: changes.map { ($0.key, $0.delete_) }) == [
                "profile": false, "event:4": false, "event:1": true, "rating:2": false,
                "note:3": true,
            ])
    }

}

@MainActor
struct FirebaseLocalProfileImportTests {
    @Test
    func localNotesSurviveImportEvenWithOpaqueLegacySystemFields() throws {
        var profile = TestFixtures.cachedOwnerFestivalProfile()
        profile.artistNotes = [FestivalArtistNote(artistID: 7, noteText: "PRIVATE LOCAL NOTE")]
        profile.rootRecordSystemFieldsData = Data([1, 2, 3])
        profile.artistNoteRecordSystemFieldsByName = ["old-note": Data([4, 5, 6])]
        let raw = try JSONEncoder().encode(profile)
        let restored = try JSONDecoder().decode(CachedOwnerFestivalProfile.self, from: raw)
        let local = try OwnProfileData.shared.encodeLocal(journal: nil, profile: restored.domainProfile, changes: restored.domainChanges)
        #expect(local.contains("PRIVATE LOCAL NOTE"))
        #expect(restored.artistNotes == profile.artistNotes)
        #expect(restored.rootRecordSystemFieldsData == profile.rootRecordSystemFieldsData)
    }

    @Test
    func versionedNotesRoundTripThroughFirebasePayloadWithoutChangingTheirDates() throws {
        let profile = PersonalProfile(badgeName: "Local", badgeHue: 30, savedEventIDs: [], artistPreferences: [], artistNotes: [ArtistNote(artistID: 7, noteText: "Note")])
        let version = ProfileVersion(modifiedAt: 1234.123, changeID: "local-edit")
        let value = ProfileRecordValue.artistNote(FestivalArtistNote(artistID: 7, noteText: "Note"))
        let record = OwnProfileData.shared.record(change: ProfileRecordChange(value: value, version: version))
        let payload = OwnProfileData.shared.encodeRecords(value: [record])
        #expect(payload.contains("1234.123"))
        #expect(profile.artistNotes.first?.noteText == record.value?.noteText)
    }
}

struct FestivalProfilePersistenceTests {
    @Test
    func cachesAndLegacyValuesAreIsolatedByFestivalYear() {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        userDefaults.set([26], forKey: "2026/savedEvents")
        userDefaults.set([27], forKey: "2027/savedEvents")
        let persistence2026 = UserDefaultsFestivalProfilePersistence(
            userDefaults: userDefaults,
            festivalYear: 2026
        )
        let persistence2027 = UserDefaultsFestivalProfilePersistence(
            userDefaults: userDefaults,
            festivalYear: 2027
        )
        let cache2026 = TestFixtures.festivalProfileCache(
            currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                festivalYear: 2026,
                savedEventIDs: [126]
            )
        )
        let cache2027 = TestFixtures.festivalProfileCache(
            currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                festivalYear: 2027,
                savedEventIDs: [127]
            )
        )

        persistence2026.persist(cache2026)
        persistence2027.persist(cache2027)

        #expect(persistence2026.loadCache() == cache2026)
        #expect(persistence2027.loadCache() == cache2027)
        #expect(persistence2026.loadLegacyOwnerProfile().savedEventIDs == [26])
        #expect(persistence2027.loadLegacyOwnerProfile().savedEventIDs == [27])
    }

    @Test
    func yearIndependentCacheMigratesToItsEmbeddedFestivalYear() throws {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let legacyCache = TestFixtures.festivalProfileCache(
            currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                festivalYear: 2026,
                savedEventIDs: [42]
            )
        )
        let legacyData = try JSONEncoder().encode(legacyCache)
        userDefaults.set(
            legacyData,
            forKey: FestivalProfileStore.Constants.legacyCacheKey
        )
        let currentYearPersistence = UserDefaultsFestivalProfilePersistence(
            userDefaults: userDefaults,
            festivalYear: 2027
        )

        #expect(currentYearPersistence.loadCache() == nil)
        #expect(
            userDefaults.data(
                forKey: FestivalProfileStore.Constants.cacheKey(for: 2026)
            ) == legacyData
        )
        #expect(
            userDefaults.object(
                forKey: FestivalProfileStore.Constants.legacyCacheKey
            ) == nil
        )
        #expect(currentYearPersistence.loadCache() == nil)
    }

    @Test
    func legacyMigrationPreservesAnExistingValidYearCache() throws {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let existingCache = TestFixtures.festivalProfileCache(
            currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                festivalYear: 2026,
                savedEventIDs: [1]
            )
        )
        let legacyCache = TestFixtures.festivalProfileCache(
            currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                festivalYear: 2026,
                savedEventIDs: [2]
            )
        )
        userDefaults.set(
            try JSONEncoder().encode(existingCache),
            forKey: FestivalProfileStore.Constants.cacheKey(for: 2026)
        )
        userDefaults.set(
            try JSONEncoder().encode(legacyCache),
            forKey: FestivalProfileStore.Constants.legacyCacheKey
        )
        let persistence = UserDefaultsFestivalProfilePersistence(
            userDefaults: userDefaults,
            festivalYear: 2026
        )

        #expect(persistence.loadCache() == existingCache)
        #expect(
            userDefaults.object(
                forKey: FestivalProfileStore.Constants.legacyCacheKey
            ) == nil
        )
    }

    @Test
    func cacheForWrongFestivalYearIsNeitherPersistedNorLoaded() throws {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let persistence = UserDefaultsFestivalProfilePersistence(
            userDefaults: userDefaults,
            festivalYear: 2027
        )
        let cache2026 = TestFixtures.festivalProfileCache(
            currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                festivalYear: 2026
            )
        )

        persistence.persist(cache2026)
        userDefaults.set(
            try JSONEncoder().encode(cache2026),
            forKey: FestivalProfileStore.Constants.cacheKey(for: 2027)
        )

        #expect(persistence.loadCache() == nil)
    }

    @Test
    func legacyCacheIsRetainedWhenItsYearDestinationIsInvalid() throws {
        let userDefaults = TestFixtures.isolatedUserDefaults()
        let legacyCache = TestFixtures.festivalProfileCache(
            currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                festivalYear: 2026,
                savedEventIDs: [42]
            )
        )
        let legacyData = try JSONEncoder().encode(legacyCache)
        userDefaults.set(
            legacyData,
            forKey: FestivalProfileStore.Constants.legacyCacheKey
        )
        userDefaults.set(
            Data("invalid".utf8),
            forKey: FestivalProfileStore.Constants.cacheKey(for: 2026)
        )
        let persistence = UserDefaultsFestivalProfilePersistence(
            userDefaults: userDefaults,
            festivalYear: 2026
        )

        #expect(persistence.loadCache() == nil)
        #expect(
            userDefaults.data(
                forKey: FestivalProfileStore.Constants.legacyCacheKey
            ) == legacyData
        )
    }
}

@MainActor
struct FestivalProfileConflictTests {
    private let editDate = Date(timeIntervalSince1970: 1_800_000_000)
    private let artist = Artist.example
    private let event = Event.example

    private func change(_ value: FestivalProfileRecordValue, seconds: Double, id: String = "remote") -> FestivalProfileChange {
        FestivalProfileChange(value: value, version: FestivalProfileChangeVersion(
                modifiedAt: editDate.addingTimeInterval(seconds), changeID: id
            ))
    }

    private func values(note: String, rating: Int, saved: Bool) -> [FestivalProfileRecordValue] {
        [
            .artistNote(FestivalArtistNote(artistID: artist.id, noteText: note)),
            .artistPreference(FestivalArtistPreference(artistID: artist.id, rating: rating, iconName: nil)),
            .savedEvent(eventID: event.id, isSaved: saved)
        ]
    }

    @Test
    func userEditTimeWinsIndependentlyOfDeliveryOrderAndEntity() {
        let store = FestivalProfileStore(
            userDefaults: TestFixtures.isolatedUserDefaults(), cloudSyncEnabled: false, now: { editDate }
        )
        store.setArtistNote(for: artist, note: "Local")
        store.setArtistRating(for: artist, rating: 3)
        store.toggleSavedEvent(event)

        for value in values(note: "Older", rating: 1, saved: false) {
            #expect(store.mergeRemoteChange(change(value, seconds: -10)))
            #expect(store.pendingProfileRecords.contains(value.record))
        }
        #expect(store.noteText(for: artist) == "Local")
        #expect(store.rating(for: artist.id) == 3)
        #expect(store.isEventSaved(event.id))

        // A newer note does not alter the independently edited rating or event.
        store.mergeRemoteChange(change(values(note: "Newer", rating: 1, saved: false)[0], seconds: 10))
        #expect(store.noteText(for: artist) == "Newer")
        #expect(store.rating(for: artist.id) == 3)
        #expect(store.isEventSaved(event.id))

        for value in values(note: "Newer", rating: 1, saved: false) {
            #expect(!store.mergeRemoteChange(change(value, seconds: 10)))
        }
        #expect(store.rating(for: artist.id) == 1)
        #expect(!store.isEventSaved(event.id))
        #expect(store.pendingProfileRecords.isEmpty)
    }

    @Test
    func deletionsAndPendingChangesSurviveRestartAndPreventResurrection() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        var clock = editDate
        let store = FestivalProfileStore(
            userDefaults: defaults, cloudSyncEnabled: false, now: { clock }, waitBeforePersisting: {}
        )
        store.setArtistNote(for: artist, note: "Saved")
        store.setArtistRating(for: artist, rating: 3)
        store.toggleSavedEvent(event)
        clock = editDate.addingTimeInterval(20)
        store.setArtistNote(for: artist, note: "")
        store.setArtistRating(for: artist, rating: 0)
        store.toggleSavedEvent(event)
        await store.flushPendingPersistence()

        let persistence = UserDefaultsFestivalProfilePersistence(userDefaults: defaults, festivalYear: DataStore.year)
        let cache = try #require(persistence.loadCache())
        #expect(cache.currentProfile.syncRecords.count == 3)
        #expect(
            ProfileRecords.shared.fullUpload(
                profile: cache.currentProfile.domainProfile,
                versionKeys: Set((cache.currentProfile.changeVersions ?? [:]).keys)
            ).count == 4)
        for value in values(note: "", rating: 0, saved: false) {
            let deletion = try #require(cache.currentProfile.change(for: value.record))
            #expect(deletion.value.isDeleted)
            #expect(deletion.version.date == clock)
        }

        let reloaded = FestivalProfileStore(userDefaults: defaults, cloudSyncEnabled: false)
        #expect(reloaded.pendingProfileRecords.count == 3)
        for value in values(note: "Old saved value", rating: 3, saved: true) {
            #expect(reloaded.mergeRemoteChange(change(value, seconds: 10)))
        }
        #expect(reloaded.noteText(for: artist) == nil)
        #expect(reloaded.rating(for: artist.id) == 0)
        #expect(!reloaded.isEventSaved(event.id))

        for value in values(note: "Saved again", rating: 2, saved: true) {
            reloaded.mergeRemoteChange(change(value, seconds: 30))
        }
        #expect(reloaded.noteText(for: artist) == "Saved again")
        #expect(reloaded.rating(for: artist.id) == 2)
        #expect(reloaded.isEventSaved(event.id))
    }

    @Test
    func duplicateDeliveryAndEqualTimesConvergeOnBothDevices() {
        let first = TestFixtures.festivalProfileStore()
        let second = TestFixtures.festivalProfileStore()
        let a = change(values(note: "A", rating: 1, saved: true)[0], seconds: 0, id: "a")
        let b = change(values(note: "B", rating: 1, saved: true)[0], seconds: 0, id: "b")
        [a, b, b, a].forEach { first.mergeRemoteChange($0) }
        [b, a, a, b].forEach { second.mergeRemoteChange($0) }
        #expect(first.noteText(for: artist) == "B")
        #expect(second.noteText(for: artist) == "B")
        // The latest server echo confirms the winning version.
        first.mergeRemoteChange(b)
        #expect(first.pendingProfileRecords.isEmpty)
    }

    @Test
    func anOlderUploadAcknowledgementDoesNotClearANewerLocalEdit() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let persistence = UserDefaultsFestivalProfilePersistence(userDefaults: defaults, festivalYear: DataStore.year)
        var clock = editDate
        let store = FestivalProfileStore(
            userDefaults: defaults, cloudSyncEnabled: false, now: { clock }, waitBeforePersisting: {}
        )
        let record = FestivalProfileSyncRecord.artistPreference(artistID: artist.id)
        store.setArtistRating(for: artist, rating: 1)
        await store.flushPendingPersistence()
        let first = try #require(persistence.loadCache()?.currentProfile.change(for: record))
        clock = editDate.addingTimeInterval(10)
        store.setArtistRating(for: artist, rating: 3)
        store.acknowledgeUploadedChange(first)
        #expect(store.pendingProfileRecords.contains(record))
        #expect(store.rating(for: artist.id) == 3)
        await store.flushPendingPersistence()
        let latest = try #require(persistence.loadCache()?.currentProfile.change(for: record))
        store.acknowledgeUploadedChange(latest)
        #expect(!store.pendingProfileRecords.contains(record))
    }

    @Test
    func unchangedValuesDoNotCreateNewVersionsOrPendingWork() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let persistence = UserDefaultsFestivalProfilePersistence(userDefaults: defaults, festivalYear: DataStore.year)
        let store = FestivalProfileStore(
            userDefaults: defaults, cloudSyncEnabled: false, now: { editDate }, waitBeforePersisting: {}
        )
        let incoming = change(values(note: "Unchanged", rating: 2, saved: false)[0], seconds: -10)
        store.mergeRemoteChange(incoming)
        store.setArtistNote(for: artist, note: "  Unchanged  ")
        store.setArtistRating(for: artist, rating: 0)
        await store.flushPendingPersistence()
        #expect(store.pendingProfileRecords.isEmpty)
        #expect(persistence.loadCache()?.currentProfile.change(for: incoming.value.record) == incoming)
    }

    @Test
    func partialUploadFailureRetainsRetryIntentAcrossRestart() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let persistence = UserDefaultsFestivalProfilePersistence(userDefaults: defaults, festivalYear: DataStore.year)
        let store = FestivalProfileStore(
            userDefaults: defaults, cloudSyncEnabled: false, now: { editDate }, waitBeforePersisting: {}
        )
        store.setArtistRating(for: artist, rating: 3)
        store.setArtistNote(for: artist, note: "Keep for retry")
        await store.flushPendingPersistence()
        let ratingRecord = FestivalProfileSyncRecord.artistPreference(artistID: artist.id)
        let noteRecord = FestivalProfileSyncRecord.artistNote(artistID: artist.id)
        let uploaded = try #require(persistence.loadCache()?.currentProfile.change(for: ratingRecord))
        store.recordUploadFailure(for: noteRecord, message: "Network unavailable")
        store.acknowledgeUploadedChange(uploaded)
        #expect(store.syncStore.shouldWarnBeforeEditing)
        #expect(store.pendingProfileRecords == [noteRecord])
        #expect(store.noteText(for: artist) == "Keep for retry")
        await store.flushPendingPersistence()
        let reloaded = FestivalProfileStore(userDefaults: defaults, cloudSyncEnabled: false)
        #expect(reloaded.pendingProfileRecords == [noteRecord])
        #expect(reloaded.noteText(for: artist) == "Keep for retry")
    }

    @Test
    func successiveActionsWithinTheSameClockTickKeepTheirOrder() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let persistence = UserDefaultsFestivalProfilePersistence(userDefaults: defaults, festivalYear: DataStore.year)
        let store = FestivalProfileStore(
            userDefaults: defaults, cloudSyncEnabled: false, now: { editDate }, waitBeforePersisting: {}
        )
        store.toggleSavedEvent(event)
        await store.flushPendingPersistence()
        let first = try #require(persistence.loadCache()?.currentProfile.change(for: .savedEvent(eventID: event.id)))
        store.toggleSavedEvent(event)
        #expect(store.mergeRemoteChange(first))
        #expect(!store.isEventSaved(event.id))
    }

    @Test
    func legacyCachesRemainReadableWithoutFabricatingCurrentEditDates() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let original = TestFixtures.festivalProfileCache(currentProfile: TestFixtures.cachedOwnerFestivalProfile(
                savedEventIDs: [event.id],
            artistPreferences: [FestivalArtistPreference(artistID: artist.id, rating: 3, iconName: nil)],
                artistNotes: [FestivalArtistNote(artistID: artist.id, noteText: "Before update")]
            ))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var profile = try #require(json["currentProfile"] as? [String: Any])
        profile.removeValue(forKey: "changeVersions")
        json["currentProfile"] = profile
        json.removeValue(forKey: "pendingProfileRecords")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: FestivalProfileStore.Constants.cacheKey(for: DataStore.year))
        let store = FestivalProfileStore(userDefaults: defaults, cloudSyncEnabled: false, now: { editDate })
        #expect(store.savedEvents == [event.id])
        #expect(store.rating(for: artist.id) == 3)
        #expect(store.noteText(for: artist) == "Before update")
        #expect(store.pendingProfileRecords.isEmpty)
        // An old server record still supersedes undated legacy text; migration did not date it "now".
        store.mergeRemoteChange(change(values(note: "Historical remote", rating: 2, saved: false)[0], seconds: -100))
        #expect(store.noteText(for: artist) == "Historical remote")
    }

    @Test
    func legacyPhysicalDeletionRemovesLegacyValuesButCannotEraseDatedLocalEdits() {
        let store = TestFixtures.festivalProfileStore()
        let value = values(note: "Legacy", rating: 1, saved: false)[0]
        store.mergeRemoteChange(FestivalProfileChange(value: value, version: FestivalProfileChangeVersion(
                    modifiedAt: .distantPast, changeID: value.legacyChangeID
                )))
        #expect(!store.mergeLegacyDeletion(for: value.record))
        #expect(store.noteText(for: artist) == nil)
        store.setArtistNote(for: artist, note: "Explicit new edit")
        #expect(store.mergeLegacyDeletion(for: value.record))
        #expect(store.noteText(for: artist) == "Explicit new edit")
    }

}

@MainActor
struct ArtistNoteEditingTests {
    @Test
    func pristineDraftAdoptsRemoteTextAndUpdatesItsBaseline() {
        var draft = ArtistNoteDraft(noteText: "Old")
        draft.receiveSavedNote("New")
        #expect(draft.text == "New")
        #expect(!draft.hasChanges)
        draft.text = "Edited"
        draft.receiveSavedNote("Another remote edit")
        #expect(draft.text == "Edited")
        #expect(draft.hasChanges)
    }

    @Test
    func returningToOriginalTextIsUnchangedAndCanAdoptRemoteDeletion() {
        var draft = ArtistNoteDraft(noteText: "Original")
        draft.text = "Changed"
        draft.text = " Original \n"
        #expect(!draft.hasChanges)
        draft.receiveSavedNote(nil)
        #expect(draft.text.isEmpty)
        #expect(!draft.hasChanges)
        draft.text = "New draft"
        #expect(draft.hasChanges)
    }

    @Test
    func syncWarningSurvivesPendingWorkAndDisappearsOnlyAfterRecovery() {
        let sync = FestivalProfileSyncStore()
        sync.accountStatus = .available
        #expect(!sync.shouldWarnBeforeEditing)
        sync.recordFailure("Offline")
        #expect(sync.shouldWarnBeforeEditing)
        sync.syncState = .syncing
        #expect(sync.shouldWarnBeforeEditing)
        sync.syncState = .idle
        #expect(sync.shouldWarnBeforeEditing)
        sync.confirmSuccess()
        #expect(!sync.shouldWarnBeforeEditing)
        sync.accountStatus = .unavailable("Signed out")
        #expect(sync.shouldWarnBeforeEditing)
        sync.confirmSuccess()
        #expect(sync.shouldWarnBeforeEditing)
    }
}
