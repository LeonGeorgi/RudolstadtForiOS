import Combine
import Foundation
import Testing
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
}
