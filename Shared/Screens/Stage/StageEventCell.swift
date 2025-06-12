import SwiftUI

struct StageEventCell: View {
    let event: Event
    let imageWidth: CGFloat
    let imageHeight: CGFloat

    @EnvironmentObject var settings: UserSettings

    func artistRating() -> Int {
        settings.ratings["\(event.artist.id)"] ?? 0
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    ArtistImageView(artist: event.artist, fullImage: false)
                        .frame(width: imageWidth, height: imageHeight)
                    VStack(alignment: .leading, spacing: 0) {
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
            if artistRating() != 0 {
                ArtistRatingSymbol(artist: self.event.artist)
            }
            EventSavedIcon(event: self.event)
        }.contextMenu {
            SaveEventButton(event: event)
        }.id(settings.idFor(event: event))

    }
}

struct StageEventCell_Previews: PreviewProvider {
    static var previews: some View {
        StageEventCell(event: .example, imageWidth: 64, imageHeight: 56)
            .environmentObject(UserSettings())
    }
}
