//
//  ArtistImageView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI
import SDWebImageSwiftUI

struct ArtistImageView: View {
    let artist: Artist
    let fullImage: Bool
    var body: some View {
        VStack {
            if fullImage && artist.fullImageUrl != nil {
                WebImage(url: artist.fullImageUrl!)
                    .placeholder {
                        Image("placeholder")
                            .resizable()                     // Make image resizable
                            .aspectRatio(contentMode: .fill) // Fill the frame
                            .clipped()
                }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else if artist.thumbImageUrl != nil {
                WebImage(url: artist.thumbImageUrl!)
                    .placeholder {
                        Image("placeholder")
                            .resizable()                     // Make image resizable
                            .aspectRatio(contentMode: .fill) // Fill the frame
                            .clipped()
                }
                .resizable()
                .aspectRatio(contentMode: .fill)
            .clipped()
            } else {
                Image("placeholder")
                        .resizable()                     // Make image resizable
                        .aspectRatio(contentMode: .fill) // Fill the frame
                        .clipped()
            }
        }
    }
}

struct ArtistImageView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistImageView(artist: .example, fullImage: false)
    }
}
