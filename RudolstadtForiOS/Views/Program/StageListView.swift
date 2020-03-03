//
//  NewsListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct StageListView: View {

    @EnvironmentObject var dataStore: DataStore

    var stages: [AreaStages] {
        Dictionary(grouping: dataStore.stages) { (stage: Stage) in
            stage.area
        }.map { area, stages in
            AreaStages(area: area, stages: stages)
        }.sorted { stages, stages2 in
            stages.area.id < stages2.area.id
        }
    }

    var body: some View {
        List {
            ForEach(stages) { (areaStages: AreaStages) in
                Section(header: Text(areaStages.area.germanName)) {
                    ForEach(areaStages.stages) { (stage: Stage) in
                        NavigationLink(destination: StageDetailView(stage: stage)) {
                            HStack {
                                Text(stage.germanName)
                                if stage.stageNumber != nil {
                                    Spacer()
                                    Text(String(stage.stageNumber!))
                                            .frame(width: 30, height: 30)
                                            .background(Color.accentColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(.infinity)
                                }
                            }
                        }
                    }
                }
            }.navigationBarTitle("News")
        }
    }
}

struct AreaStages: Identifiable {
    var id: Int {
        area.id
    }
    let area: Area
    let stages: [Stage]
}

struct StageListView_Previews: PreviewProvider {
    static var previews: some View {
        StageListView()
    }
}
