import SwiftUI

struct ArtistDescriptionBlock: View {
    let description: String?

    var body: some View {
        if let description, !description.isEmpty {
            Text(description)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
struct ArtistDescriptionBlock_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistDescriptionBlock(
            description: PreviewMockData.featuredArtist.formattedDescription
        )
        .previewMockEnvironment(suiteName: "ArtistDescriptionBlockPreview")
        .previewLayout(.sizeThatFits)
    }
}
#endif
