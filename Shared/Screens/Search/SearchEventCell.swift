import SwiftUI

struct SearchEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    ZStack(content: {
                        ArtistImageView(artist: event.artist, fullImage: false)
                                .overlay(Color.black.opacity(0.5))
                                .frame(width: 60, height: 40)
                                .cornerRadius(4)

                        Text(event.shortWeekDay + " " + event.timeAsString)
                                .font(.system(size: 10))
                                .fontWeight(.bold)
                                .clipped()
                                .foregroundColor(.white)
                                .shadow(radius: 5)
                    })
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
                    EventSavedIcon(event: self.event)
                }

            }
        }
                .contextMenu {
                    SaveEventButton(event: event)
                }.id(settings.idFor(event: event))

    }
}

struct SearchEventCell_Previews: PreviewProvider {
    static var previews: some View {
        SearchEventCell(event: .example)
    }
}
