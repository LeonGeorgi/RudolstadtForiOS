import SwiftUI

struct ArtistRatingSymbol: View {
    let artist: Artist
    @EnvironmentObject var settings: UserSettings
    
    var artistSymbol: String? {
        settings.getArtistIcon(for: artist)
    }

    var artistRating: Int {
        settings.ratings["\(artist.id)"] ?? 0
    }

    var body: some View {
        if artistRating < 0 {
            Image(systemName: artistSymbol ?? "hand.thumbsdown.fill")
        } else if artistRating == 0 {
            // return empty view
            EmptyView()
        } else {
            RatingSymbol(rating: artistRating)
        }
    }
}
