import SwiftUI

struct ArtistCell: View {
    let artist: Artist
    @EnvironmentObject var settings: UserSettings

    func artistRating() -> Int {
        return settings.ratings["\(self.artist.id)"] ?? 0
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ArtistImageView(artist: artist, fullImage: false)
                    .frame(width: 60, height: 52.5)
                
            }
            HStack(alignment: .center, spacing: 4) {
                Text(artist.formattedName)
                    .lineLimit(2)
                if artistRating() != 0 {
                    Spacer()
                    ArtistRatingSymbol(artist: artist)
                        .foregroundColor(.secondary)
                }

            }
        }
    }
}

struct ArtistListItem_Previews: PreviewProvider {
    static var previews: some View {
        ArtistCell(artist: .example)
            .environmentObject(DataStore())
            .environmentObject(UserSettings())
    }
}
