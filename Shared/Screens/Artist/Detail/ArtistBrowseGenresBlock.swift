import SwiftUI

struct ArtistBrowseGenresBlock: View {
    let artist: Artist

    @EnvironmentObject var dataStore: DataStore

    private var localizedBrowseGenres: [String] {
        let provider = dataStore.features.groupings.value
        return (provider?.groupings ?? []).flatMap { grouping in
            let ids = provider?.groupIDs(for: artist.id, in: grouping.id) ?? []
            return grouping.groups.filter { ids.contains($0.id) }.map { $0.title.resolved() }
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

        return ArtistBrowseGenresBlock(artist: PreviewMockData.featuredArtist)
            .previewEnvironment(environment)
            .previewLayout(.sizeThatFits)
    }
}
#endif
