import SwiftUI

struct StageEventCell: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    ArtistImageView(artist: event.artist, fullImage: false)
                            .frame(width: 45, height: 45)
                            .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(event.timeAsString)
                            Spacer()
                            if event.tag != nil {
                                Text(event.tag!.localizedName)
                                        .font(.system(.caption2, design: .rounded))
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 6)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(100)
                                        .lineLimit(1)
                            }
                        }
                        Text(event.artist.name).lineLimit(1)
                                .font(.subheadline)
                    }

                }

            }
            Spacer()
            EventSavedIcon(event: self.event)
        }.contextMenu {
            SaveEventButton(event: event)
        }.id(settings.idFor(event: event))

    }
}

struct StageEventCell_Previews: PreviewProvider {
    static var previews: some View {
        StageEventCell(event: .example)
            .environmentObject(UserSettings())
    }
}
