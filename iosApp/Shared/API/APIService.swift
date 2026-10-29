import Foundation
import RudolstadtCore

protocol FestivalDataFetching: Sendable {
    func fetchFestivalData() async throws -> RudolstadtPayload
}

extension AppleRemoteClient: @unchecked @retroactive Sendable {}
extension AppleRequest: @unchecked @retroactive Sendable {}

// Its Kotlin HTTP client is lazy; constructing this does not start networking.
let sharedRemoteClient = AppleRemoteClient()

func awaitKotlinRequest<T>(
    _ operation: (AppleRequest) async throws -> T
) async throws -> T {
    let request = AppleRequest()
    do {
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let result = try await operation(request)
            try Task.checkCancellation()
            return result
        } onCancel: {
            request.cancel()
        }
    } catch {
        if Task.isCancelled { throw CancellationError() }
        throw ((error as NSError).kotlinException as? AppleTransportFailure)?.error ?? error
    }
}

struct APIClient: FestivalDataFetching, Sendable {
    static let productionBaseURL: URL = {
        guard let url = URL(string: "https://www.rudolstadt-festival.de/api/") else {
            preconditionFailure("Invalid production API base URL")
        }
        return url
    }()
    private let remote: AppleRemoteClient
    private let baseURL: URL

    init(remote: AppleRemoteClient? = nil, baseURL: URL = productionBaseURL) {
        self.remote = remote ?? sharedRemoteClient
        self.baseURL = baseURL
    }

    func fetchFestivalData() async throws -> RudolstadtPayload {
        try await awaitKotlinRequest { request in
            try await remote.festival(baseURL: baseURL.absoluteString, request: request)
        }
    }

    func fetchNews() async throws -> [APINewsItem] {
        try await awaitKotlinRequest { request in
            try await remote.news(baseURL: baseURL.absoluteString, request: request)
        }
    }
}
