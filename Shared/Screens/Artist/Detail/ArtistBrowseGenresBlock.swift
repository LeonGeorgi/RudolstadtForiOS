import SwiftUI

struct ArtistBrowseGenresBlock: View {
    let artist: Artist

    @EnvironmentObject var dataStore: DataStore

    private var localizedBrowseGenres: [String] {
        let browseGenreIDs = artist.ai?.browseGenreIDs ?? []
        var seen = Set<String>()
        return browseGenreIDs.compactMap { genreID in
            let label = dataStore.localizedBrowseGenreLabel(for: genreID)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else {
                return nil
            }
            if seen.contains(label) {
                return nil
            }
            seen.insert(label)
            return label
        }
    }

    var body: some View {
        if !localizedBrowseGenres.isEmpty {
            Text(localizedBrowseGenres.joined(separator: " • "))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 26)
        }
    }
}

#if DEBUG
struct ArtistBrowseGenresBlock_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        let environment = PreviewMockData.makeEnvironment(
            suiteName: "ArtistBrowseGenresBlockPreview"
        )
        environment.dataStore.loadExtraData()

        return ArtistBrowseGenresBlock(artist: PreviewMockData.featuredArtist)
            .previewEnvironment(environment)
            .previewLayout(.sizeThatFits)
    }
}
#endif
