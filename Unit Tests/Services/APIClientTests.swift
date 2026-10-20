import Foundation
import Testing
@testable import Rudolstadt

struct APIClientTests {
    @Test
    func fetchUsesInjectedBaseURLAndHTTPClient() async throws {
        let responseData = try JSONEncoder().encode([
            APIArea(id: 7, title: "Innenstadt", titleEN: "City Centre")
        ])
        let httpClient = HTTPClientStub { _ in
            HTTPResponse(data: responseData, statusCode: 200)
        }
        let baseURL = try #require(
            URL(string: "https://example.com/festival-api/")
        )
        let client = APIClient(
            httpClient: httpClient,
            baseURL: baseURL
        )

        let areas = try await client.fetch([APIArea].self, from: .areas)
        let requestedURLs = await httpClient.requestedURLs

        #expect(areas.map(\.id) == [7])
        #expect(
            requestedURLs
                == [baseURL.appendingPathComponent(Endpoint.areas.rawValue)]
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
            let _: [APIArea] = try await client.fetch(
                [APIArea].self,
                from: .areas
            )
            Issue.record("Expected HTTP status error")
        } catch let APIClientError.httpStatus(
            endpoint,
            statusCode,
            bodyPreview
        ) {
            #expect(endpoint == .areas)
            #expect(statusCode == 503)
            #expect(bodyPreview == "Service unavailable")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

extension APIClientTests {
    @Test
    func festivalFetchRetainsIdentifiableEventsAndReportsSkippedRecords() async throws {
        let http = HTTPClientStub { url in
            let json =
                url.lastPathComponent == "events"
                ? #"[{"id":41},{"id":"bad"},null,{"id":42,"artist":8}]"# : "[]"
            return HTTPResponse(data: Data(json.utf8), statusCode: 200)
        }
        let api = try await APIClient(httpClient: http).fetchFestivalData()
        #expect(api.events.map(\.id) == [41, 42])
        #expect(api.omittedRecordCount == 2)
        let cached = try JSONDecoder().decode(
            APIRudolstadtData.self, from: JSONEncoder().encode(api))
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
        } catch APIClientError.decoding(let endpoint, _, _) {
            #expect(endpoint == .events)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
