import SwiftUI

struct ArtistDescriptionBlock: View {
    let description: String?
    let backgroundColor: Color

    var body: some View {
        if let description, !description.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(description)
                    .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
        }
    }
}

#if DEBUG
struct ArtistDescriptionBlock_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        ArtistDescriptionBlock(
            description: PreviewMockData.featuredArtist.formattedDescription,
            backgroundColor: .clear
        )
        .previewMockEnvironment(suiteName: "ArtistDescriptionBlockPreview")
        .previewLayout(.sizeThatFits)
    }
}
#endif
