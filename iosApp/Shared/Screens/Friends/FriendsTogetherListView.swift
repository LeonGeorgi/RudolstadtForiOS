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
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        var body: some View {
            let recommendations = context.recommendations(
                friendProfiles: sortedFriendProfiles(friends.state.profiles),
                savedEventIDs: profile.savedEvents, ratings: profile.ratings)
            ScrollView {
                if recommendations.isEmpty {
                    Text("friends.ui.recommendations.empty")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                } else {
                    FriendRecommendationGridLayout(
                        columnCount: dynamicTypeSize.isAccessibilitySize ? 1 : 2
                    ) {
                        ForEach(recommendations) { recommendation in
                            NavigationLink(
                                value: AppNavigationRoute.artist(
                                    id: recommendation.artist.id,
                                    highlightedEventId: recommendation.highlightedEventID,
                                    transitionSourceID: nil
                                )
                            ) {
                                FriendArtistRecommendationCard(recommendation: recommendation)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("friend-recommendation-\(recommendation.id)")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
        }

        private var navigationTitle: LocalizedStringKey {
            switch kind {
            case .recommendations:
                return "friends.recommendations.title"
            }
        }
    }

    struct FriendRecommendationGridLayout: Layout {
        var columnCount = 2
        var spacing: CGFloat = 12

        func sizeThatFits(
            proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
        ) -> CGSize {
            let idealWidth = CGFloat(max(1, columnCount)) * 175
                + CGFloat(max(0, columnCount - 1)) * spacing
            let width = proposal.width.flatMap { $0.isFinite ? max(0, $0) : nil } ?? idealWidth
            let frames = measuredFrames(width: width, subviews: subviews)
            return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
        }

        func placeSubviews(
            in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
        ) {
            let frames = measuredFrames(width: bounds.width, subviews: subviews)
            for (subview, frame) in zip(subviews, frames) {
                subview.place(
                    at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: frame.width, height: frame.height)
                )
            }
        }

        private func measuredFrames(width: CGFloat, subviews: Subviews) -> [CGRect] {
            let proposal = ProposedViewSize(width: columnWidth(in: width), height: nil)
            return frames(width: width, heights: subviews.map { $0.sizeThatFits(proposal).height })
        }

        func frames(width: CGFloat, heights: [CGFloat]) -> [CGRect] {
            let itemWidth = columnWidth(in: width)
            var nextY = Array(repeating: CGFloat.zero, count: max(1, columnCount))
            return heights.map { height in
                let column = nextY.indices.min { nextY[$0] < nextY[$1] } ?? 0
                let frame = CGRect(
                    x: CGFloat(column) * (itemWidth + spacing), y: nextY[column],
                    width: itemWidth, height: height
                )
                nextY[column] = frame.maxY + spacing
                return frame
            }
        }

        private func columnWidth(in width: CGFloat) -> CGFloat {
            max(0, (width - CGFloat(max(0, columnCount - 1)) * spacing)
                / CGFloat(max(1, columnCount)))
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
