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
        NavigationLink(value: AppNavigationRoute.news(id: newsItem.id)) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .foregroundColor(.blue)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                    .opacity(settings.readNews.contains(newsItem.id) ? 0 : 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text(newsItem.formattedShortDescription)
                        .font(.headline)
                        .lineLimit(2)
                    if !newsItem.formattedLongDescription.isEmpty {
                        Text(newsItem.formattedLongDescription)
                            .lineLimit(2)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(newsItem.formattedContent)
                            .lineLimit(2)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(newsItem.dateAsString) \(newsItem.timeAsString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

struct NewsItemCell_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemCell(newsItem: .example)
            .environmentObject(UserSettings())
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}
