import SwiftUI

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
    @Published var selectedPresentationMode: ArtistPresentationMode = .grid
    @Published var selectedGridDensity: ArtistGridDensity = .comfortable
    @Published var selectedArtistType: ShownArtistTypes? = nil
    @Published var selectedBrowseGenreID: String? = nil
    @Published var searchText = ""
    @Published var favoriteArtistsOnly = false

    var hasActiveFilters: Bool {
        selectedArtistType != nil || selectedBrowseGenreID != nil
    }

    func clearFilters() {
        selectedArtistType = nil
        selectedBrowseGenreID = nil
    }

    func syncBrowseGenreSelection(with browseGenreOptions: [BrowseTaxonomyEntry]) {
        let availableGenreIDs = Set(browseGenreOptions.map(\.id))
        guard let selectedBrowseGenreID else {
            return
        }
        if !availableGenreIDs.contains(selectedBrowseGenreID) {
            self.selectedBrowseGenreID = nil
        }
    }
}
