import SwiftUI

private enum ArtistLayoutOption: CaseIterable, Hashable {
    case list
    case comfortableGrid
    case compactGrid

    var title: LocalizedStringKey {
        switch self {
        case .list:
            return ArtistPresentationMode.list.localizedTitle
        case .comfortableGrid:
            return ArtistGridDensity.comfortable.localizedTitle
        case .compactGrid:
            return ArtistGridDensity.compact.localizedTitle
        }
    }

    var systemImageName: String {
        switch self {
        case .list:
            return ArtistPresentationMode.list.systemImageName
        case .comfortableGrid:
            return ArtistGridDensity.comfortable.systemImageName
        case .compactGrid:
            return ArtistGridDensity.compact.systemImageName
        }
    }
}

struct ArtistPresentationMenu: View {
    @ObservedObject var state: ArtistOverviewState
    let currentTipID: String?

    private var systemImageName: String {
        switch state.selectedPresentationMode {
        case .list:
            return ArtistPresentationMode.list.systemImageName
        case .grid:
            return state.selectedGridDensity.systemImageName
        }
    }

    private var selection: Binding<ArtistLayoutOption> {
        Binding {
            switch state.selectedPresentationMode {
            case .list:
                return .list
            case .grid:
                return state.selectedGridDensity == .comfortable
                    ? .comfortableGrid : .compactGrid
            }
        } set: { option in
            switch option {
            case .list:
                state.selectedPresentationMode = .list
            case .comfortableGrid:
                state.selectedGridDensity = .comfortable
                state.selectedPresentationMode = .grid
            case .compactGrid:
                state.selectedGridDensity = .compact
                state.selectedPresentationMode = .grid
            }
        }
    }

    var body: some View {
        Menu {
            Picker("artists.view.layout", selection: selection) {
                ForEach(ArtistLayoutOption.allCases, id: \.self) { option in
                    Label(option.title, systemImage: option.systemImageName)
                        .tag(option)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: systemImageName)
        }
        .accessibilityLabel(Text("artists.view.layout"))
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
            ArtistPresentationMenu(
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
