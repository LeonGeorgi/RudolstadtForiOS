import SwiftUI

struct SavedArtistEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    func artistRating() -> Int {
        settings.ratings["\(event.artist.id)"] ?? 0
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    ZStack {
                        ArtistImageView(artist: event.artist, fullImage: false)
                                .overlay(Color.black.opacity(0.5))
                                .frame(width: 80, height: 45)
                                .cornerRadius(4)

                        Text(event.timeAsString)
                                .fontWeight(.bold)
                                .clipped()
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                    }
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
                        Text(event.stage.localizedName)
                                .lineLimit(1)
                                .font(.footnote)

                    }
                    Spacer()
                    if artistRating() != 0 {
                        ArtistRatingSymbol(artist: self.event.artist)
                    }
                    EventSavedIcon(event: self.event)
                }

            }
        }.contextMenu {
            SaveEventButton(event: event)
        }.id(settings.idFor(event: event))

    }
}

struct SavedArtistEventCell_Previews: PreviewProvider {
    static var previews: some View {
        TimeProgramEventCell(event: .example)
    }
}
