import SwiftUI

struct SharedProfileSavedEventRow: View {
    let event: Event
    var isSavedByCurrentUser = false

    var body: some View {
        FestivalListRow(hasThirdLine: event.tag != nil) {
            EventTimeBadge(event: event)
        } content: {
            if let tag = event.tag {
                Text(tag.localizedName.uppercased())
                    .font(FestivalListRowStyle.tagFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            FestivalListRowTitle(event.artist.formattedName)

            Text(event.stage.localizedName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } accessories: {
            if isSavedByCurrentUser {
                Label("friends.detail.saved_with_you", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("friends.detail.saved_with_you")
            }
        }
        .padding(.vertical, 2)
    }
}

struct SharedProfileRatedArtistRow: View {
    let artist: Artist
    let preference: FestivalArtistPreference

    var body: some View {
        FestivalListRow {
            ArtistListRowImage(artist: artist)
        } content: {
            FestivalListRowTitle(artist.formattedName)
        } accessories: {
            if preference.rating != 0 {
                ArtistRatingSymbol(rating: preference.rating, iconName: preference.iconName)
                    .foregroundStyle(.secondary)
            } else {
                Text("No rating")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
