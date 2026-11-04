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
    @EnvironmentObject private var settings: UserSettings
    let currentTipID: String?

    private var systemImageName: String {
        switch settings.artistPresentationMode {
        case .list:
            return ArtistPresentationMode.list.systemImageName
        case .grid:
            return settings.artistGridDensity.systemImageName
        }
    }

    private var selection: Binding<ArtistLayoutOption> {
        Binding {
            switch settings.artistPresentationMode {
            case .list:
                return .list
            case .grid:
                return settings.artistGridDensity == .comfortable
                    ? .comfortableGrid : .compactGrid
            }
        } set: { option in
            switch option {
            case .list:
                settings.artistPresentationMode = .list
            case .comfortableGrid:
                settings.artistGridDensity = .comfortable
                settings.artistPresentationMode = .grid
            case .compactGrid:
                settings.artistGridDensity = .compact
                settings.artistPresentationMode = .grid
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
    @Environment(\.festivalAccentColor) private var festivalAccentColor
    let isActive: Bool

    var body: some View {
        if isActive {
            ZStack {
                Circle()
                    .fill(festivalAccentColor)
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
    @Environment(\.festivalAccentColor) private var festivalAccentColor
    @Environment(\.festivalData) private var festivalData
    @ObservedObject var state: ArtistOverviewState
    let currentTipID: String?
    let browseGenreOptions: [BrowseTaxonomyEntry]
    let localizedBrowseGenreLabel: (String) -> String
    let showWorldMap: () -> Void

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
        ToolbarItemGroup(placement: .topBarLeading) {
            Button(action: showWorldMap) {
                Label("artists.view.world_map", systemImage: "globe.europe.africa")
            }
            .labelStyle(.iconOnly)

            if festivalData.tags.contains(where: \.isDiscoverable) {
                NavigationLink(value: AppNavigationRoute.programDiscovery(tagID: nil)) {
                    Label("program.discovery.title", systemImage: "tag")
                }
                .labelStyle(.iconOnly)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            ArtistPresentationMenu(
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
            .foregroundStyle(state.favoriteArtistsOnly ? festivalAccentColor : Color.primary)
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

                ForEach(festivalData.features.groupings.value?.groupings ?? []) { grouping in
                    Menu {
                        Button("artisttypes.all") { state.selectedGroups.removeValue(forKey: grouping.id) }
                        ForEach(grouping.groups) { group in
                            Button {
                                state.selectedGroups[grouping.id] = group.id
                            } label: {
                                if state.selectedGroups[grouping.id] == group.id {
                                    Label(group.title.resolved(), systemImage: "checkmark")
                                } else { Text(group.title.resolved()) }
                            }
                        }
                    } label: { Text(grouping.title.resolved()) }
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
