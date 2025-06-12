import SwiftUI

struct SaveEventPreview: View {
    let event: Event

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        ZStack(alignment: .center) {
            ArtistImageView(artist: event.artist, fullImage: false)
                .frame(maxHeight: 150)
                .blur(radius: 5)

            VStack(alignment: .center) {
                Text(event.artist.formattedName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("\(event.weekDay) \(event.timeAsString)")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: 200)
    }
}

struct SaveEventPreview_Previews: PreviewProvider {
    static var previews: some View {
        SaveEventPreview(event: .example)
            .environmentObject(UserSettings())
            .frame(width: 400, height: 400)
    }
}
