//
// Created by Leon on 27.02.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

struct NewsItemDetailView: View {
    let newsItem: NewsItem
    
    @EnvironmentObject var settings: UserSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("\(newsItem.dateAsString) \(newsItem.timeAsString)")
                        .font(.subheadline)
                        .padding(.bottom, 5)

                Text(newsItem.formattedLongDescription)
                        .font(.headline)
                        .padding(.bottom, 15)

                Text(newsItem.formattedContent)
            }.padding()
        }.navigationBarTitle(Text(newsItem.shortDescription), displayMode: .inline)
            .onAppear {
                if !settings.readNews.contains(newsItem.id) {
                    settings.readNews.append(newsItem.id)
                }
            }
    }
}

struct NewsItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NewsItemDetailView(newsItem: .example)
    }
}
