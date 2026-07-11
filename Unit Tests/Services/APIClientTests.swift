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
