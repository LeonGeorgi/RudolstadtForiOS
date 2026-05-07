import SwiftUI

@MainActor
final class ArtistOverviewState: ObservableObject {
    @Published var selectedPresentationMode: ArtistPresentationMode = .grid
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
