import SwiftUI

struct StageEventCell: View {
    let event: Event
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let isSaved: Bool
    let artistRating: Int
    let artistIconName: String?
    let friendProfilesWhoSavedEvent: [SharedFestivalProfile]
    let onToggleSaved: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 12) {
                    ArtistImageView(artist: event.artist, fullImage: false)
                        .frame(width: imageWidth, height: imageHeight)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: 14,
                                style: .continuous
                            )
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        if event.tag != nil {
                            Text(event.tag!.localizedName.uppercased())
                                .font(.system(size: 11))
                                .fontWeight(.semibold)
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                        }
                        Text(event.artist.formattedName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(event.timeAsString)
                            .lineLimit(1)
                            .font(.subheadline)
                    }
                }
            }
            Spacer()
            if artistRating != 0 {
                ArtistRatingSymbol(rating: artistRating, iconName: artistIconName)
                    .foregroundStyle(.secondary)
            }
            if !friendProfilesWhoSavedEvent.isEmpty {
                FriendSavedEventBadges(
                    eventID: event.id,
                    profiles: friendProfilesWhoSavedEvent,
                    style: .plainInline
                )
                .frame(minWidth: 24, minHeight: 24, alignment: .center)
            }
            EventSavedIcon(event: self.event, isSaved: isSaved, onToggle: onToggleSaved)
        }
        .contextMenu {
            SaveEventButton(event: event, isSaved: isSaved, onToggle: onToggleSaved)
        }
        .id("\(event.id)-\(isSaved)")
    }
}

struct StageEventCell_Previews: PreviewProvider {
    static var previews: some View {
        StageEventCell(
            event: .example,
            imageWidth: 64,
            imageHeight: 56,
            isSaved: false,
            artistRating: 0,
            artistIconName: nil,
            friendProfilesWhoSavedEvent: [],
            onToggleSaved: {}
        )
            .environmentObject(UserSettings())
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}
