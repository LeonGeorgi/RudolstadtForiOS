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
    
    var ratingSymbol: String {
        switch rating {
        case 0: return "🤔"
        case 1: return "🙂"
        case 2: return "😊"
        case 3: return "😍"
        default: return "Invalid"
        }
    }
    
    
    var body: some View {
        Text(ratingSymbol)
    }
}
