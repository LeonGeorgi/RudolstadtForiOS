#if os(iOS)
import SwiftUI

struct FriendsTogetherListView: View {
    let kind: FriendsTogetherListKind

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var profileSync: FestivalProfileSyncStore

    private var friendProfiles: [SharedFestivalProfile] {
        sortedFriendProfiles(profileSync.acceptedFriendProfiles)
    }

    private var friendRecommendations: [FriendArtistRecommendation] {
        friendArtistRecommendations(
            friendProfiles: friendProfiles,
            artists: festivalData.artists,
            events: festivalData.events,
            excludedArtistIDs: friendRecommendationExcludedArtistIDs(
                savedEventIDs: profile.savedEvents,
                ratings: profile.ratings,
                events: festivalData.events
            )
        )
    }

    var body: some View {
        List {
            switch kind {
            case .recommendations:
                ForEach(friendRecommendations) { recommendation in
                    NavigationLink(
                        value: AppNavigationRoute.artist(
                            id: recommendation.artist.id,
                            highlightedEventId: recommendation.highlightedEventID,
                            transitionSourceID: nil
                        )
                    ) {
                        FriendArtistRecommendationRow(recommendation: recommendation)
                    }
                    .listRowInsets(
                        EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 12)
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(navigationTitle)
    }

    private var navigationTitle: LocalizedStringKey {
        switch kind {
        case .recommendations:
            return "friends.recommendations.title"
        }
    }
}

#if DEBUG
struct FriendsTogetherListView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        let environment = PreviewMockData.makeEnvironment(
            suiteName: "FriendsTogetherListViewPreview"
        )
        environment.dataStore.loadExtraData()

        return NavigationStack {
            FriendsTogetherListView(kind: .recommendations)
                .navigationDestination(for: AppNavigationRoute.self) { _ in
                    EmptyView()
                }
        }
        .previewEnvironment(environment)
    }
}
#endif
#endif
