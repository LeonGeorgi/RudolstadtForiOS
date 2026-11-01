import Foundation
import SwiftUI

struct ArtistListView: View {
    let navigate: (AppNavigationRoute) -> Void
    private let imageTransitionNamespace: Namespace.ID?

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject var profile: FestivalProfileStore
    @EnvironmentObject var dataStore: DataStore

    @StateObject private var overviewState = ArtistOverviewState()
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.artistScreen
    )
    @Namespace private var localArtistImageTransition

    init(
        imageTransitionNamespace: Namespace.ID? = nil,
        navigate: @escaping (AppNavigationRoute) -> Void = { _ in }
    ) {
        self.imageTransitionNamespace = imageTransitionNamespace
        self.navigate = navigate
    }

    private var resolvedImageTransitionNamespace: Namespace.ID {
        imageTransitionNamespace ?? localArtistImageTransition
    }

    private var browseGenreOptions: [BrowseTaxonomyEntry] {
        dataStore.browseTaxonomy.sorted { lhs, rhs in
            dataStore.localizedBrowseGenreLabel(for: lhs.id)
                .localizedCaseInsensitiveCompare(
                    dataStore.localizedBrowseGenreLabel(for: rhs.id)
                ) == .orderedAscending
        }
    }

    private var navigationTitleKey: LocalizedStringKey {
        overviewState.favoriteArtistsOnly
            ? "rated_artists.title" : "artists.title"
    }

    private var emptyMessageKey: LocalizedStringKey {
        if overviewState.favoriteArtistsOnly
            && !overviewState.hasActiveFilters
            && overviewState.searchText.isEmpty
        {
            return "artists.saved.empty"
        }
        return "artists.none-found"
    }

    private func filteredArtists(from data: FestivalData) -> [Artist] {
        data.artists.filter { artist in
            !artist.hiddenFromArtistList && overviewState.selectedGroups.allSatisfy { groupingID, groupID in
                artist.groupIDs[groupingID]?.contains(groupID) == true
            }
        }
    }

    var body: some View {
        let artists = artistsForOverview(
            filteredArtists(from: festivalData),
            favoritesOnly: overviewState.favoriteArtistsOnly,
            ratings: profile.ratings,
            searchTerm: overviewState.searchText
        )

        ArtistBrowseView(
            artists: artists,
            state: overviewState,
            currentTipID: tipSequencer.currentTipID,
            emptyMessageKey: emptyMessageKey,
            browseGenreOptions: browseGenreOptions,
            localizedBrowseGenreLabel: dataStore.localizedBrowseGenreLabel,
            navigationTitleKey: navigationTitleKey,
            imageTransitionNamespace: resolvedImageTransitionNamespace,
            navigate: navigate
        )
        .task {
            ArtistWorldMapView.preloadResources()
        }
        .onChange(of: dataStore.browseTaxonomy, initial: false) { _, _ in
            overviewState.syncBrowseGenreSelection(
                with: dataStore.browseTaxonomy
            )
        }
    }
}

#if DEBUG
struct ArtistListView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            ArtistListView()
                .navigationDestination(for: AppNavigationRoute.self) { _ in
                    EmptyView()
                }
        }
        .previewMockEnvironment(suiteName: "ArtistListViewPreview")
    }
}
#endif
