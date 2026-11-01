import SwiftUI

struct ArtistOverviewCell: View {
    let artist: Artist
    var imageTransitionNamespace: Namespace.ID? = nil
    @EnvironmentObject private var profile: FestivalProfileStore
    @EnvironmentObject private var friends: FriendProfilesStore

    var body: some View {
        let rating = profile.rating(for: artist.id)
        let icon = profile.iconName(forArtistID: artist.id)
        let summary = friends.friendArtistRatingSummary(for: artist.id)
        if let imageTransitionNamespace {
            ArtistGridCell(
                artist: artist, imageTransitionNamespace: imageTransitionNamespace,
                artistRating: rating, artistIconName: icon, friendRatingSummary: summary)
        } else {
            ArtistCell(
                artist: artist, artistRating: rating, artistIconName: icon,
                friendRatingSummary: summary)
        }
    }
}

struct ArtistCell: View {
    let artist: Artist
    let artistRating: Int
    let artistIconName: String?
    let friendRatingSummary: FriendArtistRatingSummary?

    var body: some View {
        FestivalListRow {
            ArtistListRowImage(artist: artist)
        } content: {
            FestivalListRowTitle(artist.formattedName)
        } accessories: {
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
