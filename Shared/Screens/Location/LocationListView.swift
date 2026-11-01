import SwiftUI

struct LocationListView: View {
    @Environment(\.festivalData) private var data
    @State private var searchTerm = ""

    @Environment(\.locale) private var locale

    private var places: [Stage] {
        (data.stages).filter { place in
            let details = data.features.placeDetails.value?.details(for: place.id)?.description?.text.resolved(locale: locale)
            let areaNames = data.features.areas.value.map { areas in
                areas.areas.filter { areas.areaIDs(for: place.id).contains($0.id) }
                    .map { $0.name.resolved(locale: locale) }
            } ?? []
            return searchTerm.isEmpty || ([place.name.resolved(locale: locale), place.reference, details].compactMap { $0 } + areaNames)
                .contains { $0.localizedStandardContains(searchTerm) }
        }.sorted { first, second in
            guard let left = first.reference else { return false }
            guard let right = second.reference else { return true }
            return left.compare(right, options: .numeric) == .orderedAscending
        }
    }

    private var sortedAreas: [Area] {
        guard let areas = data.features.areas.value else { return [] }
        return areas.areas.sorted { first, second in
            let firstIndex = places.firstIndex { areas.areaIDs(for: $0.id).contains(first.id) } ?? .max
            let secondIndex = places.firstIndex { areas.areaIDs(for: $0.id).contains(second.id) } ?? .max
            return firstIndex < secondIndex
        }
    }

    var body: some View {
        List {
            if let plan = data.features.sitePlan.value {
                Section {
                    NavigationLink { FestivalOriginalPlanView(document: plan.document) } label: {
                        Label(plan.document.title.resolved(), systemImage: "map")
                    }
                }
            }
            if let areas = data.features.areas.value, !areas.areas.isEmpty {
                ForEach(sortedAreas) { area in
                    let members = places.filter { areas.areaIDs(for: $0.id).contains(area.id) }
                    if !members.isEmpty {
                        Section(area.name.resolved()) { rows(members) }
                    }
                }
                rows(places.filter { areas.areaIDs(for: $0.id).isEmpty })
            } else if let map = data.features.map.value, !map.categories.isEmpty {
                ForEach(map.categories) { category in
                    let members = places.filter { map.category(for: $0.id)?.id == category.id }
                    if !members.isEmpty { Section(category.title.resolved()) { rows(members) } }
                }
                rows(places.filter { map.category(for: $0.id) == nil })
            } else {
                rows(places)
            }
        }
        .searchable(text: $searchTerm).disableAutocorrection(true).navigationTitle("locations.title")
    }

    @ViewBuilder
    private func rows(_ places: [Stage]) -> some View {
        ForEach(places) { place in
            NavigationLink(value: AppNavigationRoute.stage(id: place.id, highlightedEventId: nil)) {
                row(place)
            }
        }
    }
    private func row(_ place: Stage) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name.resolved(locale: locale))
                if !data.events.contains(where: { $0.stage.id == place.id }),
                   let note = data.features.placeDetails.value?.details(for: place.id)?.description?.text.resolved(locale: locale),
                   !note.isEmpty {
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } icon: {
            if let stage = data.stages.first(where: { $0.id == place.id }) {
                StageNumber(stage: stage, size: 34)
            } else {
                Image(systemName: data.features.map.value?.category(for: place.id)?.systemImageName ?? "mappin")
            }
        }.accessibilityIdentifier("location-\(place.id)")
    }
}
