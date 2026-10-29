import RudolstadtCore
import Foundation
import Testing
@testable import Rudolstadt

struct APIClientTests {
    @Test
    func fetchUsesInjectedBaseURLAndHTTPClient() async throws {
        let responseData = Data(#"[{"id":7,"title":"Innenstadt","title_en":"City Centre"}]"#.utf8)
        let httpClient = HTTPClientStub { url in
            HTTPResponse(data: url.lastPathComponent == "areas" ? responseData : Data("[]".utf8), statusCode: 200)
        }
        let baseURL = try #require(
            URL(string: "https://example.com/festival-api/")
        )
        let client = APIClient(
            httpClient: httpClient,
            baseURL: baseURL
        )

        let payload = try await client.fetchFestivalData()
        let requestedURLs = await httpClient.requestedURLs

        #expect(try TestFixtures.sourceRecords(payload, "areas").compactMap { $0["id"] as? Int } == [7])
        #expect(
            Set(requestedURLs)
                == Set(["areas", "artists", "events", "stages", "tags"].map { baseURL.appendingPathComponent($0) })
        )
    }

    @Test
    func fetchReportsInjectedHTTPErrorResponse() async throws {
        let httpClient = HTTPClientStub { _ in
            HTTPResponse(
                data: Data("Service unavailable".utf8),
                statusCode: 503
            )
        }
        let baseURL = try #require(URL(string: "https://example.com/api/"))
        let client = APIClient(
            httpClient: httpClient,
            baseURL: baseURL
        )

        do {
            _ = try await client.fetchNews()
            Issue.record("Expected HTTP status error")
        } catch {
            guard let failure = (error as NSError).kotlinException as? RemoteHttpError else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(failure.endpoint == "news")
            #expect(failure.statusCode == 503)
            #expect(failure.bodyPreview == "Service unavailable")
        }
    }
}

extension APIClientTests {
    @Test(.timeLimit(.minutes(1)))
    func swiftCancellationStopsTheSharedRequestAndNativeTestTransport() async {
        let probe = HTTPRequestCancellationProbe()
        let task = Task { try await APIClient(httpClient: probe).fetchNews() }
        await probe.waitUntilStarted()
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            await probe.waitUntilCancelled()
        } catch { Issue.record("Unexpected error: \(error)") }
    }

    @Test
    func cancelledTokenDoesNotStartAnHTTPCall() async {
        let http = HTTPClientStub { _ in HTTPResponse(data: Data("[]".utf8), statusCode: 200) }
        let request = AppleRequest()
        request.cancel()
        do {
            _ = try await AppleRemoteClient(source: TestHTTPSource(http)).news(
                baseURL: "https://example.com/api/", request: request)
            Issue.record("Expected cancellation before the request starts")
        } catch {
            #expect((error as NSError).kotlinException is KotlinCancellationException)
        }
        #expect(await http.requestedURLs.isEmpty)
    }

    @Test
    func transportFailurePreservesNativeErrorForOfflineFallback() async {
        let http = HTTPClientStub { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await APIClient(httpClient: http).fetchNews()
            Issue.record("Expected offline error")
        } catch {
            #expect((error as NSError).domain == NSURLErrorDomain)
            #expect((error as NSError).code == URLError.notConnectedToInternet.rawValue)
        }
    }

    @Test
    func invalidUTF8CannotSilentlyChangeArtistNames() async {
        let http = HTTPClientStub { url in
            var data = Data("[{\"id\":1,\"name\":\"".utf8)
            data.append(0xFF)
            data.append(contentsOf: "\"}]".utf8)
            return HTTPResponse(data: url.lastPathComponent == "artists" ? data : Data("[]".utf8), statusCode: 200)
        }
        do {
            _ = try await APIClient(httpClient: http).fetchFestivalData()
            Issue.record("Invalid UTF-8 must fail rather than replace letters in artist names")
        } catch {
            #expect(((error as NSError).kotlinException as? RemoteDecodingError)?.endpoint == "artists")
        }
    }

    @Test
    func festivalFetchRetainsIdentifiableEventsAndReportsSkippedRecords() async throws {
        let http = HTTPClientStub { url in
            let json =
                url.lastPathComponent == "events"
                ? #"[{"id":41},{"id":"bad"},null,{"id":42,"artist":8}]"# : "[]"
            return HTTPResponse(data: Data(json.utf8), statusCode: 200)
        }
        let api = try await APIClient(httpClient: http).fetchFestivalData()
        #expect(try TestFixtures.sourceRecords(api, "events").compactMap { $0["id"] as? Int } == [41, 42])
        #expect(api.omittedRecordCount == 2)
        let cached = try KotlinCore.bridge.decodeRudolstadtPayload(sourceJSON: api.sourceJSON)
        #expect(cached.omittedRecordCount == 2)
    }

    @Test(arguments: ["{broken", #"{"events":[]}"#])
    func structuralErrorsStillFailTheFestivalFetch(json: String) async {
        let http = HTTPClientStub { url in
            HTTPResponse(
                data: Data((url.lastPathComponent == "events" ? json : "[]").utf8), statusCode: 200)
        }
        do {
            _ = try await APIClient(httpClient: http).fetchFestivalData()
            Issue.record("Expected an invalid event response to fail for the existing fallback")
        } catch {
            #expect(((error as NSError).kotlinException as? RemoteDecodingError)?.endpoint == "events")
        }
    }
}

private actor HTTPRequestCancellationProbe: HTTPClient {
    private var started = false
    private var cancelled = false
    private var startedWaiter: CheckedContinuation<Void, Never>?
    private var cancelledWaiter: CheckedContinuation<Void, Never>?

    func data(from url: URL) async throws -> HTTPResponse {
        started = true
        startedWaiter?.resume()
        do {
            try await Task.sleep(for: .seconds(30))
            return HTTPResponse(data: Data("[]".utf8), statusCode: 200)
        } catch {
            cancelled = true
            cancelledWaiter?.resume()
            throw error
        }
    }

    func waitUntilStarted() async {
        if !started { await withCheckedContinuation { startedWaiter = $0 } }
    }

    func waitUntilCancelled() async {
        if !cancelled { await withCheckedContinuation { cancelledWaiter = $0 } }
    }
}
