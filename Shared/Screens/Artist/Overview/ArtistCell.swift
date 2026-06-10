import SwiftUI

struct ArtistCell: View {
    let artist: Artist
    let artistRating: Int
    let artistIconName: String?
    let friendRatingSummary: FriendArtistRatingSummary?

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ArtistImageView(artist: artist, fullImage: false)
                    .frame(width: 60, height: 52.5)
                
            }
            HStack(alignment: .center, spacing: 4) {
                Text(artist.formattedName)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let friendRatingSummary {
                    FriendArtistRatingsBubble(
                        summary: friendRatingSummary,
                        style: .plainInline
                    )
                    .frame(minHeight: 24, alignment: .center)
                }
                ArtistRatingListSlot(
                    rating: artistRating,
                    iconName: artistIconName,
                    reservesSpace: friendRatingSummary != nil
                )

            }
        }
    }
}

struct ArtistRatingListSlot: View {
    let rating: Int
    let iconName: String?
    let reservesSpace: Bool

    private let slotSize: CGFloat = 21

    var body: some View {
        if rating != 0 {
            CompactArtistRatingSymbol(
                rating: rating,
                iconName: iconName
            )
            .frame(width: slotSize, height: slotSize)
        } else if reservesSpace {
            Color.clear
                .frame(width: slotSize, height: slotSize)
                .accessibilityHidden(true)
        }
    }
}

struct ArtistListItem_Previews: PreviewProvider {
    static var previews: some View {
        ArtistCell(
            artist: .example,
            artistRating: 0,
            artistIconName: nil,
            friendRatingSummary: nil
        )
            .environmentObject(DataStore())
    }
}
