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
    @EnvironmentObject var settings: UserSettings

    @State(initialValue: "") var searchTerm: String

    func stages(_ entities: Entities) -> [AreaStages] {
        let normalizedSearchTerm = normalize(string: searchTerm)
        return Dictionary(grouping: entities.stages) { (stage: Stage) in
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
                    stages.minStageNumber(stageNumberType: settings.stageNumberType) < stages2.minStageNumber(stageNumberType: settings.stageNumberType)
                }
    }

    var body: some View {
        LoadingListView(noDataMessage: "locations.empty", dataMapper: { entities in
            stages(entities)
        }) { stages in
            List {
                ForEach(stages) { (areaStages: AreaStages) in
                    Section(header: Text(areaStages.area.localizedName)) {
                        ForEach(areaStages.sortedStages(stageNumberType: settings.stageNumberType)) { (stage: Stage) in
                            NavigationLink(destination: StageDetailView(stage: stage)) {
                                StageCell(stage: stage)
                            }
                        }
                    }
                }
            }
                    .searchable(text: $searchTerm)
                    .listStyle(.grouped)
        }
                .navigationBarTitle("locations.title")
    }
}

struct AreaStages: Identifiable {
    var id: Int {
        area.id
    }
    let area: Area
    let stages: [Stage]

    func sortedStages(stageNumberType: StageNumberType.RawValue) -> [Stage] {
        stages.sorted { stage, stage2 in
            Util.compareStageNumbers(stage, stage2, stageNumberType: stageNumberType)
        }
    }

    func minStageNumber(stageNumberType: StageNumberType.RawValue) -> Int {
        stages.min { stage1, stage2 in
                    Util.compareStageNumbers(stage1, stage2, stageNumberType: stageNumberType)
                }?
                .getAdjustedStageNumber(stageNumberType: stageNumberType) ?? Int.max
    }
}

struct LocationListView_Previews: PreviewProvider {
    static var previews: some View {
        LocationListView()
    }
}
