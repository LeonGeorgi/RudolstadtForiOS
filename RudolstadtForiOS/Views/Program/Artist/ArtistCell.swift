//
//  ArtistConcertItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistCell: View {
    let artist: Artist
    @EnvironmentObject var settings: UserSettings
    
    func artistRating() -> Int {
        return settings.ratings["\(self.artist.id)"] ?? 0
    }
    
    func ratingSymbol(rating: Int) -> String {
        switch rating {
        case 0: return "🤔"
        case 1: return "🙂"
        case 2: return "😊"
        case 3: return "😍"
        default: return "Invalid"
        }
    }
    
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ArtistImageView(artist: artist, fullImage: false)
                    .frame(width: 80, height: 45)
                    .cornerRadius(4)
            }
            HStack(alignment: .center, spacing: 4) {
                Text(artist.name)
                    .lineLimit(2)
                if artistRating() != 0 {
                    Text(ratingSymbol(rating: artistRating()))
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
