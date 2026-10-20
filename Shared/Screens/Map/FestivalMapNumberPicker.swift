import SwiftUI

struct FestivalMapNumberPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    let stages: [Stage]
    let selectedStageID: Int?
    let select: (Int) -> Void

    private var displayedStages: [Stage] {
        stages.filter { stage in
            searchText.isEmpty
                || stage.stageNumber.map { String($0).localizedStandardContains(searchText) } == true
                || stage.localizedName.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(displayedStages) { stage in
                Button {
                    select(stage.id)
                } label: {
                    HStack {
                        Text(stage.stageNumber.map(String.init) ?? "")
                            .monospacedDigit()
                            .foregroundStyle(StageNumber.baseColor(for: stage.stageType))
                            .frame(minWidth: 32, alignment: .trailing)
                        VStack(alignment: .leading) {
                            Text(stage.localizedName)
                                .foregroundStyle(.primary)
                            if !stage.hasLocation {
                                Text("map.location.unavailable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if stage.id == selectedStageID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityIdentifier("festival-map-number-\(stage.id)")
            }
            .overlay {
                if displayedStages.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView("map.numbers.empty", systemImage: "mappin.slash")
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "search.locations")
            .navigationTitle("map.numbers.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}
