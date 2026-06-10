import SwiftUI

struct ArtistWorldMapCalloutCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Spacer()
                
                Image(systemName: "globe.europe.africa.fill")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)

                Text("artists.map.card.title")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Capsule()
                .fill(.secondary.opacity(0.12))
            )
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
