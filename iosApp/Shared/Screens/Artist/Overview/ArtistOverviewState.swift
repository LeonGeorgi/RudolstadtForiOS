import SwiftUI
import RudolstadtCore

enum ArtistGridDensity: Int, CaseIterable {
    case comfortable = 2
    case compact = 3

    var systemImageName: String {
        switch self {
        case .comfortable:
            return "square.grid.2x2"
        case .compact:
            return "square.grid.3x3"
        }
    }

    var localizedTitle: LocalizedStringKey {
        switch self {
        case .comfortable:
            return "artists.grid.comfortable"
        case .compact:
            return "artists.grid.compact"
        }
    }
}

@MainActor
final class ArtistOverviewState: ObservableObject {
    private let viewModel = DiscoveryViewModel()
    private var observation: StateSubscription?
    var selectedArtistType: ShownArtistTypes? {
        get { ShownArtistTypes.allCases.first { String(describing: $0) == viewModel.current.artistType } }
        set { viewModel.selectType(value: newValue.map { String(describing: $0) }) }
    }
    var selectedBrowseGenreID: String? {
        get { viewModel.current.browseGenre }
        set { viewModel.selectGenre(value: newValue) }
    }
    var selectedGroups: [String: String] {
        get { viewModel.current.groups }
        set { viewModel.selectGroups(value: newValue) }
    }
    var searchText: String {
        get { viewModel.current.search }
        set { viewModel.search(value: newValue) }
    }
    var favoriteArtistsOnly: Bool {
        get { viewModel.current.favoritesOnly }
        set { viewModel.favoritesOnly(value: newValue) }
    }
    init() { observation = viewModel.observe { [weak self] _ in self?.objectWillChange.send() } }
    deinit { observation?.cancel() }
    var hasActiveFilters: Bool { viewModel.current.hasActiveFilters }
    func clearFilters() { viewModel.clearFilters() }
    func syncBrowseGenreSelection(with browseGenreOptions: [BrowseTaxonomyEntry]) {
        viewModel.availableGenres(ids: Set(browseGenreOptions.map(\.id)))
    }
}
