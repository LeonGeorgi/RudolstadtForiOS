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

    func stages(_ entities: Entities) -> [AreaStages] {
        let normalizedSearchTerm = normalize(string: searchTerm)
        return Dictionary(grouping: entities.stages) { (stage: Stage) in
            stage.area
        }
        .map { area, stages in
            AreaStages(
                area: area,
                stages: stages.filter { stage in
                    stage.matches(searchTerm: normalizedSearchTerm)
                }
            )
        }
        .filter { areaStages in
            !areaStages.stages.isEmpty
        }
        .sorted { s1, s2 in
            guard let s1Number = s1.stages[0].stageNumber else {
                return false
            }

            guard let s2Number = s2.stages[0].stageNumber else {
                return true
            }
            return s1Number < s2Number
        }
        /*.sorted { stages, stages2 in
            stages.area.id < stages2.area.id
        }*/
    }

    var body: some View {
        LoadingListView(
            noDataMessage: "locations.empty",
            dataMapper: { entities in
                stages(entities)
            }
        ) { stages in
            List {
                ForEach(stages) { (areaStages: AreaStages) in
                    Section(header: Text(areaStages.area.localizedName)) {
                        ForEach(areaStages.stages) { (stage: Stage) in
                            NavigationLink(
                                destination: StageDetailView(
                                    stage: stage,
                                    highlightedEventId: nil
                                )
                            ) {
                                StageCell(stage: stage)
                            }
                        }
                    }
                }
            }
            .listStyle(.grouped)
        }
        .searchable(text: $searchTerm)
        .disableAutocorrection(true)
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
