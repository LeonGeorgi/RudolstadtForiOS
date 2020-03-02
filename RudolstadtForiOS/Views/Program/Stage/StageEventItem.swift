//
//  ProgramEventItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct StageEventItem: View {
    let event: Event

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    ArtistImageView(artist: event.artist, fullImage: false)
                            .frame(width: 80, height: 45)
                            .cornerRadius(4)
                    VStack(alignment: .leading) {
                        HStack {
                            Text(event.timeAsString)
                            Spacer()
                            if event.tag != nil {
                                Text(event.tag!.germanName)
                                        .font(.system(.caption, design: .rounded))
                                        .padding(.vertical, 2)
                                        .padding(.horizontal, 6)
                                        .background(Color.accentColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(100)
                                        .lineLimit(1)
                            }
                        }
                        Text(event.artist.name).lineLimit(1)
                                .font(.subheadline)
                    }

                }

            }
        }

    }
}

struct StageEventItem_Previews: PreviewProvider {
    static var previews: some View {
        StageEventItem(event: .example)
    }
}
