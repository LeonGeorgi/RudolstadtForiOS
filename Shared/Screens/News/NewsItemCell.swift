//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

struct NewsItemCell: View {
    let newsItem: NewsItem
    
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        NavigationLink(destination: NewsItemDetailView(newsItem: newsItem)) {
            VStack(alignment: .leading) {
                Text(newsItem.shortDescription)
                Text("\(newsItem.dateAsString) \(newsItem.timeAsString)")
                        .font(.caption)
            }
        }.opacity(settings.readNews.contains(newsItem.id) ? 0.5 : 1)
    }
}

struct NewsItemCell_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemCell(newsItem: .example)
            .environmentObject(UserSettings())
    }
}
