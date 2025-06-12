import Foundation

enum Endpoint: String, CaseIterable {
    case news    = "news"
    case areas   = "areas"
    case artists = "artists"
    case events  = "events"
    case stages  = "stages"
    case tags    = "tags"
    
    var url: URL {
        URL(string: "https://www.rudolstadt-festival.de/api/\(rawValue)")!
    }
}


struct APIClient {
    
    private let session = URLSession.shared
    
    func fetch<T: Decodable>(_ type: T.Type, from endpoint: Endpoint) async throws -> T {
        let (data, _) = try await session.data(from: endpoint.url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func fetchAll() async throws -> APIRudolstadtData {
        async let news:   [APINewsItem]    = fetch([APINewsItem].self,   from: .news)
        async let areas:  [APIArea]    = fetch([APIArea].self,   from: .areas)
        async let artists:[APIArtist]  = fetch([APIArtist].self, from: .artists)
        async let events: [APIEvent]   = fetch([APIEvent].self,  from: .events)
        async let stages: [APIStage]   = fetch([APIStage].self,  from: .stages)
        async let tags:   [APITag]     = fetch([APITag].self,    from: .tags)
        
        return try await APIRudolstadtData(
            news: news,
            areas: areas,
            artists: artists,
            events: events,
            stages: stages,
            tags: tags
        )
    }
}
