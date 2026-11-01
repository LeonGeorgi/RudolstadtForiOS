import RudolstadtCore
import Foundation
import OSLog

enum StageWalkingDistanceProvider {
    static let bundled = loadBundledMatrix()
    static func decodeMatrix(from data: Data) throws -> StageWalkingDistanceMatrix {
        try WalkingMatrices.shared.decode(sourceJSON: sourceJSONString(data))
    }

    private static func loadBundledMatrix(
        bundle: Bundle = .main,
        fileName: String = "stage_walk_distances"
    ) -> StageWalkingDistanceMatrix {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            AppLog.data.error("Missing bundled stage walking-distance matrix")
            return .empty
        }

        do {
            let data = try Data(contentsOf: url)
            return try decodeMatrix(from: data)
        } catch {
            AppLog.data.error(
                "Could not decode bundled stage walking-distance matrix: \(error.localizedDescription)"
            )
            return .empty
        }
    }
}
