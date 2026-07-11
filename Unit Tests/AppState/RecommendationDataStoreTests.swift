import Foundation
import Testing
@testable import Rudolstadt

@MainActor
struct RecommendationDataStoreTests {
    @Test
    func refreshRecommendationsStaysLoadingWithoutFestivalData() async {
        let store = DataStore(
            festivalProfileStore: TestFixtures.festivalProfileStore(),
            userSettings: UserSettings(),
            recommendationService: RecommendationServiceStub(
                snapshot: RecommendationSnapshot(
                    recommendedEventIds: [901],
                    estimatedEventDurations: [901: 60]
                )
            )
        )
        store.festivalData = .loading

        await store.refreshRecommendations(
            now: TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        )

        if case .loading = store.recommendedEventIDs {
            #expect(store.estimatedEventDurationsByEventID == nil)
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
            userSettings: UserSettings(),
            recommendationService: RecommendationServiceStub(snapshot: snapshot)
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

        guard case .success(let ids) = store.recommendedEventIDs else {
            Issue.record("Expected recommendation success state")
            return
        }
        #expect(ids == snapshot.recommendedEventIds)
        #expect(
            store.estimatedEventDurationsByEventID
                == snapshot.estimatedEventDurations
        )
    }
}
