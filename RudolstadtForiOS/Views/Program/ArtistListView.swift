//
//  ArtistListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI
import URLImage

struct ArtistListView: View {
    let data: FestivalData
    @State private var showingSheet = false

    var body: some View {
        List(data.artists) { (artist: Artist) in
            NavigationLink(destination: ArtistDetailView(artist: artist, data: self.data)) {
                HStack {
                    ArtistImageView(artist: artist, fullImage: false)
                            .frame(width: 80, height: 45)
                            .cornerRadius(4)
                    Text(artist.name)
                            .lineLimit(1)
                }
            }

        }.navigationBarTitle("Artists")
                .navigationBarItems(trailing: Button(action: {

                }) {
                    Text("Filter")
                })
    }
}

struct ArtistListView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistListView(data: .example)
    }
}
