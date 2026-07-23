import SwiftUI

struct StageEventCell: View {
    let event: Event
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let contextPreviewState: EventContextPreviewState
    let onToggleSaved: () -> Void

    private var isSaved: Bool {
        contextPreviewState.isSaved
    }

    private var artistRating: Int {
        contextPreviewState.artistRating
    }

    private var artistIconName: String? {
        contextPreviewState.artistIconName
    }

    private var friendProfilesWhoSavedEvent: [SharedFestivalProfile] {
        contextPreviewState.friendProfilesWhoSavedEvent
    }

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
        } preview: {
            EventContextPreview(
                event: event,
                state: contextPreviewState
            )
        }
        .accessibilityIdentifier("event-\(event.id)")
    }
}

struct StageEventCell_Previews: PreviewProvider {
    static var previews: some View {
        StageEventCell(
            event: .example,
            imageWidth: 64,
            imageHeight: 56,
            contextPreviewState: EventContextPreviewState(
                isSaved: false,
                artistRating: 0,
                artistIconName: nil,
                friendProfilesWhoSavedEvent: [],
                artistNote: nil,
                isArtistSummaryEnabled: true
            ),
            onToggleSaved: {}
        )
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}
