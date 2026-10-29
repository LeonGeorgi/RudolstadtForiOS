import Combine
import Foundation
import RudolstadtCore

@MainActor
final class FriendProfilesStore: KotlinStateStore<FriendProfileState> {
    let viewModel: FriendsViewModel

    init() {
        let model = FriendsViewModel()
        viewModel = model
        super.init(current: { model.current }, observe: model.observe)
    }
    func friendProfilesSavingEvent(_ eventID: Int) -> [SharedFestivalProfile] {
        viewModel.saving(eventID: Int64(eventID)).sorted {
            $0.id.localizedStandardCompare($1.id) == .orderedAscending
        }
    }

    func friendArtistRatingSummary(for artistID: Int) -> FriendArtistRatingSummary? {
        let entries = viewModel.rating(artistID: Int64(artistID))
            .sorted { lhs, rhs in
                lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
            }
            .compactMap { sharedProfile -> FriendArtistRatingSummary.Entry? in
                guard
                    let preference = sharedProfile.preferences.first(where: { preference in
                        preference.artistID == artistID
                }) else {
                    return nil
                }

                return FriendArtistRatingSummary.Entry(
                    profileID: sharedProfile.id,
                    badge: sharedProfile.badge,
                    preference: preference.native
                )
            }

        guard !entries.isEmpty else {
            return nil
        }

        return FriendArtistRatingSummary(entries: entries)
    }
}
