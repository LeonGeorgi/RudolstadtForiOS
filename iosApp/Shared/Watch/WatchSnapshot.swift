import Foundation
import RudolstadtCore

enum WatchSnapshotTransport {
    static let applicationContextKey = "festivalSnapshot"
}

enum WatchSnapshotEnvironment: String, Codable, Equatable, Sendable {
    case production
    case preview
    case test
    case screenshot
}

enum WatchFestivalDataSource: String, Codable, Equatable, Sendable {
    case remote
    case cache
    case staleCache
    case bundledBackup
}

enum WatchSnapshotAvailabilityState: String, Codable, Equatable, Sendable {
    case available
    case loading
    case failed
    case unavailable
}

struct WatchSnapshotFreshness: Codable, Equatable, Sendable {
    let festivalDataSource: WatchFestivalDataSource
    let festivalDataUpdatedAt: Date?
    let refreshCheckedAt: Date?
    let profileCloudRefreshedAt: Date?
    let recommendationsGeneratedAt: Date?
}

struct WatchRecommendationSnapshot: Codable, Equatable, Sendable {
    let state: WatchSnapshotAvailabilityState
    let generatedAt: Date?
    let orderedEventIDs: [Int]
}

struct WatchFriendSnapshot: Codable, Equatable, Sendable {
    let state: WatchSnapshotAvailabilityState
    let updatedAt: Date?
}

struct WatchEventSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let artistID: Int
    let artistName: String
    let stageID: Int
    let stageNumber: Int?
    let stageNameGerman: String
    let stageNameEnglish: String
    let festivalDay: Int
    let startDate: Date
    let endDate: Date
    let isSaved: Bool
    let hasPositiveRating: Bool
    let recommendationRank: Int?
    let friendSaveCount: Int?
}

enum WatchPlanTransitionStatus: String, Codable, Equatable, Sendable {
    case comfortable
    case tight
    case impossible
    case unknown
}

enum WatchTransferCertainty: String, Codable, Equatable, Sendable {
    case known
    case estimated
    case unknown
}

struct WatchPlanTransitionSnapshot: Codable, Equatable, Sendable {
    let fromEventID: Int
    let toEventID: Int
    let status: WatchPlanTransitionStatus
    let walkingMinutes: Int?
    let projectedLatenessMinutes: Int?
    let certainty: WatchTransferCertainty
}

struct WatchPlanOverlapSnapshot: Codable, Equatable, Sendable {
    let firstEventID: Int
    let secondEventID: Int
    let overlapMinutes: Int
}

struct WatchUnplacedEventSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let artistName: String
    let stageNameGerman: String
    let stageNameEnglish: String
    let knownDay: Date?
}

struct WatchFestivalSnapshot: Codable, Equatable, Sendable {
    let events: [WatchEventSnapshot]
    let missingSavedEventCount: Int?
    let recommendations: WatchRecommendationSnapshot
    let friends: WatchFriendSnapshot
    let planTransitions: [WatchPlanTransitionSnapshot]
    let planOverlaps: [WatchPlanOverlapSnapshot]
    let unplacedSavedEvents: [WatchUnplacedEventSnapshot]?
    let hasIncompleteProgram: Bool?

    init(
        events: [WatchEventSnapshot],
        missingSavedEventCount: Int? = nil,
        recommendations: WatchRecommendationSnapshot,
        friends: WatchFriendSnapshot,
        planTransitions: [WatchPlanTransitionSnapshot],
        planOverlaps: [WatchPlanOverlapSnapshot],
        unplacedSavedEvents: [WatchUnplacedEventSnapshot]? = nil,
        hasIncompleteProgram: Bool? = nil
    ) {
        self.events = events
        self.missingSavedEventCount = missingSavedEventCount
        self.recommendations = recommendations
        self.friends = friends
        self.planTransitions = planTransitions
        self.planOverlaps = planOverlaps
        self.unplacedSavedEvents = unplacedSavedEvents
        self.hasIncompleteProgram = hasIncompleteProgram
    }
}

struct WatchSnapshotEnvelope: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let festivalYear: Int
    let revision: UInt64
    let generatedAt: Date
    let environment: WatchSnapshotEnvironment
    let freshness: WatchSnapshotFreshness
    let payload: WatchFestivalSnapshot
}

enum WatchSnapshotCodecError: Error, Equatable {
    case payloadTooLarge(actualByteCount: Int, maximumByteCount: Int)
}

struct WatchSnapshotCodec: Sendable {
    static let defaultMaximumEncodedByteCount = 60_000
    static let defaultMaximumDecodedByteCount = 5_000_000

    let maximumEncodedByteCount: Int
    let maximumDecodedByteCount: Int

    init(
        maximumEncodedByteCount: Int = Self.defaultMaximumEncodedByteCount,
        maximumDecodedByteCount: Int = Self.defaultMaximumDecodedByteCount
    ) {
        self.maximumEncodedByteCount = max(1, maximumEncodedByteCount)
        self.maximumDecodedByteCount = max(1, maximumDecodedByteCount)
    }

    func encode(_ envelope: WatchSnapshotEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let decodedData = try encoder.encode(envelope)
        try checkDecodedSize(of: decodedData)
        let encodedData = try (decodedData as NSData).compressed(using: .lzfse) as Data
        try checkEncodedSize(of: encodedData)
        return encodedData
    }

    func decode(_ data: Data) throws -> WatchSnapshotEnvelope {
        let decodedData = try decodedData(from: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(WatchSnapshotEnvelope.self, from: decodedData)
    }

    func decodeHeader(_ data: Data) throws -> WatchSnapshotHeader {
        let decodedData = try decodedData(from: data)
        return try JSONDecoder().decode(WatchSnapshotHeader.self, from: decodedData)
    }

    private func decodedData(from encodedData: Data) throws -> Data {
        try checkEncodedSize(of: encodedData)
        let decodedData = try (encodedData as NSData).decompressed(using: .lzfse) as Data
        try checkDecodedSize(of: decodedData)
        return decodedData
    }

    private func checkEncodedSize(of data: Data) throws {
        guard data.count <= maximumEncodedByteCount else {
            throw WatchSnapshotCodecError.payloadTooLarge(
                actualByteCount: data.count,
                maximumByteCount: maximumEncodedByteCount
            )
        }
    }

    private func checkDecodedSize(of data: Data) throws {
        guard data.count <= maximumDecodedByteCount else {
            throw WatchSnapshotCodecError.payloadTooLarge(
                actualByteCount: data.count,
                maximumByteCount: maximumDecodedByteCount
            )
        }
    }
}

struct WatchSnapshotHeader: Decodable, Equatable, Sendable {
    let schemaVersion: Int
    let festivalYear: Int
    let revision: UInt64
    let environment: String
}

enum WatchSnapshotPayloadIssue: Equatable, Sendable {
    case duplicateEventID(Int)
    case invalidEventDates(Int)
    case invalidPlanContract
    case invalidRecommendationContract
    case invalidFriendContract
    case invalidTransitionReference
    case invalidOverlapReference
}

enum WatchSnapshotRejection: Equatable, Sendable {
    case payloadTooLarge
    case corrupt
    case incompatibleSchema(received: Int, supported: Int)
    case wrongFestivalYear(received: Int, expected: Int)
    case disallowedEnvironment(String)
    case duplicateRevision(UInt64)
    case olderRevision(received: UInt64, current: UInt64)
    case invalidPayload(WatchSnapshotPayloadIssue)
}

enum WatchSnapshotValidation: Equatable, Sendable {
    case accepted(WatchSnapshotEnvelope)
    case rejected(WatchSnapshotRejection)
}

struct WatchSnapshotValidator: Sendable {
    let expectedFestivalYear: Int
    let supportedSchemaVersion: Int
    let expectedEnvironment: WatchSnapshotEnvironment
    let codec: WatchSnapshotCodec

    init(
        expectedFestivalYear: Int,
        supportedSchemaVersion: Int = WatchSnapshotEnvelope.currentSchemaVersion,
        expectedEnvironment: WatchSnapshotEnvironment = .production,
        codec: WatchSnapshotCodec = WatchSnapshotCodec()
    ) {
        self.expectedFestivalYear = expectedFestivalYear
        self.supportedSchemaVersion = supportedSchemaVersion
        self.expectedEnvironment = expectedEnvironment
        self.codec = codec
    }

    func validate(
        _ data: Data,
        currentRevision: UInt64?
    ) -> WatchSnapshotValidation {
        let header: WatchSnapshotHeader
        do {
            header = try codec.decodeHeader(data)
        } catch is WatchSnapshotCodecError {
            return .rejected(.payloadTooLarge)
        } catch {
            return .rejected(.corrupt)
        }

        guard header.schemaVersion == supportedSchemaVersion else {
            return .rejected(.incompatibleSchema(
                received: header.schemaVersion,
                supported: supportedSchemaVersion
            ))
        }
        guard header.festivalYear == expectedFestivalYear else {
            return .rejected(.wrongFestivalYear(
                received: header.festivalYear,
                expected: expectedFestivalYear
            ))
        }
        guard header.environment == expectedEnvironment.rawValue else {
            return .rejected(.disallowedEnvironment(header.environment))
        }
        if let currentRevision {
            if header.revision == currentRevision {
                return .rejected(.duplicateRevision(header.revision))
            }
            if header.revision < currentRevision {
                return .rejected(.olderRevision(
                    received: header.revision,
                    current: currentRevision
                ))
            }
        }

        let envelope: WatchSnapshotEnvelope
        do {
            envelope = try codec.decode(data)
        } catch is WatchSnapshotCodecError {
            return .rejected(.payloadTooLarge)
        } catch {
            return .rejected(.corrupt)
        }

        if let issue = payloadIssue(in: envelope.payload) {
            return .rejected(.invalidPayload(issue))
        }
        return .accepted(envelope)
    }

    private func payloadIssue(
        in payload: WatchFestivalSnapshot
    ) -> WatchSnapshotPayloadIssue? {
        var eventIDs = Set<Int>()
        for event in payload.events {
            guard eventIDs.insert(event.id).inserted else {
                return .duplicateEventID(event.id)
            }
            guard event.startDate < event.endDate else {
                return .invalidEventDates(event.id)
            }
        }

        if let unplaced = payload.unplacedSavedEvents, !unplaced.isEmpty {
            guard payload.hasIncompleteProgram == true,
                (payload.missingSavedEventCount ?? 0) >= unplaced.count
            else {
                return .invalidPlanContract
            }
        }
        var unplacedIDs = Set<Int>()
        for event in payload.unplacedSavedEvents ?? [] {
            guard event.id > 0, !eventIDs.contains(event.id), unplacedIDs.insert(event.id).inserted
            else {
                return .duplicateEventID(event.id)
            }
            if let day = event.knownDay {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = FestivalConfiguration.timeZone
                guard calendar.component(.year, from: day) == expectedFestivalYear else {
                    return .invalidEventDates(event.id)
                }
            }
        }

        if payload.missingSavedEventCount.map({ $0 < 0 }) == true {
            return .invalidPlanContract
        }

        let recommendedIDs = payload.recommendations.orderedEventIDs
        let recommendedIDSet = Set(recommendedIDs)
        let rankedEvents = payload.events.compactMap { event -> (Int, Int)? in
            event.recommendationRank.map { (event.id, $0) }
        }
        switch payload.recommendations.state {
        case .available:
            guard recommendedIDSet.count == recommendedIDs.count,
                  recommendedIDSet.isSubset(of: eventIDs),
                  rankedEvents.count == recommendedIDs.count,
                  rankedEvents.allSatisfy({ eventID, rank in
                      recommendedIDs.indices.contains(rank)
                          && recommendedIDs[rank] == eventID
                  })
            else {
                return .invalidRecommendationContract
            }
        case .loading, .failed, .unavailable:
            guard recommendedIDs.isEmpty, rankedEvents.isEmpty else {
                return .invalidRecommendationContract
            }
        }

        switch payload.friends.state {
        case .available:
            guard payload.events.allSatisfy({ event in
                event.friendSaveCount.map { $0 >= 0 } == true
            }) else {
                return .invalidFriendContract
            }
        case .loading, .failed, .unavailable:
            guard payload.events.allSatisfy({ $0.friendSaveCount == nil }) else {
                return .invalidFriendContract
            }
        }

        for transition in payload.planTransitions {
            guard eventIDs.contains(transition.fromEventID),
                  eventIDs.contains(transition.toEventID),
                  transition.fromEventID != transition.toEventID,
                  transition.walkingMinutes.map({ $0 >= 0 }) ?? true,
                  transition.projectedLatenessMinutes.map({ $0 >= 0 }) ?? true
            else {
                return .invalidTransitionReference
            }
        }

        for overlap in payload.planOverlaps {
            guard eventIDs.contains(overlap.firstEventID),
                  eventIDs.contains(overlap.secondEventID),
                  overlap.firstEventID != overlap.secondEventID,
                  overlap.overlapMinutes > 0
            else {
                return .invalidOverlapReference
            }
        }
        return nil
    }
}

enum WatchSnapshotStaleReason: String, Equatable, Sendable {
    case fallbackFestivalData
    case festivalDataAgeUnknown
    case festivalDataTooOld
    case recommendationsAgeUnknown
    case recommendationsTooOld
    case friendDataAgeUnknown
    case friendDataTooOld
    case snapshotTooOld
    case timestampInFuture
}

struct WatchSnapshotFreshnessPolicy: Equatable, Sendable {
    var maximumFestivalDataAge: TimeInterval = 3 * 60 * 60
    var maximumRecommendationAge: TimeInterval = 24 * 60 * 60
    var maximumFriendDataAge: TimeInterval = 24 * 60 * 60
    var maximumSnapshotAge: TimeInterval = 24 * 60 * 60
    var maximumClockSkew: TimeInterval = 5 * 60

    var core: PlanFreshnessPolicy {
        PlanFreshnessPolicy(
            maximumFestivalDataAge: maximumFestivalDataAge,
            maximumRecommendationAge: maximumRecommendationAge,
            maximumFriendDataAge: maximumFriendDataAge,
            maximumSnapshotAge: maximumSnapshotAge, maximumClockSkew: maximumClockSkew)
    }
    func staleReasons(for envelope: WatchSnapshotEnvelope, now: Date) -> [WatchSnapshotStaleReason]
    {
        core.staleReasons(
            input: envelope.coreFreshness, now: now.timeIntervalSince1970, scheduleOnly: false
        )
        .compactMap(WatchSnapshotStaleReason.init(rawValue:))
    }
    func eventScheduleStaleReasons(for envelope: WatchSnapshotEnvelope, now: Date)
        -> [WatchSnapshotStaleReason]
    {
        core.staleReasons(
            input: envelope.coreFreshness, now: now.timeIntervalSince1970, scheduleOnly: true
        )
        .compactMap(WatchSnapshotStaleReason.init(rawValue:))
    }
}

enum WatchSnapshotUnavailableReason: Equatable, Sendable {
    case noSnapshot
    case corruptStoredSnapshot
    case invalidIncomingSnapshot
    case incompatibleStoredSchema(received: Int, supported: Int)
    case wrongStoredFestivalYear(received: Int, expected: Int)
    case disallowedStoredEnvironment
    case readFailure
    case persistenceFailure
}

enum WatchSnapshotAvailability: Equatable, Sendable {
    case loading
    case unavailable(WatchSnapshotUnavailableReason)
    case available
    case stale([WatchSnapshotStaleReason])
}

enum WatchSnapshotImportDiagnostic: Equatable, Sendable {
    case payloadTooLarge
    case corrupt
    case incompatibleSchema(received: Int, supported: Int)
    case wrongFestivalYear(received: Int, expected: Int)
    case disallowedEnvironment
    case invalidPayload(WatchSnapshotPayloadIssue)
    case storageReadFailure
    case persistenceFailure
}

struct WatchSnapshotState: Equatable, Sendable {
    let snapshot: WatchSnapshotEnvelope?
    let availability: WatchSnapshotAvailability
    let importDiagnostic: WatchSnapshotImportDiagnostic?

    var isShowingRetainedSnapshotAfterFailedImport: Bool {
        guard snapshot != nil else {
            return false
        }
        switch importDiagnostic {
        case .payloadTooLarge, .corrupt, .invalidPayload, .storageReadFailure,
             .persistenceFailure:
            return true
        case .none, .incompatibleSchema, .wrongFestivalYear,
             .disallowedEnvironment:
            return false
        }
    }

    static let loading = WatchSnapshotState(
        snapshot: nil,
        availability: .loading,
        importDiagnostic: nil
    )
}

enum WatchSnapshotAcceptance: Equatable, Sendable {
    case stored(revision: UInt64)
    case ignored(WatchSnapshotRejection)
    case rejected(WatchSnapshotRejection)
    case storageUnavailable
    case persistenceFailed
}

protocol WatchSnapshotDataPersisting {
    func read() throws -> Data?
    func replaceAtomically(with data: Data) throws
}

struct FileWatchSnapshotPersistence: WatchSnapshotDataPersisting {
    let fileURL: URL
    var fileManager: FileManager = .default

    func read() throws -> Data? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try Data(contentsOf: fileURL)
    }

    func replaceAtomically(with data: Data) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

enum WatchSnapshotStorage {
    static let appGroupIdentifier = "group.de.leongeorgi.RudolstadtForiOS.watch"
    static let fileName = "confirmed-festival-snapshot-v1.lzfse"

    static func appGroupFileURL(
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )?.appendingPathComponent(fileName, isDirectory: false)
    }
}

enum WatchSnapshotStorageError: Error {
    case appGroupUnavailable
}

struct UnavailableWatchSnapshotPersistence: WatchSnapshotDataPersisting {
    func read() throws -> Data? {
        throw WatchSnapshotStorageError.appGroupUnavailable
    }

    func replaceAtomically(with data: Data) throws {
        throw WatchSnapshotStorageError.appGroupUnavailable
    }
}

actor WatchSnapshotRepository {
    private enum LoadDisposition: Equatable {
        case notLoaded
        case ready
        case readFailed
    }

    private let persistence: any WatchSnapshotDataPersisting
    private let validator: WatchSnapshotValidator
    private let freshnessPolicy: WatchSnapshotFreshnessPolicy
    private var state = WatchSnapshotState.loading
    private var loadDisposition = LoadDisposition.notLoaded
    private var storedRevisionFloor: UInt64?

    init(
        persistence: any WatchSnapshotDataPersisting,
        expectedFestivalYear: Int,
        freshnessPolicy: WatchSnapshotFreshnessPolicy = WatchSnapshotFreshnessPolicy()
    ) {
        self.persistence = persistence
        self.validator = WatchSnapshotValidator(
            expectedFestivalYear: expectedFestivalYear
        )
        self.freshnessPolicy = freshnessPolicy
    }

    static func live(expectedFestivalYear: Int) -> WatchSnapshotRepository {
        guard let fileURL = WatchSnapshotStorage.appGroupFileURL() else {
            return WatchSnapshotRepository(
                persistence: UnavailableWatchSnapshotPersistence(),
                expectedFestivalYear: expectedFestivalYear
            )
        }
        return WatchSnapshotRepository(
            persistence: FileWatchSnapshotPersistence(fileURL: fileURL),
            expectedFestivalYear: expectedFestivalYear
        )
    }

    @discardableResult
    func load(now: Date = .now) -> WatchSnapshotState {
        do {
            guard let data = try persistence.read() else {
                loadDisposition = .ready
                storedRevisionFloor = nil
                state = WatchSnapshotState(
                    snapshot: nil,
                    availability: .unavailable(.noSnapshot),
                    importDiagnostic: nil
                )
                return state
            }
            loadDisposition = .ready
            storedRevisionFloor = revisionFloor(in: data)
            switch validator.validate(data, currentRevision: nil) {
            case .accepted(let envelope):
                storedRevisionFloor = envelope.revision
                state = makeState(snapshot: envelope, now: now, diagnostic: nil)
            case .rejected(let rejection):
                state = WatchSnapshotState(
                    snapshot: nil,
                    availability: .unavailable(unavailableReason(for: rejection)),
                    importDiagnostic: diagnostic(for: rejection)
                )
            }
        } catch {
            loadDisposition = .readFailed
            state = stateAfterImportFailure(
                diagnostic: .storageReadFailure,
                fallbackAvailability: .unavailable(.readFailure)
            )
        }
        return state
    }

    @discardableResult
    func ensureLoaded(now: Date = .now) -> WatchSnapshotState {
        switch loadDisposition {
        case .notLoaded, .readFailed:
            return load(now: now)
        case .ready:
            return currentState(now: now)
        }
    }

    func currentState(now: Date = .now) -> WatchSnapshotState {
        guard let snapshot = state.snapshot else {
            return state
        }
        state = makeState(
            snapshot: snapshot,
            now: now,
            diagnostic: state.importDiagnostic
        )
        return state
    }

    func accept(
        _ data: Data,
        now: Date = .now
    ) -> WatchSnapshotAcceptance {
        if loadDisposition != .ready {
            _ = load(now: now)
        }
        guard loadDisposition == .ready else {
            state = stateAfterImportFailure(
                diagnostic: .storageReadFailure,
                fallbackAvailability: .unavailable(.readFailure)
            )
            return .storageUnavailable
        }

        let validation = validator.validate(
            data,
            currentRevision: maxRevision(
                state.snapshot?.revision,
                storedRevisionFloor
            )
        )
        switch validation {
        case .accepted(let envelope):
            do {
                try persistence.replaceAtomically(with: data)
                storedRevisionFloor = envelope.revision
                state = makeState(snapshot: envelope, now: now, diagnostic: nil)
                return .stored(revision: envelope.revision)
            } catch {
                state = stateAfterImportFailure(
                    diagnostic: .persistenceFailure,
                    fallbackAvailability: .unavailable(.persistenceFailure)
                )
                return .persistenceFailed
            }
        case .rejected(let rejection):
            switch rejection {
            case .duplicateRevision, .olderRevision:
                return .ignored(rejection)
            default:
                state = stateAfterImportFailure(
                    diagnostic: diagnostic(for: rejection),
                    fallbackAvailability: .unavailable(
                        incomingUnavailableReason(for: rejection)
                    )
                )
                return .rejected(rejection)
            }
        }
    }

    private func makeState(
        snapshot: WatchSnapshotEnvelope,
        now: Date,
        diagnostic: WatchSnapshotImportDiagnostic?
    ) -> WatchSnapshotState {
        let staleReasons = freshnessPolicy.staleReasons(for: snapshot, now: now)
        return WatchSnapshotState(
            snapshot: snapshot,
            availability: staleReasons.isEmpty ? .available : .stale(staleReasons),
            importDiagnostic: diagnostic
        )
    }

    private func stateAfterImportFailure(
        diagnostic: WatchSnapshotImportDiagnostic?,
        fallbackAvailability: WatchSnapshotAvailability
    ) -> WatchSnapshotState {
        WatchSnapshotState(
            snapshot: state.snapshot,
            availability: state.snapshot == nil ? fallbackAvailability : state.availability,
            importDiagnostic: diagnostic
        )
    }

    private func unavailableReason(
        for rejection: WatchSnapshotRejection
    ) -> WatchSnapshotUnavailableReason {
        switch rejection {
        case .incompatibleSchema(let received, let supported):
            return .incompatibleStoredSchema(
                received: received,
                supported: supported
            )
        case .wrongFestivalYear(let received, let expected):
            return .wrongStoredFestivalYear(received: received, expected: expected)
        case .disallowedEnvironment:
            return .disallowedStoredEnvironment
        case .payloadTooLarge, .corrupt, .invalidPayload, .duplicateRevision,
             .olderRevision:
            return .corruptStoredSnapshot
        }
    }

    private func incomingUnavailableReason(
        for rejection: WatchSnapshotRejection
    ) -> WatchSnapshotUnavailableReason {
        switch rejection {
        case .incompatibleSchema(let received, let supported):
            return .incompatibleStoredSchema(
                received: received,
                supported: supported
            )
        case .wrongFestivalYear(let received, let expected):
            return .wrongStoredFestivalYear(received: received, expected: expected)
        case .disallowedEnvironment:
            return .disallowedStoredEnvironment
        case .payloadTooLarge, .corrupt, .invalidPayload, .duplicateRevision,
             .olderRevision:
            return .invalidIncomingSnapshot
        }
    }

    private func revisionFloor(in data: Data) -> UInt64? {
        guard let header = try? WatchSnapshotCodec().decodeHeader(data),
              header.festivalYear == validator.expectedFestivalYear,
              header.environment == validator.expectedEnvironment.rawValue
        else {
            return nil
        }
        return header.revision
    }

    private func maxRevision(_ first: UInt64?, _ second: UInt64?) -> UInt64? {
        switch (first, second) {
        case (.some(let first), .some(let second)):
            return max(first, second)
        case (.some(let revision), .none), (.none, .some(let revision)):
            return revision
        case (.none, .none):
            return nil
        }
    }

    private func diagnostic(
        for rejection: WatchSnapshotRejection
    ) -> WatchSnapshotImportDiagnostic? {
        switch rejection {
        case .payloadTooLarge:
            return .payloadTooLarge
        case .corrupt:
            return .corrupt
        case .incompatibleSchema(let received, let supported):
            return .incompatibleSchema(received: received, supported: supported)
        case .wrongFestivalYear(let received, let expected):
            return .wrongFestivalYear(received: received, expected: expected)
        case .disallowedEnvironment:
            return .disallowedEnvironment
        case .invalidPayload(let issue):
            return .invalidPayload(issue)
        case .duplicateRevision, .olderRevision:
            return nil
        }
    }
}
