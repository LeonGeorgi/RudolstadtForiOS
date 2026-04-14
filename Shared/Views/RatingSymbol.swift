//
//  ArtistConcertItem.swift
//  RudolstadtForiOS
//
//  Created by Leon on 25.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct RatingSymbol: View {
    let rating: Int
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        HStack(spacing: 0) {
            if rating <= 0 {
                Text("No Rating")
                    .foregroundColor(.secondary)

            } else {
                ForEach(0..<rating, id: \.self) { _ in
                    Image(systemName: settings.likeIcon)
                        .foregroundColor(.red)
                }
            }
        }
    }
}
