//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

struct ArtistListView: View {
    let navigate: (AppNavigationRoute) -> Void

    @EnvironmentObject var settings: UserSettings
    @EnvironmentObject var dataStore: DataStore

    @StateObject private var overviewState = ArtistOverviewState()
    @StateObject private var tipSequencer = TipSequencer(
        DiscoverabilityTipSequences.artistScreen
    )
    @Namespace private var artistImageTransition

    init(
        navigate: @escaping (AppNavigationRoute) -> Void = { _ in }
    ) {
        self.navigate = navigate
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
                (artist: artist, rating: settings.ratings[String(artist.id)])
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
        LoadingListView(
            noDataMessage: "artists.none-found",
            noDataSubtitle: nil,
            dataMapper: { data in
                artistsToShow(
                    from: filteredArtists(from: data)
                ).withApplied(searchTerm: overviewState.searchText) { artist in
                    artist.name
                }
            }
        ) { artists in
            ArtistBrowseView(
                artists: artists,
                state: overviewState,
                currentTipID: tipSequencer.currentTipID,
                browseGenreOptions: browseGenreOptions,
                localizedBrowseGenreLabel: dataStore.localizedBrowseGenreLabel,
                navigationTitleKey: navigationTitleKey,
                imageTransitionNamespace: artistImageTransition,
                navigate: navigate
            )
            .onAppear {
                print(
                    "[ArtistWorldMap] ArtistListView content appeared mode=\(overviewState.selectedPresentationMode.rawValue) artists=\(artists.count)"
                )
            }
        }
        .task {
            print("[ArtistWorldMap] ArtistListView.task start")
            ArtistWorldMapView.preloadResources()
            let restoredMode =
                ArtistPresentationMode(rawValue: settings.artistViewType) ?? .grid
            overviewState.selectedPresentationMode = restoredMode
            if settings.artistViewType != restoredMode.rawValue {
                settings.artistViewType = restoredMode.rawValue
            }
            print(
                "[ArtistWorldMap] ArtistListView.task restored mode=\(overviewState.selectedPresentationMode.rawValue)"
            )
        }
        .onChange(of: overviewState.selectedPresentationMode) { _, newMode in
            settings.artistViewType = newMode.rawValue
        }
        .onChange(of: dataStore.browseTaxonomy) {
            overviewState.syncBrowseGenreSelection(
                with: browseGenreOptions
            )
        }
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
            .environmentObject(DataStore())
    }
}
