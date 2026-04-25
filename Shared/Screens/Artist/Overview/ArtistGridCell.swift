import SwiftUI

struct ArtistGridCell: View {
    let artist: Artist
    let imageTransitionNamespace: Namespace.ID
    @EnvironmentObject var settings: UserSettings

    private var artistRating: Int {
        settings.ratings["\(artist.id)"] ?? 0
    }

    private var artistSymbol: String? {
        settings.getArtistIcon(for: artist)
    }

    private var flags: String? {
        let value = (artist.ai?.flags ?? []).joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private var countryAndFlags: String? {
        let country = artist.countries.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let value = [country, flags]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))

                ArtistImageView(artist: artist, fullImage: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ratingBadge
                    .padding(8)
            }
            .aspectRatio(8 / 7, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 0.5)
            )
            .artistImageTransitionSource(
                id: artist.id,
                namespace: imageTransitionNamespace
            )

            Text(artist.formattedName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.94)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let countryAndFlags {
                Text(countryAndFlags)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.94)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var ratingBadge: some View {
        if artistRating > 0 {
            HStack(spacing: 4) {
                ForEach(0..<artistRating, id: \.self) { _ in
                    Image(systemName: settings.likeIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(.black.opacity(0.7))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
        } else if artistRating < 0 {
            HStack(spacing: 5) {
                Image(systemName: artistSymbol ?? "hand.thumbsdown.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Noted")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(.black.opacity(0.7))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
        } else {
            Color.clear
        }
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
