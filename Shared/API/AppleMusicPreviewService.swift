import Foundation

struct AppleMusicCatalogReference: Hashable, Sendable {
    enum Kind: String, Sendable {
        case artist
        case album
        case song
    }

    let kind: Kind
    let catalogID: Int
    let storefront: String

    init?(url: URL) {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "music.apple.com"
        else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 3,
              let pathKind = Kind(rawValue: pathComponents[1].lowercased()),
              let pathCatalogID = Int(pathComponents.last ?? ""),
              pathCatalogID > 0
        else {
            return nil
        }

        let storefront = pathComponents[0].lowercased()
        guard !storefront.isEmpty else {
            return nil
        }

        let queryTrackID = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?
        .queryItems?
        .first { $0.name == "i" }?
        .value
        .flatMap(Int.init)

        if pathKind == .album,
           let queryTrackID,
           queryTrackID > 0
        {
            kind = .song
            catalogID = queryTrackID
        } else {
            kind = pathKind
            catalogID = pathCatalogID
        }
        self.storefront = storefront
    }

    init?(urlString: String) {
        guard let url = URL(string: urlString) else {
            return nil
        }
        self.init(url: url)
    }
}

struct AppleMusicPreview: Equatable, Sendable {
    let trackName: String
    let artistName: String
    let previewURL: URL
}

struct AppleMusicPreviewHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
}

enum AppleMusicPreviewServiceError: LocalizedError {
    case invalidLookupURL
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)
    case previewUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidLookupURL:
            return "The Apple Music lookup URL could not be created."
        case .invalidResponse:
            return "Apple Music returned an invalid response."
        case .httpStatus(let statusCode):
            return "Apple Music returned HTTP status \(statusCode)."
        case .decoding(let error):
            return "The Apple Music response could not be decoded: \(error)"
        case .previewUnavailable:
            return "No Apple Music preview is available."
        }
    }
}

struct AppleMusicPreviewService: Sendable {
    typealias Loader = @Sendable (URL) async throws
        -> AppleMusicPreviewHTTPResponse

    private let loader: Loader

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    init(session: URLSession = .shared) {
        self.init { url in
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppleMusicPreviewServiceError.invalidResponse
            }
            return AppleMusicPreviewHTTPResponse(
                data: data,
                statusCode: httpResponse.statusCode
            )
        }
    }

    func fetchPreview(
        for reference: AppleMusicCatalogReference
    ) async throws -> AppleMusicPreview {
        let lookupURL = try makeLookupURL(for: reference)
        let response = try await loader(lookupURL)

        guard (200...299).contains(response.statusCode) else {
            throw AppleMusicPreviewServiceError.httpStatus(response.statusCode)
        }

        let lookupResponse: LookupResponse
        do {
            lookupResponse = try JSONDecoder().decode(
                LookupResponse.self,
                from: response.data
            )
        } catch {
            throw AppleMusicPreviewServiceError.decoding(error)
        }

        let result = lookupResponse.results.first {
            $0.hasPreview && $0.matches(reference)
        }

        guard let result,
              let trackName = result.trackName,
              let artistName = result.artistName,
              let previewURL = result.previewURL
        else {
            throw AppleMusicPreviewServiceError.previewUnavailable
        }

        return AppleMusicPreview(
            trackName: trackName,
            artistName: artistName,
            previewURL: previewURL
        )
    }

    private func makeLookupURL(
        for reference: AppleMusicCatalogReference
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "itunes.apple.com"
        components.path = "/lookup"
        let queryItems = [
            URLQueryItem(name: "id", value: String(reference.catalogID)),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(
                name: "limit",
                value: reference.kind == .artist ? "50" : "10"
            ),
            URLQueryItem(
                name: "country",
                value: reference.storefront.uppercased()
            ),
        ]
        components.queryItems = queryItems
        guard let url = components.url else {
            throw AppleMusicPreviewServiceError.invalidLookupURL
        }
        return url
    }
}

private extension AppleMusicPreviewService {
    struct LookupResponse: Decodable {
        let results: [LookupResult]
    }

    struct LookupResult: Decodable {
        let kind: String?
        let artistID: Int?
        let collectionID: Int?
        let trackID: Int?
        let artistName: String?
        let trackName: String?
        let previewURL: URL?

        enum CodingKeys: String, CodingKey {
            case kind
            case artistID = "artistId"
            case collectionID = "collectionId"
            case trackID = "trackId"
            case artistName
            case trackName
            case previewURL = "previewUrl"
        }

        var hasPreview: Bool {
            kind == "song"
                && trackName != nil
                && artistName != nil
                && previewURL != nil
        }

        func matches(_ reference: AppleMusicCatalogReference) -> Bool {
            switch reference.kind {
            case .artist:
                return artistID == reference.catalogID
            case .album:
                return collectionID == reference.catalogID
            case .song:
                return trackID == reference.catalogID
            }
        }
    }
}
