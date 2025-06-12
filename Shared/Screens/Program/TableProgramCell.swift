import SwiftUI

struct TableProgramCell: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var settings: UserSettings

    func artistRating() -> Int {
        return settings.ratings["\(self.event.artist.id)"] ?? 0
    }
    let width: CGFloat
    let height: CGFloat
    let event: Event

    private var isSaved: Bool {
        return settings.savedEvents.contains(event.id)
    }

    var body: some View {
        if #available(iOS 16, *) {
            renderContent()
                .contextMenu {
                    SaveEventButton(event: event)
                } preview: {
                    SaveEventPreview(event: event)
                }
        } else {
            renderContent()
                .contextMenu {
                    SaveEventButton(event: event)
                }
        }
    }

    func renderContent() -> some View {
        return NavigationLink(
            destination: ArtistDetailView(
                artist: event.artist,
                highlightedEventId: event.id
            )
        ) {
            VStack(spacing: 0) {
                if let tag = event.tag {
                    Text(tag.localizedName)
                        //.frame(maxWidth: width)
                        .font(.system(size: 8, weight: .bold))

                        .foregroundColor(
                            isSaved
                                ? .white
                                : .primary.opacity(
                                    colorScheme == .light ? 1 : 0.9
                                )
                        )
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                        .textCase(.uppercase)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                }
                if artistRating() != 0 {
                    Spacer(minLength: 0)

                }

                Spacer(minLength: 0)
                Text(event.artist.formattedName)
                    //.frame(maxWidth: width)
                    .font(.system(size: 12))
                    .foregroundColor(
                        isSaved
                            ? .white
                            : .primary.opacity(colorScheme == .light ? 1 : 0.9)
                    )
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .padding(.vertical, 2)
                Spacer(minLength: 0)
                if event.tag != nil {
                    Spacer(minLength: 0)
                }

                if artistRating() != 0 {
                    ArtistRatingSymbol(artist: event.artist)
                        .font(.system(size: 12))
                        .padding(.vertical, 2)

                    Spacer(minLength: 0)

                }
            }
            .frame(width: width, height: height)
            .background(getColorForEvent(event).opacity(0.7))
            .foregroundColor(.black)
            .cornerRadius(4)
            /*.overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black, lineWidth: 1)
                    .opacity(0.15)
            )*/
        }
    }

    func getColorForEvent(_ event: Event) -> Color {
        switch event.artist.artistType {
        case .stage:
            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeStageSaved
            } else {
                return Color.artistTypeStage
            }
        case .dance:

            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeDanceSaved
            } else {
                return Color.artistTypeDance
            }
        case .street:
            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeStreetSaved
            } else {
                return Color.artistTypeStreet
            }
        case .other:
            if settings.savedEvents.contains(event.id) {
                return Color.artistTypeOtherSaved
            } else {
                return Color.artistTypeOther
            }
        }
    }
}

struct TableProgramCell_Previews: PreviewProvider {
    static func exampleEvent(artistType: ArtistType, id: Int, tag: Tag?)
        -> Event
    {
        return Event(
            id: id,
            dayInJuly: 5,
            timeAsString: "17:00",
            stage: .example,
            artist: .example,
            tag: tag
        )
    }
    static func userSettings() -> UserSettings {
        let userSettings = UserSettings()
        userSettings.savedEvents = [2, 4, 6, 8]
        return userSettings
    }

    static func generateMainVariants(tag: Tag?) -> some View {

        HStack {
            let width = 60.0
            let height = 60.0
            VStack {
                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .stage, id: 1, tag: tag)
                )
                .environmentObject(userSettings())

                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .stage, id: 2, tag: tag)
                )
                .environmentObject(UserSettings())

            }

            VStack {

                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .dance, id: 3, tag: tag)
                )
                .environmentObject(UserSettings())

                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .dance, id: 4, tag: tag)
                )
                .environmentObject(UserSettings())

            }

            VStack {

                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .street, id: 5, tag: tag)
                )
                .environmentObject(UserSettings())

                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .street, id: 6, tag: tag)
                )
                .environmentObject(UserSettings())
            }

            VStack {

                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .other, id: 7, tag: tag)
                )
                .environmentObject(UserSettings())

                TableProgramCell(
                    width: width,
                    height: height,
                    event: exampleEvent(artistType: .other, id: 8, tag: tag)
                )
                .environmentObject(UserSettings())

            }
        }
    }

    static var previews: some View {
        VStack(spacing: 50) {
            generateMainVariants(tag: nil)
            generateMainVariants(tag: .example)
        }
        .previewLayout(PreviewLayout.sizeThatFits)
    }
}
