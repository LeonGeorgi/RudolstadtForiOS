import Combine
import Foundation
import Testing
#if os(iOS)
import CloudKit
#endif
@testable import Rudolstadt

@MainActor
struct FestivalProfileStoreTests {
    @Test
    func recommendationInputChangeFiresForSavedEventsAndRatings() {
        let profileStore = TestFixtures.festivalProfileStore()
        var callbackCount = 0
        profileStore.onChange(of: .recommendationInputs) {
            callbackCount += 1
        }

        profileStore.toggleSavedEvent(Event.example)
        profileStore.setArtistRating(for: Artist.example, rating: 2)

        #expect(callbackCount == 2)
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
            cloudKitEnabled: false
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
            colorHex: "#3D78E0"
        )

        #expect(profileStore.badgeName == "Leon Georgi")
        #expect(profileStore.badgeColorHex == "#3D78E0")
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
            cloudKitEnabled: false,
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
        #expect(profileStore.iCloudStatus == .unavailable("Cloud sync disabled"))
    }

    @Test
    func profileReducerNormalizesLocalMutationsWithoutStoreOrSystemAdapters() {
        let profile = TestFixtures.cachedOwnerFestivalProfile(
            savedEventIDs: [9, 3]
        )

        let updatedProfile = FestivalProfileReducer.applying(
            .setArtistNote(artistID: 42, noteText: "  Bring earplugs  "),
            to: profile
        )

        #expect(updatedProfile.savedEventIDs == [3, 9])
        #expect(
            updatedProfile.artistNotes
                == [FestivalArtistNote(artistID: 42, noteText: "Bring earplugs")]
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

        let changes = FestivalProfileSyncPlanner.changes(
            from: oldProfile,
            to: newProfile
        )

        #expect(changes == [
            .save(.profile),
            .save(.savedEvent(eventID: 4)),
            .delete(.savedEvent(eventID: 1)),
            .save(.artistPreference(artistID: 2)),
            .delete(.artistNote(artistID: 3))
        ])
    }

#if os(iOS)
    @Test
    func cloudKitMappingAndConflictPolicyAreCallableWithoutSyncEngine() {
        let profileZoneID = CKRecordZone.ID(
            zoneName: "ProfileZone",
            ownerName: CKCurrentUserDefaultName
        )
        let notesZoneID = CKRecordZone.ID(
            zoneName: "NotesZone",
            ownerName: CKCurrentUserDefaultName
        )
        let recordID = FestivalProfileCloudRecordMapper.recordID(
            for: .savedEvent(eventID: 42),
            profileZoneID: profileZoneID,
            notesZoneID: notesZoneID,
            festivalYear: 2026
        )
        let record = CKRecord(
            recordType: FestivalProfileStore.Constants.savedEventRecordType,
            recordID: recordID
        )

        #expect(recordID.recordName == "SavedEvent-2026-42")
        #expect(
            FestivalProfileCloudRecordMapper.payload(from: record)
                == .savedEvent(eventID: 42)
        )
        #expect(
            FestivalProfileSyncConflictPolicy.action(for: .serverRecordChanged)
                == .mergeServerRecord
        )
        #expect(
            FestivalProfileSyncConflictPolicy.action(for: .zoneNotFound)
                == .recreateZoneAndRetry
        )
        #expect(
            FestivalProfileSyncConflictPolicy.action(for: .networkUnavailable)
                == .waitForAutomaticRetry
        )
    }
#endif
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
