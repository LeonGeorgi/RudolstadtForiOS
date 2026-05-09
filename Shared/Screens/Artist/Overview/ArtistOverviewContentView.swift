import SwiftUI

struct ArtistOverviewContentView: View {
    let artists: [Artist]
    let selectedPresentationMode: ArtistPresentationMode
    let emptyMessageKey: LocalizedStringKey
    let imageTransitionNamespace: Namespace.ID

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 11),
        count: 3
    )

    private var sortedArtists: [Artist] {
        artists.sorted { first, second in
            normalizedArtistName(first.name) < normalizedArtistName(second.name)
        }
    }

    var body: some View {
        Group {
            if sortedArtists.isEmpty {
                VStack {
                    Spacer()
                    Text(emptyMessageKey)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                    Spacer()
                }
            } else if selectedPresentationMode == .grid {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(sortedArtists) { artist in
                            NavigationLink(
                                value: AppNavigationRoute.artist(
                                    id: artist.id,
                                    highlightedEventId: nil,
                                )
                            ) {
                                ArtistGridCell(
                                    artist: artist,
                                    imageTransitionNamespace: imageTransitionNamespace
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 14)
                }
            } else {
                List {
                    ForEach(sortedArtists) { artist in
                        NavigationLink(
                            value: AppNavigationRoute.artist(
                                id: artist.id,
                                highlightedEventId: nil
                            )
                        ) {
                            ArtistCell(artist: artist)
                        }
                        .listRowInsets(
                            .init(top: 0, leading: 0, bottom: 0, trailing: 16)
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

func normalizedArtistName(_ name: String) -> String {
    name.folding(
        options: [
            .diacriticInsensitive, .caseInsensitive, .widthInsensitive,
        ],
        locale: Locale.current
    )
}
