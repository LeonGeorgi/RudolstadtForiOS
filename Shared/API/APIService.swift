import Foundation

enum Endpoint: String, CaseIterable {
    case news = "news"
    case areas = "areas"
    case artists = "artists"
    case events = "events"
    case stages = "stages"
    case tags = "tags"

    var url: URL {
        URL(string: "https://www.rudolstadt-festival.de/api/\(rawValue)")!
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

struct APIClient {

    private let session = URLSession.shared

    func fetch<T: Decodable>(_ type: T.Type, from endpoint: Endpoint)
        async throws -> T
    {
        let (data, response) = try await session.data(from: endpoint.url)
        guard let response = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse(endpoint: endpoint)
        }
        guard (200...299).contains(response.statusCode) else {
            throw APIClientError.httpStatus(
                endpoint: endpoint,
                statusCode: response.statusCode,
                bodyPreview: makeBodyPreview(from: data)
            )
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIClientError.decoding(
                endpoint: endpoint,
                underlyingError: error,
                bodyPreview: makeBodyPreview(from: data)
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
