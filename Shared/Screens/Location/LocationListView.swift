//
//  NewsListView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct LocationListView: View {

    @EnvironmentObject var dataStore: DataStore

    @State(initialValue: "") var searchTerm: String

    var stages: [AreaStages] {
        let normalizedSearchTerm = normalize(string: searchTerm)
        return Dictionary(grouping: dataStore.stages) { (stage: Stage) in
            stage.area
        }
                .map { area, stages in
                    AreaStages(area: area, stages: stages.filter { stage in
                        stage.matches(searchTerm: normalizedSearchTerm)
                    })
                }
                .filter { areaStages in
                    !areaStages.stages.isEmpty
                }
                .sorted { stages, stages2 in
                    stages.area.id < stages2.area.id
                }
    }

    var body: some View {
        List {
            ForEach(stages) { (areaStages: AreaStages) in
                Section(header: Text(areaStages.area.localizedName)) {
                    ForEach(areaStages.stages) { (stage: Stage) in
                        NavigationLink(destination: StageDetailView(stage: stage)) {
                            HStack {
                                if stage.stageNumber != nil {
                                    Text(String(stage.stageNumber!))
                                            .frame(width: 30, height: 30)
                                            .background(Color.accentColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(.infinity)
                                }
                                Text(stage.localizedName)
                            }
                        }
                    }
                }
            }
        }
                .searchable(text: $searchTerm)
                .navigationBarTitle("locations.title")
    }
}

struct AreaStages: Identifiable {
    var id: Int {
        area.id
    }
    let area: Area
    let stages: [Stage]
}

struct LocationListView_Previews: PreviewProvider {
    static var previews: some View {
        LocationListView()
    }
}
