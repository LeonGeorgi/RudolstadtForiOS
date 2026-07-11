import SwiftUI

struct LocationListView: View {

    @Environment(\.festivalData) private var festivalData

    @State private var searchTerm = ""

    private var areaStages: [AreaStages] {
        let normalizedSearchTerm = normalize(string: searchTerm)

        return Dictionary(
            grouping: festivalData.stages.filter { stage in
                stage.matches(searchTerm: normalizedSearchTerm)
            },
            by: \.area
        )
        .map(AreaStages.init)
        .sorted { s1, s2 in
            (s1.stages.first?.stageNumber ?? .max) < (s2.stages.first?.stageNumber ?? .max)
        }
    }

    var body: some View {
        List {
            ForEach(areaStages) { group in
                Section(header: Text(group.area.localizedName)) {
                    ForEach(group.stages) { stage in
                        NavigationLink(
                            value: AppNavigationRoute.stage(
                                id: stage.id,
                                highlightedEventId: nil
                            )
                        ) {
                            Label {
                                Text(stage.localizedName)
                            } icon: {
                                StageNumber(stage: stage, size: 34)
                            }
                        }
                        .accessibilityIdentifier("location-\(stage.id)")
                    }
                }
            }
        }
        .searchable(text: $searchTerm)
        .disableAutocorrection(true)
        .navigationTitle("locations.title")
    }
}

private struct AreaStages: Identifiable {
    var id: Int {
        area.id
    }
    let area: Area
    let stages: [Stage]
}

#if DEBUG
struct LocationListView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        NavigationStack {
            LocationListView()
                .navigationDestination(for: AppNavigationRoute.self) { _ in
                    EmptyView()
                }
        }
        .previewMockEnvironment(suiteName: "LocationListViewPreview")
    }
}
#endif
