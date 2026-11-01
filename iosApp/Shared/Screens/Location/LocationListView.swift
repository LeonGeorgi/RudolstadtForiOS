import SwiftUI

struct LocationListEntry: Identifiable {
    let stage: Stage
    let title: String
    let note: String?
    let searchTerms: [String]
    let sectionIDs: Set<String>
    var id: FestivalPlaceID { stage.id }
}

struct LocationListSection: Identifiable {
    let id: String
    let title: String
    let entries: [LocationListEntry]
}

/// Search changes reuse localized rows and memberships; providers are read only during preparation.
struct LocationListContents {
    let entries: [LocationListEntry]
    let sections: [(id: String, title: String)]
    let sortsSectionsByFirstPlace: Bool

    func filtered(by query: String) -> (
        sections: [LocationListSection], ungrouped: [LocationListEntry]
    ) {
        var grouped: [String: [LocationListEntry]] = [:]
        var firstIndex: [String: Int] = [:]
        var ungrouped: [LocationListEntry] = []
        for (index, entry) in entries.enumerated() {
            guard
                query.isEmpty
                    || entry.searchTerms.contains(where: { $0.localizedStandardContains(query) })
            else { continue }
            if entry.sectionIDs.isEmpty { ungrouped.append(entry) }
            for id in entry.sectionIDs {
                grouped[id, default: []].append(entry)
                if firstIndex[id] == nil { firstIndex[id] = index }
            }
        }
        let order =
            sortsSectionsByFirstPlace
            ? sections.sorted { (firstIndex[$0.id] ?? .max) < (firstIndex[$1.id] ?? .max) }
            : sections
        return (
            order.compactMap { section in
                grouped[section.id].map {
                    LocationListSection(id: section.id, title: section.title, entries: $0)
                }
            }, ungrouped
        )
    }
}

struct LocationListView: View {
    @Environment(\.festivalData) private var data
    @Environment(\.locale) private var locale

    var body: some View {
        let areas = data.features.areas.value
        let map = data.features.map.value
        let availableAreas = areas?.areas ?? []
        let usesAreas = !availableAreas.isEmpty
        let usesCategories = !usesAreas && map?.categories.isEmpty == false
        let performancePlaces = Set(data.events.map { $0.stage.id })
        let sections =
            usesAreas
            ? availableAreas.map { (id: String($0.id), title: $0.name.resolved(locale: locale)) }
            : (map?.categories ?? []).map { (id: $0.id, title: $0.title.resolved(locale: locale)) }
        let entries = data.stages.map { place in
            let title = place.name.resolved(locale: locale)
            let details = data.features.placeDetails.value?.details(for: place.id)?.content?.text
                .resolved(locale: locale)
            let ids: Set<String>
            if usesAreas {
                ids = Set((areas?.areaIDs(for: place.id) ?? []).map(String.init))
            } else if usesCategories, let category = map?.category(for: place.id) {
                ids = [category.id]
            } else {
                ids = []
            }
            return LocationListEntry(
                stage: place, title: title,
                note: !performancePlaces.contains(place.id) && details?.isEmpty == false
                    ? details : nil,
                searchTerms: [title, place.reference, details].compactMap { $0 }
                    + (usesAreas ? sections.filter { ids.contains($0.id) }.map(\.title) : []),
                sectionIDs: ids)
        }.sorted { first, second in
            guard let left = first.stage.reference else { return false }
            guard let right = second.stage.reference else { return true }
            return left.compare(right, options: .numeric) == .orderedAscending
        }
        LocationSearchList(
            contents: LocationListContents(
                entries: entries, sections: sections, sortsSectionsByFirstPlace: usesAreas),
            plan: data.features.sitePlan.value?.document)
    }
}

private struct LocationSearchList: View {
    let contents: LocationListContents
    let plan: SitePlanDocument?
    @State private var searchTerm = ""

    var body: some View {
        let result = contents.filtered(by: searchTerm)
        List {
            if let plan {
                Section {
                    NavigationLink {
                        FestivalOriginalPlanView(document: plan)
                    } label: {
                        Label(plan.title.resolved(), systemImage: "map")
                    }
                }
            }
            ForEach(result.sections) { section in
                Section(section.title) { rows(section.entries) }
            }
            rows(result.ungrouped)
        }
        .searchable(text: $searchTerm).disableAutocorrection(true).navigationTitle(
            "locations.title")
    }

    private func rows(_ entries: [LocationListEntry]) -> some View {
        ForEach(entries) { entry in
            NavigationLink(value: entry.id) {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.title)
                        if let note = entry.note {
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    StageNumber(stage: entry.stage, size: 34)
                }
                .accessibilityIdentifier("location-\(entry.id)")
            }
        }
    }
}
