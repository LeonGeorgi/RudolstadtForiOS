import SwiftUI

enum FileLoadingResult<T> {
    case loaded(T)
    case tooOld(T)
    case notFound
    case unparsable
}

struct EntityHelper<T, S> where S: StringProtocol {
    let filename: String
    let converter: ([S]) -> [T]
}

struct Entities {
    let artists: [Artist]
    let areas: [Area]
    let stages: [Stage]
    let events: [Event]
    let news: [NewsItem]
}

enum LoadingEntity<T> {
    case loading
    case success(T)
    case failure(FailureReason)

    init(from result: LoadingResult<T>) {
        switch result {
        case .failure(let reason):
            self = .failure(reason)
        case .success(let value):
            self = .success(value)
        }
    }

    func map<R>(mapper: (T) -> R) -> LoadingEntity<R> {
        switch self {
        case .loading:
            return .loading
        case .success(let t):
            return .success(mapper(t))
        case .failure(let failureReason):
            return .failure(failureReason)
        }
    }
}

enum LoadingResult<T> {
    case success(T)
    case failure(FailureReason)
}

enum FailureReason: String {
    case noConnection
    case apiNotResponding
    case couldNotLoadFromFile
}

enum DownloadResult {
    case success
    case failure(DownloadFailureReason)
}

enum DownloadFailureReason {
    case downloadError
    case unableToSave
}
