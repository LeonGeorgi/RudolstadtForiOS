import Combine
import Foundation
import RudolstadtCore
import Testing
@testable import Rudolstadt

@MainActor
struct RecommendationDataStoreTests {
    @Test
    func recommendationRefreshPublishesCoherentResultsWithoutFestivalChanges() async {
        let snapshot = RecommendationSnapshot(
            recommendedEventIds: [Event.example.id],
            estimatedEventDurations: [Event.example.id: 90]
        )
        let store = DataStore(
            festivalProfileStore: TestFixtures.festivalProfileStore(),
            userSettings: TestFixtures.userSettings(),
            recommendationService: RecommendationServiceStub(snapshot: snapshot),
            loadInitialData: false
        )
        store.festivalData = .success(TestFixtures.festivalData(events: [.example]))
        var festivalChanges = 0
        var newsChanges = 0
        var publishedResults: [RecommendationState] = []
        let festivalObservation = store.objectWillChange.sink { festivalChanges += 1 }
        let newsObservation = store.newsStore.objectWillChange.sink { newsChanges += 1 }
        let recommendationObservation = store.recommendationStore.objectWillChange
            .sink { publishedResults.append(store.recommendationStore.state) }
        defer {
            festivalObservation.cancel()
            newsObservation.cancel()
            recommendationObservation.cancel()
        }
        let generatedAt = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)

        await store.refreshRecommendations(now: generatedAt)

        #expect(festivalChanges == 0)
        #expect(newsChanges == 0)
        #expect(publishedResults.count == 2)
        guard let result = publishedResults.last, result.phase == .ready else {
            Issue.record("Expected a complete recommendation result")
            return
        }
        #expect(result.eventIDs.map(\.intValue) == snapshot.recommendedEventIds)
        #expect(result.durations?.map { Int($0.minutes) } == [90])
        #expect(result.generatedAt?.date == generatedAt)
        #expect(result === store.recommendationStore.viewModel.current)
    }

    @Test
    func observationReadsSharedSnapshotsAndReleasesItsOwner() {
        var store: RecommendationStore? = RecommendationStore()
        weak var owner: RecommendationStore?
        owner = store
        let model = store!.viewModel
        let initial = store!.state
        #expect(initial === model.current)
        model.disable()
        #expect(store!.state === model.current)
        #expect(store!.state.phase == .ready)
        #expect(initial.phase == .loading)
        store = nil
        #expect(owner == nil)
        model.reset()
    }

    @Test
    func refreshRecommendationsStaysLoadingWithoutFestivalData() async {
        let store = DataStore(
            festivalProfileStore: TestFixtures.festivalProfileStore(),
            userSettings: TestFixtures.userSettings(),
            recommendationService: RecommendationServiceStub(
                snapshot: RecommendationSnapshot(
                    recommendedEventIds: [901],
                    estimatedEventDurations: [901: 60]
                )
            ),
            loadInitialData: false
        )
        store.festivalData = .loading

        await store.refreshRecommendations(
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        #expect(store.recommendationStore.state.phase == .loading)
        #expect(store.recommendationStore.state.durations == nil)
    }

    @Test
    func refreshRecommendationsPublishesServiceSnapshot() async {
        let snapshot = RecommendationSnapshot(
            recommendedEventIds: [902, 903],
            estimatedEventDurations: [902: 60, 903: 90]
        )
        let store = DataStore(
            festivalProfileStore: TestFixtures.festivalProfileStore(),
            userSettings: TestFixtures.userSettings(),
            recommendationService: RecommendationServiceStub(snapshot: snapshot),
            loadInitialData: false
        )
        store.festivalData = .success(
            TestFixtures.festivalData(events: [
                TestFixtures.event(
                    id: 902,
                    dayInJuly: 3,
                    timeAsString: "18:00",
                    stage: TestFixtures.stage(id: 18),
                    artist: TestFixtures.artist(id: 41)
                ),
                TestFixtures.event(
                    id: 903,
                    dayInJuly: 3,
                    timeAsString: "20:00",
                    stage: TestFixtures.stage(id: 19),
                    artist: TestFixtures.artist(id: 42)
                ),
            ])
        )

        await store.refreshRecommendations(
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        let state = store.recommendationStore.state
        #expect(state.phase == .ready)
        #expect(state.eventIDs.map(\.intValue) == snapshot.recommendedEventIds)
        #expect(
            Dictionary(
                uniqueKeysWithValues: (state.durations ?? []).map {
                    (Int($0.eventID), Int($0.minutes))
                }) == snapshot.estimatedEventDurations)
    }
}
