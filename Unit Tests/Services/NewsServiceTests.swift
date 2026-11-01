import Foundation
import Testing

@testable import Rudolstadt

@MainActor
struct NewsServiceTests {
    @Test
    func loadCachedNewsUsesFreshCacheWithoutFetching() {
        let cachedNews = [TestFixtures.newsItem(id: 7, languageCode: "en")]
        let cache = NewsCacheStub(loadResult: .loaded(cachedNews))
        let apiClient = NewsAPIStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: TestFixtures.userSettings(),
            notifier: NewsNotifierStub()
        )

        let result = service.loadCachedNews()

        guard let result else {
            Issue.record("Expected cached news")
            return
        }
        #expect(result.map(\.id) == [7])
        #expect(apiClient.fetchCallCount == 0)
    }

    @Test
    func loadCachedNewsUsesStaleCacheWithoutFetching() {
        let cachedNews = [TestFixtures.newsItem(id: 8, languageCode: "en")]
        let cache = NewsCacheStub(loadResult: .stale(cachedNews))
        let apiClient = NewsAPIStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: TestFixtures.userSettings(),
            notifier: NewsNotifierStub()
        )

        let result = service.loadCachedNews()

        #expect(result?.map(\.id) == [8])
        #expect(apiClient.fetchCallCount == 0)
    }

    @Test
    func refreshNewsFetchesMissingCacheAndMarksItemsAsOld() async {
        let apiNews = [
            TestFixtures.apiNewsItem(id: 10, language: "en"),
            TestFixtures.apiNewsItem(id: 11, language: "de"),
        ]
        let cache = NewsCacheStub(loadResult: .notFound)
        let apiClient = NewsAPIStub(newsToReturn: apiNews)
        let settings = TestFixtures.userSettings()
        let notifier = NewsNotifierStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: settings,
            notifier: notifier
        )

        let result = await service.refreshNewsIfNecessary()

        guard case .success(let news) = result else {
            Issue.record("Expected fetched news")
            return
        }
        #expect(news.map(\.id) == [10, 11])
        #expect(apiClient.fetchCallCount == 1)
        #expect(cache.storedNewsIds == [10, 11])
        #expect(settings.oldNews == [10, 11])
        #expect(notifier.notifiedItemIds.isEmpty)
    }

    @Test
    func refreshCheckUsesInjectedTimeAndCalendar() async {
        let cachedNews = [TestFixtures.newsItem(id: 12, languageCode: "en")]
        let cache = NewsCacheStub(loadResult: .loaded(cachedNews))
        cache.isFileOlderThanReturnValue = false
        let apiClient = NewsAPIStub()
        let now = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: TestFixtures.userSettings(),
            notifier: NewsNotifierStub(),
            calendar: TestFixtures.festivalCalendar,
            locale: Locale(identifier: "en"),
            now: { now }
        )

        let result = await service.refreshNewsIfNecessary()

        guard case .success(let news) = result else {
            Issue.record("Expected cached news")
            return
        }
        #expect(news.map(\.id) == [12])
        #expect(
            cache.requestedOlderThanDate
                == now.addingTimeInterval(-3 * 60)
        )
        #expect(apiClient.fetchCallCount == 0)
    }

    @Test
    func backgroundRefreshNotifiesOnlyNewItemsInInjectedLanguage() async {
        let apiNews = [
            TestFixtures.apiNewsItem(id: 1, language: "en"),
            TestFixtures.apiNewsItem(id: 2, language: "en"),
            TestFixtures.apiNewsItem(id: 3, language: "de"),
        ]
        let cache = NewsCacheStub(loadResult: .loaded([]))
        let apiClient = NewsAPIStub(newsToReturn: apiNews)
        let settings = TestFixtures.userSettings()
        settings.oldNews = [1]
        let notifier = NewsNotifierStub()
        let service = NewsService(
            dataLoader: cache,
            apiClient: apiClient,
            userSettings: settings,
            notifier: notifier,
            locale: Locale(identifier: "en")
        )

        await service.refreshNewsInBackground()

        #expect(notifier.notifiedItemIds == [2])
        #expect(Set(settings.oldNews) == [1, 2, 3])
    }
}

@MainActor
private final class NewsTestClock {
    var date = TestFixtures.date(dayInJuly: 3, hour: 12, minute: 0)
}

@MainActor
private final class NewsTestContext {
    let cache: NewsCacheStub
    let api = NewsAPIStub()
    let settings: UserSettings
    let notifier = NewsNotifierStub()
    let clock = NewsTestClock()
    let service: NewsService

    init(
        cacheResult: FileLoadingResult<[NewsItem]> = .notFound,
        settings: UserSettings? = nil,
        locale: String = "en"
    ) {
        cache = NewsCacheStub(loadResult: cacheResult)
        let settings = settings ?? TestFixtures.userSettings()
        self.settings = settings
        let clock = clock
        service = NewsService(
            dataLoader: cache, apiClient: api, userSettings: settings, notifier: notifier,
            calendar: TestFixtures.festivalCalendar, locale: Locale(identifier: locale),
            now: { clock.date }
        )
    }

    func nextAttempt() { clock.date += 180 }
}

@MainActor
struct NewsReliabilityTests {
    private func news(_ ids: [Int], language: String = "en") -> [APINewsItem] {
        ids.map { TestFixtures.apiNewsItem(id: $0, language: language) }
    }

    private func cached(_ state: Int) -> FileLoadingResult<[NewsItem]> {
        let items = [TestFixtures.newsItem(id: 10, languageCode: "en")]
        switch state {
        case 0: return .loaded(items)
        case 1: return .stale(items)
        case 2: return .notFound
        default: return .unparsable
        }
    }

    private func ids(_ result: LoadingResult<[NewsItem]>) -> [Int]? {
        if case .success(let items) = result { return items.map(\.id) }
        return nil
    }

    @Test(arguments: [0, 1, 2, 3], [true, false])
    func downloadAndStorageMatrix(cacheState: Int, storageSucceeds: Bool) async {
        let context = NewsTestContext(cacheResult: cached(cacheState))
        context.cache.storeSucceeds = storageSucceeds
        context.api.newsToReturn = news([20, 20, 21])
        context.settings.readNews = [99]
        context.settings.oldNews = [98]

        let result = await context.service.refreshNewsIfNecessary()
        let throttledResult = await context.service.refreshNewsIfNecessary()

        #expect(ids(result) == [20, 21])
        #expect(ids(throttledResult) == [20, 21])
        #expect(context.api.fetchCallCount == 1)
        #expect(context.cache.storeCallCount == 1)
        #expect(context.service.source == .remote)
        #expect(context.service.notice == (storageSucceeds ? nil : .storageFailed))
        #expect(Set(context.settings.oldNews).isSuperset(of: [98, 20, 21]))
        #expect(context.settings.readNews == [99])
        #expect(context.notifier.attemptedItemIds.isEmpty)
    }

    @Test(arguments: [0, 1, 2, 3], [0, 1, 2, 3])
    func networkFailureUsesCacheThenBundle(cacheState: Int, bundleState: Int) async {
        let context = NewsTestContext(cacheResult: cached(cacheState))
        context.cache.bundledResult = cached(bundleState)
        context.api.error = URLError(.notConnectedToInternet)

        let result = await context.service.refreshNewsIfNecessary()
        if cacheState < 2 || bundleState < 2 {
            #expect(ids(result) == [10])
            #expect(context.service.source == (cacheState < 2 ? .cache : .bundle))
            #expect(
                context.service.notice == (cacheState < 2 ? .refreshFailed : .bundledAfterFailure))
        } else {
            guard case .failure(.apiNotResponding) = result else {
                Issue.record("Expected an explicit failure with no usable fallback")
                return
            }
            #expect(context.service.source == nil)
            #expect(context.service.notice == nil)
        }
        #expect(context.cache.storeCallCount == 0)
        #expect(context.notifier.attemptedItemIds.isEmpty)
        _ = await context.service.refreshNewsIfNecessary()
        #expect(context.api.fetchCallCount == 1)
    }

    @Test(arguments: [false, true])
    func firstSnapshotIsSilentAndEmptyBaselinePersists(empty: Bool) async {
        let settings = TestFixtures.userSettings()
        let context = NewsTestContext(settings: settings)
        context.api.newsToReturn = news(empty ? [] : [1, 2])
        await context.service.refreshNewsInBackground()
        #expect(settings.newsBaselineInitialized)
        #expect(context.notifier.notifiedItemIds.isEmpty)

        // A new service represents the next app/background execution.
        let next = NewsTestContext(settings: settings)
        next.api.newsToReturn = news([1, 2, 3])
        await next.service.refreshNewsInBackground()
        #expect(next.notifier.notifiedItemIds == (empty ? [1, 2, 3] : [3]))
        #expect(settings.readNews.isEmpty)
    }

    @Test
    func cachedBaselineIsSilentButLaterDownloadCanNotify() async {
        let context = NewsTestContext(cacheResult: cached(1))
        #expect(context.service.loadCachedNews()?.map(\.id) == [10])
        context.api.newsToReturn = news([10, 11])
        await context.service.refreshNewsInBackground()
        #expect(context.notifier.notifiedItemIds == [11])
        #expect(context.settings.oldNews == [10, 11])
        #expect(context.settings.readNews.isEmpty)
    }

    @Test
    func bundledBaselineIsSilentAfterFailure() async {
        let context = NewsTestContext()
        context.cache.bundledResult = cached(0)
        context.api.error = URLError(.badServerResponse)
        await context.service.refreshNewsInBackground()
        context.api.error = nil
        context.api.newsToReturn = news([10, 11])
        context.nextAttempt()
        await context.service.refreshNewsInBackground()
        #expect(context.notifier.notifiedItemIds == [11])
    }

    @Test(arguments: ["de_DE", "en_US", "fr_FR", "ja_JP"])
    func languagePolicyAndSwitchDoNotReplayHistory(locale: String) async {
        let context = NewsTestContext(locale: locale)
        context.settings.newsBaselineInitialized = true
        context.api.newsToReturn =
            news([1], language: "de")
            + news([2], language: "en") + news([3], language: "xx")
        await context.service.refreshNewsInBackground()
        #expect(context.notifier.notifiedItemIds == (locale == "de_DE" ? [1] : [2]))
        #expect(Set(context.settings.oldNews) == [1, 2, 3])

        let switched = NewsTestContext(
            settings: context.settings, locale: locale == "de_DE" ? "en" : "de")
        switched.api.newsToReturn = context.api.newsToReturn
        await switched.service.refreshNewsInBackground()
        #expect(switched.notifier.attemptedItemIds.isEmpty)
    }

    @Test
    func duplicateNotificationsRetryOnlyFailedHandoffs() async {
        let context = NewsTestContext()
        context.settings.oldNews = [1]
        context.settings.readNews = [4]
        context.notifier.failingIDs = [2]
        context.api.newsToReturn = news([1, 2, 2, 3, 4])
        await context.service.refreshNewsInBackground()
        #expect(context.notifier.attemptedItemIds == [2, 3])
        #expect(context.notifier.notifiedItemIds == [3])
        #expect(Set(context.settings.oldNews) == [1, 3, 4])

        context.nextAttempt()
        context.notifier.failingIDs = []
        context.settings.readNews = []  // Marking unread must not replay a known item.
        await context.service.refreshNewsInBackground()
        #expect(context.notifier.attemptedItemIds == [2, 3, 2])
        #expect(Set(context.settings.oldNews) == [1, 2, 3, 4])
    }

    @Test(arguments: ["foreground", "read", "language"])
    func failedHandoffStopsRetryingWhenNoLongerEligible(change: String) async {
        let context = NewsTestContext()
        context.settings.oldNews = [1]
        context.api.newsToReturn = news([2])
        context.notifier.failingIDs = [2]
        await context.service.refreshNewsInBackground()
        context.nextAttempt()
        context.notifier.failingIDs = []
        if change == "foreground" {
            _ = await context.service.refreshNewsIfNecessary()
        } else if change == "read" {
            context.settings.readNews = [2]
            await context.service.refreshNewsInBackground()
        } else {
            let switched = NewsTestContext(settings: context.settings, locale: "de")
            switched.api.newsToReturn = news([2])
            await switched.service.refreshNewsInBackground()
            #expect(switched.notifier.notifiedItemIds.isEmpty)
        }
        #expect(context.notifier.notifiedItemIds.isEmpty)
        #expect(Set(context.settings.oldNews) == [1, 2])
    }

    @Test
    func disappearedItemsAndEmptyDownloadNeverEraseHistory() async {
        let context = NewsTestContext()
        context.settings.oldNews = [1, 2]
        context.settings.readNews = [8]
        context.api.newsToReturn = []
        #expect(ids(await context.service.refreshNewsIfNecessary()) == [])
        context.nextAttempt()
        context.api.newsToReturn = news([1, 2])
        await context.service.refreshNewsInBackground()
        #expect(context.notifier.notifiedItemIds.isEmpty)
        #expect(context.settings.oldNews == [1, 2])
        #expect(context.settings.readNews == [8])
    }

    @Test(arguments: [false, true])
    func threeMinuteGateCoversSuccessAndFailure(fails: Bool) async {
        let context = NewsTestContext()
        context.api.newsToReturn = news([1])
        if fails { context.api.error = URLError(.timedOut) }
        _ = await context.service.refreshNewsIfNecessary()
        context.clock.date += 179
        await context.service.refreshNewsInBackground()
        _ = await context.service.refreshNewsIfNecessary()
        #expect(context.api.fetchCallCount == 1)
        context.clock.date += 1
        await context.service.refreshNewsInBackground()
        #expect(context.api.fetchCallCount == 2)
    }

    @Test
    func newDownloadRemainsUsableAfterWriteAndLaterNetworkFailure() async {
        let context = NewsTestContext(cacheResult: cached(0))
        context.api.newsToReturn = news([20])
        context.cache.storeSucceeds = false
        _ = await context.service.refreshNewsIfNecessary()
        context.nextAttempt()
        context.api.error = URLError(.notConnectedToInternet)
        #expect(ids(await context.service.refreshNewsIfNecessary()) == [20])
        #expect(context.service.source == .remote)
        #expect(context.service.notice == .refreshFailed)
    }

    @Test
    func storageFailureDoesNotPreventBackgroundNotification() async {
        let context = NewsTestContext()
        context.settings.oldNews = [1]
        context.cache.storeSucceeds = false
        context.api.newsToReturn = news([2])
        await context.service.refreshNewsInBackground()
        #expect(context.notifier.notifiedItemIds == [2])
        #expect(context.service.notice == .storageFailed)
    }
}

@MainActor
private final class NewsFetchGate {
    private var continuation: CheckedContinuation<[APINewsItem], Error>?
    private var started: CheckedContinuation<Void, Never>?

    func fetch() async throws -> [APINewsItem] {
        try await withCheckedThrowingContinuation {
            continuation = $0
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func finish(_ items: [APINewsItem]) { continuation?.resume(returning: items) }
}

@MainActor
struct NewsConcurrencyTests {
    @Test
    func foregroundAndBackgroundShareOneSilentFetch() async {
        let context = NewsTestContext()
        context.settings.oldNews = [1]
        let gate = NewsFetchGate()
        context.api.fetchHandler = { try await gate.fetch() }
        let background = Task { await context.service.refreshNewsInBackground() }
        await gate.waitUntilStarted()
        Task { gate.finish([TestFixtures.apiNewsItem(id: 2, language: "en")]) }
        _ = await context.service.refreshNewsIfNecessary()
        await background.value
        #expect(context.api.fetchCallCount == 1)
        #expect(context.cache.storeCallCount == 1)
        #expect(context.notifier.notifiedItemIds.isEmpty)
        #expect(context.settings.oldNews == [1, 2])
    }

    @Test
    func concurrentBackgroundRequestsNotifyOnce() async {
        let context = NewsTestContext()
        context.settings.oldNews = [1]
        let gate = NewsFetchGate()
        context.api.fetchHandler = { try await gate.fetch() }
        let first = Task { await context.service.refreshNewsInBackground() }
        await gate.waitUntilStarted()
        Task { gate.finish([TestFixtures.apiNewsItem(id: 2, language: "en")]) }
        await context.service.refreshNewsInBackground()
        await first.value
        #expect(context.api.fetchCallCount == 1)
        #expect(context.notifier.notifiedItemIds == [2])
    }

    @Test
    func cancelledFetchCannotWriteOrNotifyEvenIfFetcherIgnoresCancellation() async {
        let context = NewsTestContext()
        context.settings.oldNews = [1]
        let gate = NewsFetchGate()
        context.api.fetchHandler = { try await gate.fetch() }
        let task = Task { await context.service.refreshNewsInBackground() }
        await gate.waitUntilStarted()
        task.cancel()
        gate.finish([TestFixtures.apiNewsItem(id: 2, language: "en")])
        await task.value
        #expect(context.cache.storeCallCount == 0)
        #expect(context.notifier.attemptedItemIds.isEmpty)
        #expect(context.settings.oldNews == [1])
    }
}

@MainActor
struct NewsNotificationContractTests {
    @Test(arguments: ["de", "en", "fr", "ja"], ["de", "en", "unknown", ""])
    func languageFilteringIsStrict(locale: String, language: String) {
        let item = TestFixtures.newsItem(id: 42, languageCode: language)
        #expect(
            item.isInLanguage(Locale(identifier: locale))
                == (language == (locale == "de" ? "de" : "en")))
    }

    @Test
    func payloadRoundTripsAndPreservesNotificationContent() {
        let item = TestFixtures.newsItem(id: 42, languageCode: "en")
        let request = NewsNotificationPayload.request(for: item)
        #expect(request.identifier == FestivalEdition.current.identity.storageKey + "/news/42")
        #expect(request.content.title == item.formattedShortDescription)
        #expect(request.content.body == item.formattedLongDescription)
        #expect(request.content.sound != nil)
        #expect(request.trigger == nil)
        #expect(
            NewsNotificationPayload.itemID(
                userInfo: request.content.userInfo, identifier: request.identifier) == 42)
    }

    @Test
    func notificationRoutesUseFullIdentityAndPreserveLegacyRudolstadtPayloads() {
        let route = NewsNotificationPayload.route(userInfo: ["festivalID": "other",
            "editionID": "winter", "newsItemID": "opening"], identifier: "unused")
        #expect(route == FestivalRoute(identity: FestivalIdentity(festivalID: "other", editionID: "winter"),
            destination: .news("opening")))
        #expect(NewsNotificationPayload.route(userInfo: ["festivalID": "other", "newsItemID": 42], identifier: "42") == nil)
        #expect(NewsNotificationPayload.route(userInfo: [:], identifier: "42") == FestivalRoute(
            identity: FestivalEdition.current.identity, destination: .news("42")))
    }

    @Test
    func payloadAcceptsNumericStringsAndLegacyIdentifiersButRejectsInvalidIDs() {
        #expect(
            NewsNotificationPayload.itemID(userInfo: ["newsItemID": "42"], identifier: "99") == 42)
        #expect(NewsNotificationPayload.itemID(userInfo: [:], identifier: "99") == 99)
        #expect(
            NewsNotificationPayload.itemID(userInfo: ["newsItemID": "invalid"], identifier: "99")
                == 99)
        #expect(NewsNotificationPayload.itemID(userInfo: [:], identifier: "invalid") == nil)
        #expect(
            NewsNotificationPayload.itemID(userInfo: ["newsItemID": -1], identifier: "invalid")
                == nil)
        #expect(NewsNotificationPayload.itemID(userInfo: [:], identifier: "0") == nil)
    }

    @Test
    func clearingAnOlderNavigationRequestPreservesTheNewerOne() {
        let navigation = NewsNotificationNavigationController()
        navigation.requestOpeningNewsItem(id: 1)
        navigation.requestOpeningNewsItem(id: 2)
        navigation.clearRequestedNewsItem(id: 1)
        #expect(navigation.requestedNewsItemID == 2)
        navigation.clearRequestedNewsItem(id: 2)
        #expect(navigation.requestedNewsItemID == nil)
    }

    @Test
    func notificationDestinationWaitsForRefreshThenShowsItemOrList() async {
        let context = NewsTestContext()
        context.api.newsToReturn = [TestFixtures.apiNewsItem(id: 42, language: "en")]
        let store = NewsStore(service: context.service, bundledNewsLoader: FestivalDataCacheStub())
        guard case .loading = store.notificationDestination(id: 42, hasRefreshed: false) else {
            Issue.record("Missing notification target must wait for the refresh")
            return
        }
        await store.refreshNewsIfNecessary()
        guard case .item(let item) = store.notificationDestination(id: 42, hasRefreshed: true)
        else {
            Issue.record("Expected notification detail")
            return
        }
        #expect(item.id == 42)
        guard case .list = store.notificationDestination(id: 99, hasRefreshed: true) else {
            Issue.record("Missing target must fall back to the news list")
            return
        }
        #expect(store.source == .remote)
        #expect(store.notice == nil)
    }

    @Test
    func notificationFailureStillResolvesToListAndPublishesFallbackHint() async {
        let context = NewsTestContext()
        context.api.error = URLError(.notConnectedToInternet)
        context.cache.bundledResult = .loaded([TestFixtures.newsItem(id: 1, languageCode: "en")])
        let store = NewsStore(service: context.service, bundledNewsLoader: FestivalDataCacheStub())
        await store.refreshNewsIfNecessary()
        guard case .list = store.notificationDestination(id: 99, hasRefreshed: true) else {
            Issue.record("Missing target should offer the available list even on refresh failure")
            return
        }
        #expect(store.source == .bundle)
        #expect(store.notice == .bundledAfterFailure)
    }

    @Test
    func baselineStateAndHistoriesPersistWithoutChangingReadState() async {
        let defaults = TestFixtures.isolatedUserDefaults()
        let settings = UserSettings(userDefaults: defaults)
        settings.readNews = [90]
        settings.oldNews = [91]
        let context = NewsTestContext(settings: settings)
        context.api.newsToReturn = [TestFixtures.apiNewsItem(id: 92, language: "en")]
        _ = await context.service.refreshNewsIfNecessary()
        let restored = UserSettings(userDefaults: defaults)
        #expect(restored.newsBaselineInitialized)
        #expect(restored.oldNews == [91, 92])
        #expect(restored.readNews == [90])
    }
}

extension NewsConcurrencyTests {
    @Test(arguments: [false, true])
    func cancellationDuringHandoffPreservesSuccessAndLeavesUnsentItemsRetryable(handoffFails: Bool)
        async
    {
        let context = NewsTestContext()
        context.settings.oldNews = [1]
        context.api.newsToReturn = [
            TestFixtures.apiNewsItem(id: 2, language: "en"),
            TestFixtures.apiNewsItem(id: 3, language: "en"),
            TestFixtures.apiNewsItem(id: 4, language: "de"),
        ]
        if handoffFails { context.notifier.failingIDs = [2] }
        var refresh: Task<Void, Never>?
        context.notifier.notifyHandler = { _ in refresh?.cancel() }
        refresh = Task { await context.service.refreshNewsInBackground() }
        await refresh?.value
        #expect(context.notifier.attemptedItemIds == [2])
        #expect(Set(context.settings.oldNews) == (handoffFails ? [1, 4] : [1, 2, 4]))
        let next = NewsTestContext(settings: context.settings)
        next.api.newsToReturn = context.api.newsToReturn
        await next.service.refreshNewsInBackground()
        #expect(next.notifier.notifiedItemIds == (handoffFails ? [2, 3] : [3]))
    }
}

extension NewsReliabilityTests {
    @Test(arguments: [false, true])
    func freshCacheAlsoThrottlesBackgroundAndForeground(background: Bool) async {
        let context = NewsTestContext(cacheResult: cached(0))
        context.cache.isFileOlderThanReturnValue = false
        if background {
            await context.service.refreshNewsInBackground()
        } else {
            _ = await context.service.refreshNewsIfNecessary()
        }
        #expect(context.api.fetchCallCount == 0)
        #expect(context.cache.requestedOlderThanDate == context.clock.date.addingTimeInterval(-180))
        #expect(context.notifier.notifiedItemIds.isEmpty)
    }

    @Test(arguments: ["{broken", "[{}]", "{}"])
    func malformedNewsResponseUsesCacheWithoutMutatingIt(json: String) async {
        let cache = NewsCacheStub(loadResult: cached(1))
        let http = HTTPClientStub { _ in HTTPResponse(data: Data(json.utf8), statusCode: 200) }
        let service = NewsService(
            dataLoader: cache, apiClient: APIClient(httpClient: http),
            userSettings: TestFixtures.userSettings(), notifier: NewsNotifierStub()
        )
        #expect(ids(await service.refreshNewsIfNecessary()) == [10])
        #expect(cache.storeCallCount == 0)
        #expect(service.notice == .refreshFailed)
    }
}
