import Foundation
import Testing
@testable import Rudolstadt

struct StageLocationTests {
    @Test
    func stageCodesPreserveNumbersAndSortLettersWithoutUsingTheirIDs() {
        var letterB = Stage.example
        letterB.stageCode = "B"
        var letterA = Stage.example
        letterA.stageCode = "A"
        #expect(Stage.example.displayCode == "6")
        #expect(Stage.missing(id: 42).displayCode == nil)
        #expect(letterA.displayCode == "A")
        #expect(Stage.precedes(letterA, letterB))
        #expect(!Stage.precedes(letterB, letterA))
        #expect(Stage.precedes(letterA, .missing(id: 42)))
        letterA.stageCode = "Q7"
        #expect(letterA.matches(searchTerm: "q7", locale: Locale(identifier: "en")))
        #expect(Stage.precedes(TestFixtures.stage(id: 10, stageNumber: 2),
                               TestFixtures.stage(id: 2, stageNumber: 10)))
    }

    @Test(arguments: [(0.0, 0.0, false), (50.72, 11.34, true), (0, 11, true),
                      (50, 0, true), (91, 11, false), (50, 181, false), (.nan, 11, false)])
    func missingAndInvalidCoordinatesCannotExpandTheMap(latitude: Double, longitude: Double, valid: Bool) {
        let stage = Stage(
            id: 1, germanName: "Bühne", englishName: "Stage",
            germanDescription: nil, englishDescription: nil, stageNumber: 1,
            latitude: latitude, longitude: longitude,
            area: Area(id: 3, germanName: "Bereich", englishName: "Area"), stageType: .other
        )
        #expect(stage.hasLocation == valid)
    }
}
