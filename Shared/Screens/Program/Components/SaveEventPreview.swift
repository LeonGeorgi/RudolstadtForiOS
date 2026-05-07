import SwiftUI

struct SaveEventPreview: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        VStack(alignment: .leading) {
            ArtistImageView(artist: event.artist, fullImage: true)
                // set to 3:4 frame with width 100% of parent
                .frame(width: 200, height: 150)
                .aspectRatio(3 / 4, contentMode: .fill)
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text("\(event.shortWeekDay) \(event.timeAsString)")
                    .font(.subheadline)
                    // as pill
                    .padding(5)
                    .background(getColorForEvent(event).opacity(0.2))
                    .foregroundColor(getColorForEvent(event))
                    .cornerRadius(10)
                
                Text(event.artist.formattedName)
                    .font(.headline)
                    .lineLimit(2)
                if let tag = event.tag {
                    Text(tag.localizedName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if let ai = event.artist.ai, let aiSummary = ai.localizedSummary, !aiSummary.isEmpty {
                    Text(aiSummary)
                        .font(.subheadline)
                }

            }
            .padding(.top, 0)
            .padding(.horizontal, 5)
            .padding(.bottom, 5)
        }
        .frame(width: 200)
    }

    func getColorForEvent(_ event: Event) -> Color {
        switch event.artist.artistType {
        case .stage:
            return Color.artistTypeStageSaved
        case .dance:
            return Color.artistTypeDanceSaved
        case .street:
            return Color.artistTypeStreetSaved
        case .other:
            return Color.artistTypeOtherSaved
        }
    }
}

struct SaveEventPreview_Previews: PreviewProvider {
    static var previews: some View {
        SaveEventPreview(event: .example)
            .environmentObject(UserSettings())
            .frame(width: 400, height: 400)
    }
}
