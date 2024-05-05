import SwiftUI

struct ArtistRatingView: View {
    let artist: Artist
    @EnvironmentObject var settings: UserSettings
    
    var body: some View {
        HStack {
            Spacer()
            ForEach(-1..<4) { rating in
                Text(getSymbolForRating(rating))
                    .font(.system(size: 35))
                    .saturation(saturationFor(rating))
                    .onTapGesture {
                        if artistRating() != rating {
                            self.rateArtistIfNeeded(rating)
                        }
                    }
                if rating < 1 {
                    Divider()
                        .padding(.vertical, 5)
                }
                
            }
            Spacer()
        }
    }
    
    private func getSymbolForRating(_ rating: Int) -> String {
        switch rating {
        case -1: return "🥱"
        case 0: return "🤔"
        case 1: return "❤️"
        case 2: return "❤️"
        case 3: return "❤️"
        default: return "Invalid"
        }
    }
    
    private func saturationFor(_ rating: Int) -> Double {
        let currentRating = artistRating()
        return (rating == currentRating || (rating > 0 && rating < currentRating)) ? 1.0 : 0.0
    }
    
    private func rateArtistIfNeeded(_ rating: Int) {
        if artistRating() != rating {
            rateArtist(rating: rating)
        }
    }
    
    private func rateArtist(rating: Int) {
        var ratings = settings.ratings
        ratings["\(artist.id)"] = rating
        settings.ratings = ratings
    }
    
    func artistRating() -> Int {
        settings.ratings["\(artist.id)"] ?? 0
    }
}


#Preview {
    ArtistRatingView(artist: .example)
        .environmentObject(UserSettings())
}
