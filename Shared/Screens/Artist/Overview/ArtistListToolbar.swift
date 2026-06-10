import SwiftUI

private extension ArtistPresentationMode {
    var toggledMode: ArtistPresentationMode {
        switch self {
        case .list:
            return .grid
        case .grid:
            return .list
        }
    }
}

struct ArtistPresentationModeToggleButton: View {
    @ObservedObject var state: ArtistOverviewState
    let currentTipID: String?
    
    var body: some View {
        let nextMode = state.selectedPresentationMode.toggledMode
        
        Button {
            state.selectedPresentationMode = nextMode
        } label: {
            Label(nextMode.localizedTitle, systemImage: nextMode.systemImageName)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(nextMode.localizedTitle)
        .appPopoverTip(
            DiscoverabilityTips.artistViewMode,
            currentTipID: currentTipID,
            arrowEdge: .top
        )
    }
}

struct FilterToolbarIcon: View {
    let isActive: Bool
    
    var body: some View {
        if isActive {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 26, height: 26)
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
        } else {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.primary)
        }
    }
}

struct ArtistListToolbar: ToolbarContent {
    @ObservedObject var state: ArtistOverviewState
    let currentTipID: String?
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
    
    var body: some ToolbarContent {
        
        ToolbarItem(placement: .topBarTrailing) {
            ArtistPresentationModeToggleButton(
                state: state,
                currentTipID: currentTipID
            )
        }
        
        if #available(iOS 26.0, macOS 26.0, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        
        ToolbarItemGroup(placement: .topBarTrailing) {
            
            Button(action: {
                state.favoriteArtistsOnly.toggle()
            }) {
                Image(
                    systemName: state.favoriteArtistsOnly ? "heart.fill" : "heart"
                )
            }
            .foregroundStyle(state.favoriteArtistsOnly ? Color.accentColor : Color.primary)
            .accessibilityLabel(
                state.favoriteArtistsOnly
                ? Text("artists.all.button")
                : Text("artists.favorites.button")
            )
            .appPopoverTip(
                DiscoverabilityTips.artistFavorites,
                currentTipID: currentTipID,
                arrowEdge: .top
            )
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
                FilterToolbarIcon(isActive: state.hasActiveFilters)
            }
            .accessibilityLabel(Text("filter.button"))
            .appPopoverTip(
                DiscoverabilityTips.artistFilters,
                currentTipID: currentTipID,
                arrowEdge: .top
            )
        }
    }
}
