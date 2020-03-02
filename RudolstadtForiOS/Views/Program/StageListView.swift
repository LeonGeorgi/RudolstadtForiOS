//
//  NewsListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct StageListView: View {

    let data: FestivalData

    var body: some View {
        NavigationView {
            List(data.stages) { (stage: Stage) in
                NavigationLink(destination: StageDetailView(stage: stage, data: self.data)) {
                    VStack {
                        Text(stage.germanName)
                        Text(stage.area.germanName)
                                .font(.caption)
                    }
                }
            }.navigationBarTitle("News")
        }
    }
}

struct StageListView_Previews: PreviewProvider {
    static var previews: some View {
        StageListView(data: .empty)
    }
}
