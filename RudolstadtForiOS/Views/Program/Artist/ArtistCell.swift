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

    func artistRating() -> [Int] {
        var rating: [Int] = []
        for i in 0..<(settings.ratings["\(self.artist.id)"] ?? 0) {
            rating.append(i)
        }
        return rating

    }


    var body: some View {
        HStack(spacing: 8) {
            ArtistImageView(artist: artist, fullImage: false)
                    .frame(width: 80, height: 45)
                    .cornerRadius(4)
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                        .lineLimit(1)
                if !artistRating().isEmpty {
                    HStack(spacing: 2) {
                        ForEach(artistRating()) { index in
                            Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
    }
}

struct ArtistListItem_Previews: PreviewProvider {
    static var previews: some View {
        ArtistCell(artist: .example)
    }
}
