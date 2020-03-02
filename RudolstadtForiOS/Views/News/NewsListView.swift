//
//  NewsListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct NewsListView: View {

    let data: FestivalData

    var body: some View {
        NavigationView {
            List(data.news) { (newsItem: NewsItem) in
                NewsItemItemView(newsItem: newsItem)
            }.navigationBarTitle("News")
        }
    }
}

struct NewsListView_Previews: PreviewProvider {
    static var previews: some View {
        NewsListView(data: .empty)
    }
}
