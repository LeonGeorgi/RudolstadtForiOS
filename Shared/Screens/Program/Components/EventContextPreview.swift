import SwiftUI

struct EventContextPreviewState {
    let isSaved: Bool
    let artistRating: Int
    let artistIconName: String?
    let friendProfilesWhoSavedEvent: [SharedFestivalProfile]
    let artistNote: String?
    let isArtistSummaryEnabled: Bool
    let likeIconName: String

    @MainActor
    init(
        event: Event,
        profile: FestivalProfileStore,
        settings: UserSettings
    ) {
        isSaved = profile.isEventSaved(event.id)
        artistRating = profile.rating(for: event.artist.id)
        artistIconName = profile.iconName(forArtistID: event.artist.id)
        friendProfilesWhoSavedEvent = profile.friendProfilesSavingEvent(event.id)
        artistNote = profile.noteText(for: event.artist)
        isArtistSummaryEnabled = settings.aiSummaryEnabled
        likeIconName = settings.likeIcon
    }

    init(
        isSaved: Bool,
        artistRating: Int,
        artistIconName: String?,
        friendProfilesWhoSavedEvent: [SharedFestivalProfile],
        artistNote: String?,
        isArtistSummaryEnabled: Bool,
        likeIconName: String = "heart.fill"
    ) {
        self.isSaved = isSaved
        self.artistRating = artistRating
        self.artistIconName = artistIconName
        self.friendProfilesWhoSavedEvent = friendProfilesWhoSavedEvent
        self.artistNote = artistNote
        self.isArtistSummaryEnabled = isArtistSummaryEnabled
        self.likeIconName = likeIconName
    }
}

struct EventContextPreview: View {
    private enum Layout {
        static let width: CGFloat = 272
        static let accessibilityWidth: CGFloat = 300
        static let imageHeight: CGFloat = 150
        static let accessibilityImageHeight: CGFloat = 132
    }

    let event: Event
    let state: EventContextPreviewState

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    private var previewWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityWidth
            : Layout.width
    }

    private var imageHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Layout.accessibilityImageHeight
            : Layout.imageHeight
    }

    private var artistNote: String? {
        guard
            let note = state.artistNote?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !note.isEmpty
        else {
            return nil
        }
        return note
    }

    private var artistSummary: String? {
        guard
            state.isArtistSummaryEnabled,
            let summary = event.artist.ai?
                .localizedSummary(locale: locale)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !summary.isEmpty
        else {
            return nil
        }
        return summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArtistImageView(
                artist: event.artist,
                fullImage: true,
                loadingStyle: .quiet
            )
            .frame(width: previewWidth, height: imageHeight)
            .clipped()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    Text(event.artist.formattedName)
                        .font(.title3.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    HStack(spacing: 8) {
                        if state.artistRating != 0 {
                            ratingSymbol
                        }

                        if state.isSaved {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(tintColor)
                                .accessibilityLabel(Text("event.saved.value.saved"))
                        }
                    }
                    .fixedSize()
                }

                scheduleMetadata
                    .padding(.top, 6)

                if let tag = event.tag {
                    Text(tag.localizedName(locale: locale).uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tintColor)
                        .lineLimit(1)
                        .padding(.top, 6)
                }

                if let artistNote {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)

                        Text(artistNote)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(artistNote))
                }

                if let artistSummary {
                    Text(artistSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 10)
                }

                if !state.friendProfilesWhoSavedEvent.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .accessibilityHidden(true)

                        Text("event.saved-by-friends")
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        FriendSavedEventBadges(
                            eventID: event.id,
                            profiles: state.friendProfilesWhoSavedEvent,
                            style: .plainInline
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)
        }
        .frame(width: previewWidth)
        .background(Color(.systemBackground))
    }

    private var tintColor: Color {
        Color.okhsl(
            h: event.artist.artistType.okhslHue,
            s: colorScheme == .dark ? 0.68 : 0.74,
            l: colorScheme == .dark ? 0.68 : 0.62
        )
    }

    private var scheduleMetadata: some View {
        HStack(spacing: 5) {
            eventTime

            Text("·")
                .foregroundStyle(.tertiary)

            eventStage
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eventTime: some View {
        Text(
            "\(event.shortWeekDay(calendar: .current, locale: locale)) "
                + event.timeAsString
        )
        .fontWeight(.medium)
        .foregroundStyle(.primary)
        .monospacedDigit()
        .fixedSize(horizontal: true, vertical: false)
    }

    private var eventStage: some View {
        Text(event.stage.localizedName(locale: locale))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    @ViewBuilder
    private var ratingSymbol: some View {
        if state.artistRating < 0 {
            Image(systemName: state.artistIconName ?? "hand.thumbsdown.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        } else {
            CompactRatingGlyph(
                rating: state.artistRating,
                iconName: state.artistIconName ?? state.likeIconName,
                color: .red,
                size: 13,
                spread: 4
            )
        }
    }
}

struct EventContextPreview_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        EventContextPreview(
            event: .example,
            state: EventContextPreviewState(
                isSaved: true,
                artistRating: 2,
                artistIconName: nil,
                friendProfilesWhoSavedEvent: [],
                artistNote: "Meet at the left side of the stage.",
                isArtistSummaryEnabled: true
            )
        )
            .previewMockEnvironment(suiteName: "EventContextPreviewShowcase")
            .previewLayout(.sizeThatFits)
    }
}
