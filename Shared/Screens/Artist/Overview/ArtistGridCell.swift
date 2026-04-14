import SwiftUI

struct ArtistGridCell: View {
    let artist: Artist
    let imageTransitionNamespace: Namespace.ID
    @EnvironmentObject var settings: UserSettings

    private var artistRating: Int {
        settings.ratings["\(artist.id)"] ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            let imageWidth = proxy.size.width
            let imageHeight = imageWidth * 7 / 8

            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))

                    ArtistImageView(artist: artist, fullImage: true)
                        .frame(width: imageWidth, height: imageHeight)
                        .clipped()

                    if artistRating != 0 {
                        ArtistRatingSymbol(artist: artist)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .padding(5)
                            .background(.thinMaterial, in: Circle())
                            .padding(4)
                    }
                }
                .frame(width: imageWidth, height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 0.5)
                )
                .artistImageTransitionSource(
                    id: artist.id,
                    namespace: imageTransitionNamespace
                )

                Text(artist.formattedName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .lineSpacing(1)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .frame(height: 36, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(width: imageWidth, alignment: .topLeading)
        }
        .aspectRatio(0.74, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ArtistGridCellPreview: View {
    @Namespace private var namespace

    var body: some View {
        ArtistGridCell(artist: .example, imageTransitionNamespace: namespace)
            .environmentObject(UserSettings())
    }
}

struct ArtistGridCell_Previews: PreviewProvider {
    static var previews: some View {
        ArtistGridCellPreview()
    }
}
