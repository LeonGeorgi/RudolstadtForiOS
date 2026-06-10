import SwiftUI

struct ScheduleEventCell: View {
    let event: Event
    let isSaved: Bool
    let artistRating: Int
    let artistIconName: String?
    let friendProfilesWhoSavedEvent: [SharedFestivalProfile]
    let onToggleSaved: () -> Void

    @State private var showingAlert = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    HStack(alignment: .center) {
                        ArtistImageView(artist: event.artist, fullImage: false)
                            .frame(width: 60, height: 52.5)

                        VStack(alignment: .leading) {
                            if event.tag != nil {
                                Text(event.tag!.localizedName.uppercased())
                                    .font(.system(size: 11))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Text(event.artist.formattedName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)

                            Text(
                                "\(event.timeAsString) (\(event.stage.localizedName))"
                            )
                            .lineLimit(1)
                            .font(.subheadline)

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
                        EventSavedIcon(event: event, isSaved: isSaved, onToggle: onToggleSaved)
                    }
                }
            }
        }
        .contextMenu {
            SaveEventButton(event: event, isSaved: isSaved, onToggle: onToggleSaved)
        }
        .id("\(event.id)-\(isSaved)")
    }
}

struct ScheduleEventCell_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleEventCell(
            event: .example,
            isSaved: false,
            artistRating: 0,
            artistIconName: nil,
            friendProfilesWhoSavedEvent: [],
            onToggleSaved: {}
        )
    }
}
