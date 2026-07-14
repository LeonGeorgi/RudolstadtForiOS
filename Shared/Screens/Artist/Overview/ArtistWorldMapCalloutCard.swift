import SwiftUI

struct ArtistWorldMapCalloutCard: View {
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(
                alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
                spacing: 12
            ) {
                Image(systemName: "globe.europe.africa.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("artists.map.card.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                    Text("artists.map.card.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
