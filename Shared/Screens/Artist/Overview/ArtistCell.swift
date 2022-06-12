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
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
            }
            HStack(alignment: .center, spacing: 4) {
                Text(artist.name)
                        .lineLimit(2)
                if artistRating() != 0 {
                    Spacer()
                    ArtistRatingSymbol(artist: artist)
                }

            }
        }.contextMenu {
                    ForEach((0..<4).reversed()) { rating in
                        Button(action: {
                            self.settings.ratings[String(self.artist.id)] = rating
                        }) {
                            RatingSymbol(rating: rating)
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
