//
//  NewsListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct NewsListView: View {

    var body: some View {
        NavigationView {
            LoadingListView(noDataMessage: "news.empty", dataMapper: { entities in
                entities.news.filter { item in item.isInCurrentLanguage }
            }) { news in
                List(news) { (newsItem: NewsItem) in
                    NewsItemCell(newsItem: newsItem)
                }.listStyle(.plain)
            }
            .navigationBarTitle("news.long")
        }
    }
}

struct NewsListView_Previews: PreviewProvider {
    static var previews: some View {
        NewsListView()
    }
}
