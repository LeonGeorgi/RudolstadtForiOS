import CoreFoundation
import Foundation
import OSLog

enum StageWalkingDistanceProvider {
    private enum DecodingError: Error {
        case invalidTopLevelObject
    }

    static let bundled = loadBundledMatrix()

    static func decodeMatrix(from data: Data) throws -> StageWalkingDistanceMatrix {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let decoded = jsonObject as? [String: Any] else {
            throw DecodingError.invalidTopLevelObject
        }

        var distances = [Int: [Int: Double]]()
        for (sourceKey, rawTargets) in decoded {
            guard let sourceStageID = Int(sourceKey),
                  let targets = rawTargets as? [String: Any]
            else {
                continue
            }

            for (targetKey, rawDistance) in targets {
                guard let targetStageID = Int(targetKey),
                      let distance = rawDistance as? NSNumber,
                      CFGetTypeID(distance) != CFBooleanGetTypeID()
                else {
                    continue
                }
                distances[sourceStageID, default: [:]][targetStageID] =
                    distance.doubleValue
            }
        }
        return StageWalkingDistanceMatrix(distancesByStageID: distances)
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
