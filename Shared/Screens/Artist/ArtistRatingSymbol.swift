import SwiftUI

struct ArtistRatingSymbol: View {
    let artist: Artist
    @EnvironmentObject var settings: UserSettings

    func artistRating() -> Int {
        settings.ratings["\(artist.id)"] ?? 0
    }

    var body: some View {
        RatingSymbol(rating: artistRating())
    }
}
