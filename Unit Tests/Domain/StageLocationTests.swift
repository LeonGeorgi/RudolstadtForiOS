import Testing
@testable import Rudolstadt

struct StageLocationTests {
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
