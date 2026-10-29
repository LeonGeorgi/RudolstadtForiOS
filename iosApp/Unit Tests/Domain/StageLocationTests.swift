import Foundation
import Testing

@testable import Rudolstadt

struct StageLocationTests {
    @Test
    func stageCodesPreserveNumbersAndSortLettersWithoutUsingTheirIDs() {
        let letterB = Stage.example.replacing(stageCode: "B")
        var letterA = Stage.example.replacing(stageCode: "A")
        #expect(Stage.example.displayCode == "6")
        #expect(Stage.missing(id: 42).displayCode == nil)
        #expect(letterA.displayCode == "A")
        #expect(Stage.precedes(letterA, letterB))
        #expect(!Stage.precedes(letterB, letterA))
        #expect(Stage.precedes(letterA, .missing(id: 42)))
        letterA = letterA.replacing(stageCode: "Q7")
        #expect(letterA.matches(searchTerm: "q7", locale: Locale(identifier: "en")))
        #expect(
            Stage.precedes(
                TestFixtures.stage(id: 10, stageNumber: 2),
                TestFixtures.stage(id: 2, stageNumber: 10)))
    }

    @Test(arguments: [
        (0.0, 0.0, false), (50.72, 11.34, true), (0, 11, true),
        (50, 0, true), (91, 11, false), (50, 181, false), (.nan, 11, false),
    ])
    func missingAndInvalidCoordinatesCannotExpandTheMap(
        latitude: Double, longitude: Double, valid: Bool
    ) {
        let stage = Stage(
            id: 1, germanName: "Bühne", englishName: "Stage",
            germanDescription: nil, englishDescription: nil, stageNumber: 1,
            latitude: latitude, longitude: longitude,
            area: Area(id: 3, germanName: "Bereich", englishName: "Area"), stageType: .other
        )
        #expect(stage.hasLocation == valid)
    }
}

struct LocationListContentsTests {
    @Test
    func searchReordersAreasByTheirFirstMatchingPlace() {
        let contents = LocationListContents(
            entries: [
                entry(1, sections: ["b"], terms: ["other"]),
                entry(2, sections: ["a"], terms: ["hit"]),
                entry(3, sections: ["b"], terms: ["hit"]),
                entry(4, sections: [], terms: ["hit"]),
            ],
            sections: [("a", "Area A"), ("b", "Area B")], sortsSectionsByFirstPlace: true)
        #expect(contents.filtered(by: "").sections.map(\.id) == ["b", "a"])
        let filtered = contents.filtered(by: "hit")
        #expect(filtered.sections.map(\.id) == ["a", "b"])
        #expect(filtered.sections.flatMap(\.entries).map(\.id) == [.numeric(2), .numeric(3)])
        #expect(filtered.ungrouped.map(\.id) == [.numeric(4)])
    }

    @Test
    func categoriesKeepProviderOrderAndPlacesMayBelongToMultipleSections() {
        let contents = LocationListContents(
            entries: [entry(1, sections: ["b"]), entry(2, sections: ["a", "b"])],
            sections: [("a", "A"), ("b", "B")], sortsSectionsByFirstPlace: false)
        let result = contents.filtered(by: "")
        #expect(result.sections.map(\.id) == ["a", "b"])
        #expect(result.sections[0].entries.map(\.id) == [.numeric(2)])
        #expect(result.sections[1].entries.map(\.id) == [.numeric(1), .numeric(2)])
        #expect(result.ungrouped.isEmpty)
    }

    @Test
    func ungroupedPlacesSearchLocalizedPreparedTerms() {
        let contents = LocationListContents(
            entries: [entry(1, sections: [], terms: ["Bühne", "Heinepark"])],
            sections: [], sortsSectionsByFirstPlace: false)
        #expect(contents.filtered(by: "buhne").ungrouped.count == 1)
        #expect(contents.filtered(by: "heinepark").ungrouped.count == 1)
        #expect(contents.filtered(by: "missing").ungrouped.isEmpty)
    }

    private func entry(_ id: Int, sections: Set<String>, terms: [String] = []) -> LocationListEntry
    {
        LocationListEntry(
            stage: TestFixtures.stage(id: id), title: "Place", note: nil,
            searchTerms: terms, sectionIDs: sections)
    }
}
