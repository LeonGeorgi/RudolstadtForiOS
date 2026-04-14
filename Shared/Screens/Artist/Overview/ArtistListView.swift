//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

// import URLImage

struct ArtistListView: View {

    @EnvironmentObject var settings: UserSettings

    @State private var shownArtistTypes = Set(ShownArtistTypes.allCases)

    @State var searchText = ""
    @State var favoriteArtistsOnly = false

    let grid = true

    func normalize(string: String) -> String {
        string.folding(
            options: [
                .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
            ],
            locale: Locale.current
        )
    }

    func getFilteredArtists(data: FestivalData) -> [Artist] {
        data.artists.filter { artist in
            shownArtistTypes.contains(ShownArtistTypes(artistType: artist.artistType))
        }
    }

    private var allArtistTypesSelected: Bool {
        shownArtistTypes.count == ShownArtistTypes.allCases.count
    }

    private func showAllArtistTypes() {
        shownArtistTypes = Set(ShownArtistTypes.allCases)
    }

    private func binding(for artistType: ShownArtistTypes) -> Binding<Bool> {
        Binding(
            get: {
                shownArtistTypes.contains(artistType)
            },
            set: { isSelected in
                if isSelected {
                    shownArtistTypes.insert(artistType)
                } else {
                    shownArtistTypes.remove(artistType)
                }
            }
        )
    }

    @ViewBuilder
    private var filterButtonLabel: some View {
        if allArtistTypesSelected {
            Image(systemName: "line.3.horizontal.decrease.circle")
        } else {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 26, height: 26)
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    func generateArtistsToShow(artists: [Artist]) -> [Artist] {
        if favoriteArtistsOnly {
            let artists = artists.map { artist in
                (artist: artist, rating: settings.ratings[String(artist.id)])
            }
            let filteredArtists = artists.filter { item in
                item.rating != nil && item.rating! > 0
            }
            let sortedArtists = filteredArtists.sorted { first, second in
                first.rating! > second.rating!
            }
            return sortedArtists.map { artist, rating in
                artist
            }
        } else {
            return artists
        }
    }

    var body: some View {
        NavigationView {

            LoadingListView(
                noDataMessage: "artists.none-found",
                noDataSubtitle: nil,
                dataMapper: { data in
                    generateArtistsToShow(
                        artists: getFilteredArtists(data: data)
                    ).withApplied(searchTerm: searchText) { artist in
                        artist.name
                    }
                }
            ) { artists in
                List {
                    ForEach(
                        artists.sorted(by: { a1, a2 in
                            normalize(string: a1.name)
                                < normalize(string: a2.name)
                        })
                    ) { (artist: Artist) in
                        NavigationLink(
                            destination: ArtistDetailView(
                                artist: artist,
                                highlightedEventId: nil
                            )
                        ) {
                            ArtistCell(artist: artist)
                        }.listRowInsets(
                            .init(top: 0, leading: 0, bottom: 0, trailing: 16)
                        )
                    }
                }.listStyle(.plain)
            }
            .searchable(text: $searchText)
            .disableAutocorrection(true)
            .navigationBarTitle(
                favoriteArtistsOnly ? "rated_artists.title" : "artists.title"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        favoriteArtistsOnly.toggle()
                    }) {
                        if favoriteArtistsOnly {
                            Text("artists.all.button")
                        } else {
                            Text("artists.favorites.button")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(ShownArtistTypes.allCases, id: \.self) { artistType in
                            Toggle(isOn: binding(for: artistType)) {
                                Text(artistType.localizedName)
                            }
                        }

                        if !allArtistTypesSelected {
                            Divider()

                            Button("artisttypes.all") {
                                showAllArtistTypes()
                            }
                        }
                    } label: {
                        filterButtonLabel
                    }
                    .accessibilityLabel(Text("filter.button"))
                }
            }
        }
    }
}

enum ShownArtistTypes: CaseIterable, Hashable {
    case stage, street, dance, other

    init(artistType: ArtistType) {
        switch artistType {
        case .stage:
            self = .stage
        case .street:
            self = .street
        case .dance:
            self = .dance
        case .other:
            self = .other
        }
    }

    var localizedName: String {
        switch self {
        case .stage:
            return ArtistType.stage.localizedName
        case .street:
            return ArtistType.street.localizedName
        case .dance:
            return ArtistType.dance.localizedName
        case .other:
            return ArtistType.other.localizedName
        }
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView()
            .environmentObject(DataStore())
    }
}
