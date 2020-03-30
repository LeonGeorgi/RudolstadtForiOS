//
//  ArtistConcertItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistRatingSymbol: View {
    let artist: Artist
    @EnvironmentObject var settings: UserSettings
    
    func artistRating() -> Int {
        return settings.ratings["\(self.artist.id)"] ?? 0
    }
    
    
    var body: some View {
        RatingSymbol(rating: artistRating())
    }
}