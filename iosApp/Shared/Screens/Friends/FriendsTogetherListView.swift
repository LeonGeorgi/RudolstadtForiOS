#if os(iOS)
    import SwiftUI

    struct FriendsTogetherListView: View {
        let kind: FriendsTogetherListKind

        @Environment(\.festivalData) private var festivalData
        @Environment(\.locale) private var locale

        var body: some View {
            FriendsTogetherListContent(
                kind: kind,
                context: FriendRecommendationContext(
                    artists: festivalData.artists, events: festivalData.events, locale: locale))
        }
    }

    private struct FriendsTogetherListContent: View {
        let kind: FriendsTogetherListKind
        let context: FriendRecommendationContext
        @EnvironmentObject private var profile: FestivalProfileStore
        @EnvironmentObject private var friends: FriendProfilesStore

        var body: some View {
            let recommendations = context.recommendations(
                friendProfiles: sortedFriendProfiles(friends.state.profiles),
                savedEventIDs: profile.savedEvents, ratings: profile.ratings)
            List {
                switch kind {
                case .recommendations:
                    ForEach(recommendations) { recommendation in
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
