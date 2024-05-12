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
            HStack(alignment: .firstTextBaseline) {
                Circle()
                    .foregroundColor(.blue)
                    .frame(width: 10, height: 10)
                    .opacity(settings.readNews.contains(newsItem.id) ? 0 : 1)
                VStack(alignment: .leading) {
                    Text(newsItem.formattedShortDescription)
                        .font(.headline)
                        .lineLimit(1)
                    if !newsItem.formattedLongDescription.isEmpty {
                        Text(newsItem.formattedLongDescription)
                            .lineLimit(1)
                        .font(.subheadline)
                    } else {
                        Text(newsItem.formattedContent)
                            .lineLimit(1)
                        .font(.subheadline)
                    }
                    Text("\(newsItem.dateAsString) \(newsItem.timeAsString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct NewsItemCell_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemCell(newsItem: .example)
            .environmentObject(UserSettings())
    }
}
