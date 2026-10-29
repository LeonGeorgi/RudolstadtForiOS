import Foundation
import SwiftUI

struct ArtistListView: View {
    let navigate: (AppNavigationRoute) -> Void
    private let imageTransitionNamespace: Namespace.ID?

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject private var dataStore: DataStore
    @Environment(\.locale) private var locale
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

    var body: some View {
        let genres = dataStore.browseTaxonomy.map {
            ($0, dataStore.localizedBrowseGenreLabel(for: $0.id))
        }
        .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }.map(\.0)
        ArtistFilteredListView(
            index: dataStore.artistOverviewIndex(for: festivalData.artists, locale: locale),
            browseGenreOptions: genres,
            localizedBrowseGenreLabel: dataStore.localizedBrowseGenreLabel,
            imageTransitionNamespace: resolvedImageTransitionNamespace, navigate: navigate)
    }
}

private struct ArtistFilteredListView: View {
    let index: ArtistOverviewIndex
    let browseGenreOptions: [BrowseTaxonomyEntry]
    let localizedBrowseGenreLabel: (String) -> String
    let imageTransitionNamespace: Namespace.ID
    let navigate: (AppNavigationRoute) -> Void
    @Environment(\.locale) private var locale
    @EnvironmentObject private var profile: FestivalProfileStore
    @StateObject private var overviewState = ArtistOverviewState()
    @StateObject private var tipSequencer = TipSequencer(DiscoverabilityTipSequences.artistScreen)

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

    var body: some View {
        let artists = index.matching(
            favoritesOnly: overviewState.favoriteArtistsOnly, ratings: profile.ratings,
            searchTerm: overviewState.searchText, selectedGroups: overviewState.selectedGroups,
            locale: locale)

        ArtistBrowseView(
            artists: artists,
            state: overviewState,
            currentTipID: tipSequencer.currentTipID,
            emptyMessageKey: emptyMessageKey,
            browseGenreOptions: browseGenreOptions,
            localizedBrowseGenreLabel: localizedBrowseGenreLabel,
            navigationTitleKey: navigationTitleKey,
            imageTransitionNamespace: imageTransitionNamespace,
            navigate: navigate
        )
        .task {
            ArtistWorldMapView.preloadResources()
        }
        .onChange(of: browseGenreOptions, initial: false) { _, _ in
            overviewState.syncBrowseGenreSelection(
                with: browseGenreOptions
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
