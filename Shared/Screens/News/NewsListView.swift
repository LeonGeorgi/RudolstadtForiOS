//
//  NewsListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct NewsListView: View {
    
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        NavigationView {
            LoadingListView(noDataMessage: "news.empty", dataMapper: { entities in
                entities.news.filter { item in item.isInCurrentLanguage }
            }) { news in
                List(news) { (newsItem: NewsItem) in
                    NewsItemCell(newsItem: newsItem)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(action: {
                                if !settings.readNews.contains(newsItem.id) {
                                    settings.readNews.append(newsItem.id)
                                } else {
                                    settings.readNews.remove(at: settings.readNews.firstIndex(of: newsItem.id)!)
                                }
                            }) {
                                if settings.readNews.contains(newsItem.id) {
                                    Text("Mark unread")
                                    Image(systemName: "envelope.badge")
                                } else {
                                    Text("Mark read")
                                    Image(systemName: "envelope.open")
                                }
                            }.tint(.blue)
                        }
                }.listStyle(.plain)
            }
            .navigationBarTitle("news.long")
        }
    }
}

struct NewsListView_Previews: PreviewProvider {
    static var previews: some View {
        NewsListView()
            .environmentObject(UserSettings())
    }
}
