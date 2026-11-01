import Foundation
import RudolstadtCore

@MainActor
final class RecommendationStore: KotlinStateStore<RecommendationState> {
    let viewModel: RecommendationViewModel
    init() {
        let model = RecommendationViewModel()
        viewModel = model
        super.init(current: { model.current }, observe: model.observe)
    }
    func update(_ snapshot: RecommendationSnapshot, generatedAt: Date, token: Int64? = nil) {
        viewModel.complete(
            token: token ?? viewModel.beginRefresh(), result: snapshot,
            now: generatedAt.timeIntervalSince1970)
    }
}
