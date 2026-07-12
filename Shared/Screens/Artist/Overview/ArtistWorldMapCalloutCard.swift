import SwiftUI

struct ArtistWorldMapCalloutCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("artists.map.card.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("artists.map.card.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("artists.map.card.title"))
        .accessibilityHint(Text("artists.map.card.subtitle"))
    }
}

#if DEBUG
struct ArtistWorldMapCalloutCard_Previews: PreviewProvider {
    static var previews: some View {
        ArtistWorldMapCalloutCard {}
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
