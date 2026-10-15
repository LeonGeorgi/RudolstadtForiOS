import Combine
import Foundation

struct RecommendationState {
    var recommendedEventIDs: LoadingEntity<[Int]> = .loading
    var estimatedEventDurationsByEventID: [Int: Int]?
    var generatedAt: Date?
}

@MainActor
final class RecommendationStore: ObservableObject {
    @Published private(set) var state = RecommendationState()

    func reset() {
        state = RecommendationState()
    }

    func beginRefresh() {
        state = RecommendationState(
            estimatedEventDurationsByEventID: state.estimatedEventDurationsByEventID
        )
    }

    func update(_ snapshot: RecommendationSnapshot, generatedAt: Date) {
        state = RecommendationState(
            recommendedEventIDs: .success(snapshot.recommendedEventIds),
            estimatedEventDurationsByEventID: snapshot.estimatedEventDurations,
            generatedAt: generatedAt
        )
    }
}
