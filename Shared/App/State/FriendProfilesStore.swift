import Combine
import Foundation

@MainActor
final class FriendProfilesStore: ObservableObject {
    @Published private(set) var profiles: [SharedFestivalProfile] = []

    func updateProfiles(_ profiles: [SharedFestivalProfile]) {
        guard self.profiles != profiles else {
            return
        }
        self.profiles = profiles
    }

    func friendProfilesSavingEvent(_ eventID: Int) -> [SharedFestivalProfile] {
        profiles
            .filter { $0.savedEventIDs.contains(eventID) }
            .sorted { lhs, rhs in
                lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }
    }

    func friendArtistRatingSummary(for artistID: Int) -> FriendArtistRatingSummary? {
        let entries = profiles
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
}
