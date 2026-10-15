import Combine
import Foundation
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
        let recommendationObservation = store.recommendationStore.$state
            .dropFirst()
            .sink { publishedResults.append($0) }
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
        guard let result = publishedResults.last,
              case .success(let eventIDs) = result.recommendedEventIDs else {
            Issue.record("Expected a complete recommendation result")
            return
        }
        #expect(eventIDs == snapshot.recommendedEventIds)
        #expect(result.estimatedEventDurationsByEventID == snapshot.estimatedEventDurations)
        #expect(result.generatedAt == generatedAt)
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

        if case .loading = store.recommendationStore.state.recommendedEventIDs {
            #expect(store.recommendationStore.state.estimatedEventDurationsByEventID == nil)
        } else {
            Issue.record("Expected loading state")
        }
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

        guard case .success(let ids) = store.recommendationStore.state.recommendedEventIDs else {
            Issue.record("Expected recommendation success state")
            return
        }
        #expect(ids == snapshot.recommendedEventIds)
        #expect(
            store.recommendationStore.state.estimatedEventDurationsByEventID
                == snapshot.estimatedEventDurations
        )
    }
}
