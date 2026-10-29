import Foundation
import RudolstadtCore

typealias AppleMusicCatalogReference = MusicReference
extension MusicReference: @unchecked @retroactive Sendable {
    convenience init?(url: URL) {
        guard let reference = MediaLinks.shared.music(parts: MediaURLParts(url)) else { return nil }
        self.init(
            kind: reference.kind, catalogID: reference.catalogID, storefront: reference.storefront)
    }
    convenience init?(urlString: String) {
        guard let url = URL(string: urlString) else { return nil }
        self.init(url: url)
    }
}
extension MediaURLParts {
    convenience init(_ url: URL) {
        self.init(
            scheme: url.scheme, host: url.host,
            path: url.pathComponents.filter { $0 != "/" },
            query: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.map {
                MediaParameter(name: $0.name, value: $0.value)
            } ?? [])
    }
}

struct AppleMusicPreview: Equatable, Sendable {
    let trackName: String
    let artistName: String
    let previewURL: URL
}

enum AppleMusicPreviewServiceError: LocalizedError {
    case httpStatus(Int)
    case decoding(Error)
    case previewUnavailable

    var errorDescription: String? {
        switch self {
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
    private let remote: AppleRemoteClient

    init(remote: AppleRemoteClient? = nil) {
        self.remote = remote ?? sharedRemoteClient
    }

    func fetchPreview(
        for reference: AppleMusicCatalogReference
    ) async throws -> AppleMusicPreview {
        let selection: MusicPreviewSelection?
        do {
            selection = try await awaitKotlinRequest { request in
                try await remote.musicPreview(
                    reference: reference,
                    validURL: { KotlinBoolean(bool: URL(string: $0) != nil) },
                    request: request)
            }
        } catch {
            switch (error as NSError).kotlinException {
            case let failure as RemoteHttpError:
                throw AppleMusicPreviewServiceError.httpStatus(Int(failure.statusCode))
            case is RemoteDecodingError:
                throw AppleMusicPreviewServiceError.decoding(error)
            default: throw error
            }
        }
        guard let selection, let previewURL = URL(string: selection.audioURL) else {
            throw AppleMusicPreviewServiceError.previewUnavailable
        }
        return AppleMusicPreview(
            trackName: selection.trackName,
            artistName: selection.artistName,
            previewURL: previewURL
        )
    }

}
