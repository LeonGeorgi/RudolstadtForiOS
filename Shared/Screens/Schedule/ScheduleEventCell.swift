import SwiftUI

struct ScheduleEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    @State private var showingAlert = false

    func artistRating() -> Int {
        settings.ratings["\(event.artist.id)"] ?? 0
    }

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
                                        .foregroundColor(.accentColor)
                                        .lineLimit(1)
                            }
                            Text(event.artist.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            
                            Text("\(event.timeAsString) (\(event.stage.localizedName))")
                                    .lineLimit(1)
                                    .font(.subheadline)

                        }
                        Spacer()
                        if artistRating() != 0 {
                            ArtistRatingSymbol(artist: event.artist)
                        }
                        EventSavedIcon(event: event)
                    }.opacity(settings.savedEvents.contains(event.id) ? 1 : 0.5)
                }

            }
        }.contextMenu {
            SaveEventButton(event: event)
        }.id(settings.idFor(event: event))
    }
}

struct ScheduleEventCell_Previews: PreviewProvider {
    static var previews: some View {
        TimeProgramEventCell(event: .example)
    }
}
