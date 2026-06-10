import Foundation
import SwiftUI

struct ArtistListView: View {
    let navigate: (AppNavigationRoute) -> Void
    private let imageTransitionNamespace: Namespace.ID?

    @Environment(\.festivalData) private var festivalData
    @EnvironmentObject var settings: UserSettings
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
            let artistTypeMatches: Bool
            if let selectedArtistType = overviewState.selectedArtistType {
                artistTypeMatches =
                    selectedArtistType
                    == ShownArtistTypes(artistType: artist.artistType)
            } else {
                artistTypeMatches = true
            }

            if browseGenreOptions.isEmpty {
                return !artist.hiddenFromArtistList && artistTypeMatches
            }

            let browseGenreMatches: Bool
            if let selectedBrowseGenreID = overviewState.selectedBrowseGenreID {
                let artistBrowseGenreIDs = artist.ai?.browseGenreIDs ?? []
                browseGenreMatches = artistBrowseGenreIDs.contains(
                    selectedBrowseGenreID
                )
            } else {
                browseGenreMatches = true
            }

            return !artist.hiddenFromArtistList
                && artistTypeMatches
                && browseGenreMatches
        }
    }

    private func artistsToShow(from artists: [Artist]) -> [Artist] {
        if overviewState.favoriteArtistsOnly {
            let artistsWithRatings = artists.map { artist in
                (artist: artist, rating: profile.ratings[String(artist.id)])
            }
            let filteredArtists = artistsWithRatings.filter { item in
                item.rating != nil && item.rating! > 0
            }
            let sortedArtists = filteredArtists.sorted { first, second in
                first.rating! > second.rating!
            }
            return sortedArtists.map(\.artist)
        } else {
            return artists
        }
    }

    var body: some View {
        let artists = artistsToShow(
            from: filteredArtists(from: festivalData)
        ).withApplied(searchTerm: overviewState.searchText) { artist in
            artist.name
        }

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
            let restoredMode =
                ArtistPresentationMode(rawValue: settings.artistViewType) ?? .grid
            overviewState.selectedPresentationMode = restoredMode
            if settings.artistViewType != restoredMode.rawValue {
                settings.artistViewType = restoredMode.rawValue
            }
        }
        .onChange(of: overviewState.selectedPresentationMode) { _, newMode in
            settings.artistViewType = newMode.rawValue
        }
        .onChange(of: dataStore.browseTaxonomy, initial: false) { _, _ in
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
