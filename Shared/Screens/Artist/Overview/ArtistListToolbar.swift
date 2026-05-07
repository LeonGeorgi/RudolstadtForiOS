import SwiftUI

struct ArtistPresentationModePicker: View {
    @ObservedObject var state: ArtistOverviewState

    var body: some View {
        Menu {
            ForEach(ArtistPresentationMode.allCases, id: \.rawValue) { mode in
                Button {
                    state.selectedPresentationMode = mode
                } label: {
                    if state.selectedPresentationMode == mode {
                        Label(mode.localizedTitle, systemImage: "checkmark")
                    } else {
                        Label(
                            mode.localizedTitle,
                            systemImage: mode.systemImageName
                        )
                    }
                }
            }
        } label: {
            Label(
                state.selectedPresentationMode.localizedTitle,
                systemImage: state.selectedPresentationMode.systemImageName
            )
        }
        .labelStyle(.iconOnly)
    }
}

struct ArtistPresentationModeToolbar: ToolbarContent {
    @ObservedObject var state: ArtistOverviewState

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            ArtistPresentationModePicker(state: state)
        }
    }
}

struct ArtistListToolbar: ToolbarContent {
    @ObservedObject var state: ArtistOverviewState
    let browseGenreOptions: [BrowseTaxonomyEntry]
    let localizedBrowseGenreLabel: (String) -> String

    private var artistTypeMenuTitle: String {
        let title = NSLocalizedString("filter.artisttypes.title", comment: "")
        if let selectedArtistType = state.selectedArtistType {
            return "\(title): \(selectedArtistType.localizedName)"
        }
        return title
    }

    private var genreMenuTitle: String {
        let title = NSLocalizedString("filter.genres.title", comment: "")
        if let selectedBrowseGenreID = state.selectedBrowseGenreID {
            return "\(title): \(localizedBrowseGenreLabel(selectedBrowseGenreID))"
        }
        return title
    }

    @ViewBuilder
    private var filterButtonLabel: some View {
        if !state.hasActiveFilters {
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

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                state.favoriteArtistsOnly.toggle()
            }) {
                if state.favoriteArtistsOnly {
                    Text("artists.all.button")
                } else {
                    Text("artists.favorites.button")
                }
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            ArtistPresentationModePicker(state: state)

            Menu {
                if state.hasActiveFilters {
                    Button("filter.clear") {
                        state.clearFilters()
                    }
                    Divider()
                }

                Menu {
                    Button {
                        state.selectedArtistType = nil
                    } label: {
                        if state.selectedArtistType == nil {
                            Label("artisttypes.all", systemImage: "checkmark")
                        } else {
                            Text("artisttypes.all")
                        }
                    }

                    ForEach(ShownArtistTypes.allCases, id: \.self) { artistType in
                        Button {
                            state.selectedArtistType = artistType
                        } label: {
                            if state.selectedArtistType == artistType {
                                Label(
                                    artistType.localizedName,
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text(artistType.localizedName)
                            }
                        }
                    }
                } label: {
                    Text(artistTypeMenuTitle)
                }

                if !browseGenreOptions.isEmpty {
                    Menu {
                        Button {
                            state.selectedBrowseGenreID = nil
                        } label: {
                            if state.selectedBrowseGenreID == nil {
                                Label(
                                    "filter.genres.all",
                                    systemImage: "checkmark"
                                )
                            } else {
                                Text("filter.genres.all")
                            }
                        }

                        ForEach(browseGenreOptions, id: \.id) { browseGenre in
                            let label = localizedBrowseGenreLabel(browseGenre.id)
                            Button {
                                state.selectedBrowseGenreID = browseGenre.id
                            } label: {
                                if state.selectedBrowseGenreID == browseGenre.id {
                                    Label(label, systemImage: "checkmark")
                                } else {
                                    Text(label)
                                }
                            }
                        }
                    } label: {
                        Text(genreMenuTitle)
                    }
                }
            } label: {
                filterButtonLabel
            }
            .accessibilityLabel(Text("filter.button"))
        }
    }
}
