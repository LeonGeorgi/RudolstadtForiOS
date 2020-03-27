//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

struct NewsItemItemView: View {
    let newsItem: NewsItem

    var body: some View {
        NavigationLink(destination: NewsItemDetailView(newsItem: newsItem)) {
            VStack(alignment: .leading) {
                Text(newsItem.shortDescription)
                Text("\(newsItem.dateAsString) \(newsItem.timeAsString)")
                        .font(.caption)
            }
        }
    }
}

struct NewsItemItemView_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemItemView(newsItem: .example)
    }
}
