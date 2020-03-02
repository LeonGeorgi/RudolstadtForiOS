//
//  ArtistConcertItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistEventItem: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if event.tag != nil {
                Text(event.tag!.germanName.uppercased())
                        .font(.caption)
                        //.padding(.vertical, 2)
                        //.padding(.horizontal, 6)
                        .foregroundColor(.accentColor)
                        //.background(Color.accentColor)
                        //.foregroundColor(.white)
                        //.cornerRadius(100)
                        .lineLimit(1)
            }
            HStack(alignment: .bottom) {
                Text("\(event.shortWeekDay) \(event.timeAsString)")
                        .padding(.trailing, 10)
                        .lineLimit(1)
                //.frame(width: 80, alignment: .leading)
                Text(event.stage.germanName).lineLimit(1)
            }
            if Bool.random() {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    Text("gleichzeitig mit \"The Cat Empire\"")
                            .font(.caption)
                            .foregroundColor(.orange)
                }
            }

        }
    }
}

struct ArtistConcertItem_Previews: PreviewProvider {
    static var previews: some View {
        ArtistEventItem(event: .example)
    }
}
