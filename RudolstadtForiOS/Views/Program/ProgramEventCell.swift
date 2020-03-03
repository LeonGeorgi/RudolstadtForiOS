//
//  ProgramEventItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ProgramEventCell: View {
    let event: Event

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text("\(event.weekDay) \(event.timeAsString)".uppercased())
                            .font(.caption)
                            .fontWeight(.bold)

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
                HStack(alignment: .top) {
                    ArtistImageView(artist: event.artist, fullImage: false)
                            .frame(width: 80, height: 45)
                            .cornerRadius(4)
                    Text(event.artist.name).lineLimit(2)
                }

            }
        }

    }
}

struct ProgramEventItem_Previews: PreviewProvider {
    static var previews: some View {
        ProgramEventCell(event: .example)
    }
}
