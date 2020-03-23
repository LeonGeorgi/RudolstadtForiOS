//
//  NewsListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct NewsListView: View {
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        NavigationView {
            List(dataStore.news) { (newsItem: NewsItem) in
                NewsItemItemView(newsItem: newsItem)
            }.navigationBarTitle("news.long")
        }
    }
}

struct NewsListView_Previews: PreviewProvider {
    static var previews: some View {
        NewsListView()
    }
}
