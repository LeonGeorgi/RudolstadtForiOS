import SwiftUI

struct SharedProfileSavedEventRow: View {
    let event: Event
    var isSavedByCurrentUser = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            EventTimeBadge(event: event)

            VStack(alignment: .leading, spacing: 3) {
                if let tag = event.tag {
                    Text(tag.localizedName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.72))
                        .lineLimit(1)
                }

                Text(event.artist.formattedName)
                    .font(.headline)
                    .lineLimit(2)

                Text(event.stage.localizedName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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
        HStack(spacing: 12) {
            ArtistImageView(artist: artist, fullImage: false)
                .frame(width: 60, height: 52.5)
                .clipShape(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )

            Text(artist.formattedName)
                .font(.headline)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            SharedProfileArtistPreferenceBadge(preference: preference)
        }
        .padding(.vertical, 2)
    }
}

private struct SharedProfileArtistPreferenceBadge: View {
    let preference: FestivalArtistPreference

    @EnvironmentObject private var settings: UserSettings

    var body: some View {
        if preference.rating > 0 {
            HStack(spacing: 2) {
                ForEach(0..<preference.rating, id: \.self) { _ in
                    Image(systemName: settings.likeIcon)
                }
            }
            .foregroundStyle(.red)
        } else if let iconName = preference.iconName, preference.rating < 0 {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
        } else {
            Text("No rating")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
