import Foundation

enum Endpoint: String, CaseIterable {
    case news = "news"
    case areas = "areas"
    case artists = "artists"
    case events = "events"
    case stages = "stages"
    case tags = "tags"

    func url(relativeTo baseURL: URL) -> URL {
        baseURL.appendingPathComponent(rawValue)
    }
}

struct HTTPResponse: Sendable {
    let data: Data
    let statusCode: Int?
}

protocol HTTPClient: Sendable {
    func data(from url: URL) async throws -> HTTPResponse
}

protocol FestivalDataFetching: Sendable {
    func fetchFestivalData() async throws -> APIRudolstadtData
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL) async throws -> HTTPResponse {
        let (data, response) = try await session.data(from: url)
        return HTTPResponse(
            data: data,
            statusCode: (response as? HTTPURLResponse)?.statusCode
        )
    }
}

enum APIClientError: LocalizedError {
    case invalidResponse(endpoint: Endpoint)
    case httpStatus(endpoint: Endpoint, statusCode: Int, bodyPreview: String)
    case decoding(endpoint: Endpoint, underlyingError: Error, bodyPreview: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse(let endpoint):
            return "Invalid response for endpoint '\(endpoint.rawValue)'"
        case .httpStatus(let endpoint, let statusCode, let bodyPreview):
            return "HTTP \(statusCode) for endpoint '\(endpoint.rawValue)'. Body preview: \(bodyPreview)"
        case .decoding(let endpoint, let underlyingError, let bodyPreview):
            return "Decoding failed for endpoint '\(endpoint.rawValue)': \(underlyingError). Body preview: \(bodyPreview)"
        }
    }
}

struct APIClient: FestivalDataFetching, Sendable {
    static let productionBaseURL: URL = {
        guard let url = URL(string: "https://www.rudolstadt-festival.de/api/") else {
            preconditionFailure("Invalid production API base URL")
        }
        return url
    }()

    private let httpClient: any HTTPClient
    private let baseURL: URL

    init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = APIClient.productionBaseURL
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    func fetch<T: Decodable>(_ type: T.Type, from endpoint: Endpoint)
        async throws -> T
    {
        let response = try await httpClient.data(
            from: endpoint.url(relativeTo: baseURL)
        )
        guard let statusCode = response.statusCode else {
            throw APIClientError.invalidResponse(endpoint: endpoint)
        }
        guard (200...299).contains(statusCode) else {
            throw APIClientError.httpStatus(
                endpoint: endpoint,
                statusCode: statusCode,
                bodyPreview: makeBodyPreview(from: response.data)
            )
        }
        do {
            return try JSONDecoder().decode(T.self, from: response.data)
        } catch {
            throw APIClientError.decoding(
                endpoint: endpoint,
                underlyingError: error,
                bodyPreview: makeBodyPreview(from: response.data)
            )
        }
    }

    func fetchFestivalData() async throws -> APIRudolstadtData {
        async let areas: [APIArea] = fetch([APIArea].self, from: .areas)
        async let artists: [APIArtist] = fetch([APIArtist].self, from: .artists)
        async let events: [APIEvent] = fetch([APIEvent].self, from: .events)
        async let stages: [APIStage] = fetch([APIStage].self, from: .stages)
        async let tags: [APITag] = fetch([APITag].self, from: .tags)

        return try await APIRudolstadtData(
            areas: areas,
            artists: artists,
            events: events,
            stages: stages,
            tags: tags
        )
    }
    
    func fetchNews() async throws -> [APINewsItem] {
        return try await fetch([APINewsItem].self, from: .news)
    }

    private func makeBodyPreview(from data: Data, maxLength: Int = 500) -> String {
        let text = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        if text.count <= maxLength {
            return text
        }
        let endIndex = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<endIndex]) + "..."
    }
}
