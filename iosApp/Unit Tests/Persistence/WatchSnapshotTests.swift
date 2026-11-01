import Foundation
import Testing
@testable import Rudolstadt

struct WatchSnapshotTests {
    @Test
    func codecRoundTripPreservesUnicodeAndDates() throws {
        let envelope = makeEnvelope(
            revision: 42,
            artistName: "Banda Ç, 東京"
        )

        let data = try WatchSnapshotCodec().encode(envelope)
        let decoded = try WatchSnapshotCodec().decode(data)

        #expect(decoded == envelope)
    }

    @Test
    func futureSchemaIsReportedBeforeFullPayloadDecoding() throws {
        let data = try compressedWireData(
            """
            {"schemaVersion":2,"festivalYear":2026,"revision":7,"environment":"production"}
            """
        )
        let validator = WatchSnapshotValidator(expectedFestivalYear: 2026)

        #expect(validator.validate(data, currentRevision: nil) == .rejected(
            .incompatibleSchema(received: 2, supported: 1)
        ))
    }

    @Test
    func wrongFestivalYearNeverReplacesConfirmedSnapshot() async throws {
        let codec = WatchSnapshotCodec()
        let initialData = try codec.encode(makeEnvelope(revision: 10))
        let persistence = InMemoryWatchSnapshotPersistence(data: initialData)
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        _ = await repository.load(now: referenceDate)
        let wrongYearData = try codec.encode(makeEnvelope(
            festivalYear: 2027,
            revision: 11
        ))

        let acceptance = await repository.accept(wrongYearData, now: referenceDate)
        let state = await repository.currentState(now: referenceDate)

        #expect(acceptance == .rejected(
            .wrongFestivalYear(received: 2027, expected: 2026)
        ))
        #expect(state.snapshot?.revision == 10)
        #expect(persistence.data == initialData)
        #expect(state.importDiagnostic == .wrongFestivalYear(
            received: 2027,
            expected: 2026
        ))
    }

    @Test
    func truncatedTransferNeverReplacesConfirmedSnapshot() async throws {
        let codec = WatchSnapshotCodec()
        let initialData = try codec.encode(makeEnvelope(revision: 10))
        let persistence = InMemoryWatchSnapshotPersistence(data: initialData)
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        _ = await repository.load(now: referenceDate)

        let acceptance = await repository.accept(
            Data("{\"schemaVersion\":".utf8),
            now: referenceDate
        )
        let state = await repository.currentState(now: referenceDate)

        #expect(acceptance == .rejected(.corrupt))
        #expect(state.snapshot?.revision == 10)
        #expect(persistence.data == initialData)
        #expect(state.isShowingRetainedSnapshotAfterFailedImport)
    }

    @Test
    func invalidFirstTransferIsNotReportedAsStoredDataCorruption() async {
        let repository = WatchSnapshotRepository(
            persistence: InMemoryWatchSnapshotPersistence(),
            expectedFestivalYear: 2026
        )

        let acceptance = await repository.accept(Data("truncated".utf8))
        let state = await repository.currentState()

        #expect(acceptance == .rejected(.corrupt))
        #expect(state.availability == .unavailable(.invalidIncomingSnapshot))
        #expect(state.importDiagnostic == .corrupt)
        #expect(!state.isShowingRetainedSnapshotAfterFailedImport)
    }

    @Test
    func ensuringLoadedAgainPreservesTheLatestImportDiagnostic() async throws {
        let codec = WatchSnapshotCodec()
        let persistence = InMemoryWatchSnapshotPersistence(
            data: try codec.encode(makeEnvelope(revision: 10))
        )
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        _ = await repository.ensureLoaded(now: referenceDate)
        _ = await repository.accept(Data("truncated".utf8), now: referenceDate)

        let state = await repository.ensureLoaded(now: referenceDate)

        #expect(state.snapshot?.revision == 10)
        #expect(state.importDiagnostic == .corrupt)
        #expect(state.isShowingRetainedSnapshotAfterFailedImport)
    }

    @Test
    func duplicateAndOlderRevisionsAreIdempotentlyIgnored() async throws {
        let codec = WatchSnapshotCodec()
        let initialData = try codec.encode(makeEnvelope(revision: 10))
        let persistence = InMemoryWatchSnapshotPersistence(data: initialData)
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        _ = await repository.load(now: referenceDate)

        let duplicate = await repository.accept(initialData, now: referenceDate)
        let older = await repository.accept(
            try codec.encode(makeEnvelope(revision: 9)),
            now: referenceDate
        )

        #expect(duplicate == .ignored(.duplicateRevision(10)))
        #expect(older == .ignored(.olderRevision(received: 9, current: 10)))
        #expect(persistence.writeCount == 0)
    }

    @Test
    func persistenceFailureRetainsConfirmedSnapshot() async throws {
        let codec = WatchSnapshotCodec()
        let initialData = try codec.encode(makeEnvelope(revision: 10))
        let persistence = InMemoryWatchSnapshotPersistence(
            data: initialData,
            failWrites: true
        )
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        _ = await repository.load(now: referenceDate)

        let acceptance = await repository.accept(
            try codec.encode(makeEnvelope(revision: 11)),
            now: referenceDate
        )
        let state = await repository.currentState(now: referenceDate)

        #expect(acceptance == .persistenceFailed)
        #expect(state.snapshot?.revision == 10)
        #expect(state.importDiagnostic == .persistenceFailure)
        #expect(persistence.data == initialData)
    }

    @Test
    func readFailureNeverAllowsAnUnknownRevisionToBeReplaced() async throws {
        let codec = WatchSnapshotCodec()
        let initialData = try codec.encode(makeEnvelope(revision: 10))
        let persistence = InMemoryWatchSnapshotPersistence(
            data: initialData,
            failReads: true
        )
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        let olderData = try codec.encode(makeEnvelope(revision: 9))

        let acceptance = await repository.accept(olderData, now: referenceDate)
        let state = await repository.currentState(now: referenceDate)

        #expect(acceptance == .storageUnavailable)
        #expect(persistence.writeCount == 0)
        #expect(persistence.data == initialData)
        #expect(state.availability == .unavailable(.readFailure))
        #expect(state.importDiagnostic == .storageReadFailure)
    }

    @Test
    func independentAppAndWidgetReadersSeeSameFileRevision() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("snapshot.json")
        let persistence = FileWatchSnapshotPersistence(fileURL: fileURL)
        let writer = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        let appReader = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        let widgetReader = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        let data = try WatchSnapshotCodec().encode(makeEnvelope(revision: 99))

        let acceptance = await writer.accept(data, now: referenceDate)
        #expect(acceptance == .stored(revision: 99))
        let appState = await appReader.load(now: referenceDate)
        let widgetState = await widgetReader.load(now: referenceDate)

        #expect(appState.snapshot?.revision == 99)
        #expect(widgetState.snapshot?.revision == appState.snapshot?.revision)
    }

    @Test
    func fallbackSourceRemainsUsableButExplicitlyStale() async throws {
        let envelope = makeEnvelope(
            revision: 1,
            festivalDataSource: .bundledBackup
        )
        let persistence = InMemoryWatchSnapshotPersistence(
            data: try WatchSnapshotCodec().encode(envelope)
        )
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )

        let state = await repository.load(now: referenceDate)

        #expect(state.snapshot?.revision == 1)
        #expect(state.availability == .stale([.fallbackFestivalData]))
    }

    @Test
    func oldRecommendationsMakeAnOtherwiseCurrentSnapshotStale() async throws {
        let oldRecommendationDate = referenceDate.addingTimeInterval(-2 * 24 * 60 * 60)
        let persistence = InMemoryWatchSnapshotPersistence(
            data: try WatchSnapshotCodec().encode(makeEnvelope(
                revision: 1,
                recommendationGeneratedAt: oldRecommendationDate
            ))
        )
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )

        let state = await repository.load(now: referenceDate)

        #expect(state.availability == .stale([.recommendationsTooOld]))
    }

    @Test
    func productionRepositoryRejectsPreviewData() async throws {
        let persistence = InMemoryWatchSnapshotPersistence()
        let repository = WatchSnapshotRepository(
            persistence: persistence,
            expectedFestivalYear: 2026
        )
        let data = try WatchSnapshotCodec().encode(makeEnvelope(
            revision: 1,
            environment: .preview
        ))

        let acceptance = await repository.accept(data, now: referenceDate)

        #expect(acceptance == .rejected(.disallowedEnvironment("preview")))
        #expect(persistence.data == nil)
    }

    @Test
    func versionOneGoldenPayloadStillDecodes() throws {
        let data = try compressedWireData(
            """
            {
              "environment":"production",
              "festivalYear":2026,
              "freshness":{"festivalDataSource":"remote"},
              "generatedAt":1782998400000,
              "payload":{
                "events":[],
                "friends":{"state":"unavailable"},
                "planOverlaps":[],
                "planTransitions":[],
                "recommendations":{"orderedEventIDs":[],"state":"unavailable"}
              },
              "revision":5,
              "schemaVersion":1
            }
            """
        )

        let envelope = try WatchSnapshotCodec().decode(data)

        #expect(envelope.schemaVersion == 1)
        #expect(envelope.festivalYear == 2026)
        #expect(envelope.revision == 5)
        #expect(envelope.generatedAt == referenceDate)
        #expect(envelope.payload.events.isEmpty)
        #expect(envelope.payload.missingSavedEventCount == nil)
    }

    @Test
    func builderSkipsChangedInvalidReferencesWithoutCrashing() throws {
        let stage = TestFixtures.stage(
            id: 9_001,
            stageNumber: nil,
            germanName: "Neue Bühne",
            englishName: "New Stage"
        )
        let validEvent = TestFixtures.event(
            id: 101,
            dayInJuly: 3,
            timeAsString: "20:15",
            stage: stage,
            artist: TestFixtures.artist(id: 201)
        )
        let invalidEvent = TestFixtures.event(
            id: 102,
            dayInJuly: 3,
            timeAsString: "TBA",
            stage: stage,
            artist: TestFixtures.artist(id: 202)
        )
        let oldFriendProfile = TestFixtures.sharedFestivalProfile(
            savedEventIDs: [validEvent.id], festivalYear: 2025
        )
        let evaluator = ScheduleTransitionEvaluator(
            transferEstimator: StageTransferEstimator(
                stages: [stage],
                matrix: .empty
            ),
            calendar: TestFixtures.festivalCalendar
        )

        let result = WatchSnapshotBuilder().build(WatchSnapshotBuildInput(
            festivalYear: 2026,
            revision: 7,
            generatedAt: referenceDate,
            environment: .production,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: .remote,
                festivalDataUpdatedAt: referenceDate,
                refreshCheckedAt: referenceDate,
                profileCloudRefreshedAt: referenceDate,
                recommendationsGeneratedAt: referenceDate
            ),
            events: [validEvent, invalidEvent, validEvent],
            savedEventIDs: [validEvent.id, invalidEvent.id, 404],
            ratingsByArtistID: [:],
            estimatedDurationsByEventID: [validEvent.id: -5],
            recommendations: WatchRecommendationSnapshot(
                state: .available,
                generatedAt: referenceDate,
                orderedEventIDs: [404, validEvent.id]
            ),
            friends: WatchFriendSnapshot(
                state: .available,
                updatedAt: referenceDate
            ),
            friendProfiles: [oldFriendProfile],
            transitionEvaluator: evaluator
        ))

        #expect(result.envelope.payload.events.map(\.id) == [validEvent.id])
        #expect(result.envelope.payload.events.first?.stageID == stage.id.numericValue)
        #expect(result.envelope.payload.events.first?.stageNameGerman == "Neue Bühne")
        #expect(result.envelope.payload.recommendations.orderedEventIDs == [validEvent.id])
        #expect(result.envelope.payload.events.first?.friendSaveCount == 0)
        #expect(result.envelope.payload.missingSavedEventCount == 2)
        #expect(result.envelope.payload.unplacedSavedEvents?.map(\.id) == [invalidEvent.id])
        #expect(result.envelope.payload.unplacedSavedEvents?.first?.knownDay != nil)
        #expect(result.diagnostics.contains(.invalidEventDate(invalidEvent.id)))
        #expect(result.diagnostics.contains(.duplicateEventID(validEvent.id)))
        #expect(result.diagnostics.contains(.missingSavedEventID(invalidEvent.id)))
        #expect(result.diagnostics.contains(.missingSavedEventID(404)))
        #expect(result.diagnostics.contains(.missingRecommendedEventID(404)))
        #expect(result.diagnostics.contains(.ignoredFriendProfileFromFestivalYear(2025)))
        #expect(result.diagnostics.contains(.invalidDuration(eventID: validEvent.id)))

        let data = try WatchSnapshotCodec().encode(result.envelope)
        #expect(WatchSnapshotValidator(expectedFestivalYear: 2026).validate(
            data,
            currentRevision: nil
        ) == .accepted(result.envelope))
    }

    @Test
    func builderNormalizesAcceptedEventTimesBeforeCalculatingPlanFacts() throws {
        let stage = TestFixtures.stage(id: 301)
        let firstEvent = TestFixtures.event(
            id: 101,
            dayInJuly: 3,
            timeAsString: " 20:15 ",
            stage: stage,
            artist: TestFixtures.artist(id: 201)
        )
        let secondEvent = TestFixtures.event(
            id: 102,
            dayInJuly: 3,
            timeAsString: "20:30",
            stage: stage,
            artist: TestFixtures.artist(id: 202)
        )
        let result = WatchSnapshotBuilder().build(WatchSnapshotBuildInput(
            festivalYear: 2026,
            revision: 8,
            generatedAt: referenceDate,
            environment: .production,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: .remote,
                festivalDataUpdatedAt: referenceDate,
                refreshCheckedAt: referenceDate,
                profileCloudRefreshedAt: nil,
                recommendationsGeneratedAt: nil
            ),
            events: [secondEvent, firstEvent],
            savedEventIDs: [firstEvent.id, secondEvent.id],
            ratingsByArtistID: [:],
            estimatedDurationsByEventID: [firstEvent.id: 60, secondEvent.id: 60],
            recommendations: WatchRecommendationSnapshot(
                state: .unavailable,
                generatedAt: nil,
                orderedEventIDs: []
            ),
            friends: WatchFriendSnapshot(state: .unavailable, updatedAt: nil),
            friendProfiles: [],
            transitionEvaluator: ScheduleTransitionEvaluator(
                transferEstimator: StageTransferEstimator(
                    stages: [stage],
                    matrix: .empty
                ),
                calendar: TestFixtures.festivalCalendar
            )
        ))

        #expect(result.envelope.payload.events.map(\.id) == [101, 102])
        #expect(result.envelope.payload.events.first?.startDate == TestFixtures.date(
            dayInJuly: 3,
            hour: 20,
            minute: 15
        ))
        #expect(result.envelope.payload.planTransitions.isEmpty)
        #expect(result.envelope.payload.planOverlaps == [WatchPlanOverlapSnapshot(
            firstEventID: 101,
            secondEventID: 102,
            overlapMinutes: 45
        )])
    }

    @Test
    func builderUsesWorstTransitionFromOverlappingAlternatives() throws {
        let distantStage = TestFixtures.stage(id: 301)
        let targetStage = TestFixtures.stage(id: 302)
        let sourceStageID = try #require(distantStage.id.numericValue)
        let destinationStageID = try #require(targetStage.id.numericValue)
        let firstAlternative = TestFixtures.event(
            id: 101,
            dayInJuly: 3,
            timeAsString: "20:00",
            stage: distantStage,
            artist: TestFixtures.artist(id: 201)
        )
        let secondAlternative = TestFixtures.event(
            id: 102,
            dayInJuly: 3,
            timeAsString: "20:00",
            stage: targetStage,
            artist: TestFixtures.artist(id: 202)
        )
        let nextEvent = TestFixtures.event(
            id: 103,
            dayInJuly: 3,
            timeAsString: "21:05",
            stage: targetStage,
            artist: TestFixtures.artist(id: 203)
        )
        let result = WatchSnapshotBuilder().build(WatchSnapshotBuildInput(
            festivalYear: 2026,
            revision: 9,
            generatedAt: referenceDate,
            environment: .production,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: .remote,
                festivalDataUpdatedAt: referenceDate,
                refreshCheckedAt: referenceDate,
                profileCloudRefreshedAt: nil,
                recommendationsGeneratedAt: nil
            ),
            events: [nextEvent, secondAlternative, firstAlternative],
            savedEventIDs: [
                firstAlternative.id,
                secondAlternative.id,
                nextEvent.id
            ],
            ratingsByArtistID: [:],
            estimatedDurationsByEventID: [
                firstAlternative.id: 60,
                secondAlternative.id: 60,
                nextEvent.id: 60
            ],
            recommendations: WatchRecommendationSnapshot(
                state: .unavailable,
                generatedAt: nil,
                orderedEventIDs: []
            ),
            friends: WatchFriendSnapshot(state: .unavailable, updatedAt: nil),
            friendProfiles: [],
            transitionEvaluator: ScheduleTransitionEvaluator(
                transferEstimator: StageTransferEstimator(
                    stages: [distantStage, targetStage],
                    matrix: StageWalkingDistanceMatrix(distancesByStageID: [
                        sourceStageID: [destinationStageID: 2_000]
                    ])
                ),
                calendar: TestFixtures.festivalCalendar
            )
        ))

        #expect(result.envelope.payload.planTransitions == [
            WatchPlanTransitionSnapshot(
                fromEventID: firstAlternative.id,
                toEventID: nextEvent.id,
                status: .impossible,
                walkingMinutes: 25,
                projectedLatenessMinutes: 20,
                certainty: .known
            )
        ])
        #expect(result.envelope.payload.planOverlaps == [
            WatchPlanOverlapSnapshot(
                firstEventID: firstAlternative.id,
                secondEventID: secondAlternative.id,
                overlapMinutes: 60
            )
        ])
    }

    @Test
    func importPipelineRunsRepositoryAndUIOperationsInEnqueueOrder() async {
        let pipeline = WatchSnapshotImportPipeline()
        let recorder = WatchImportRecorder()

        pipeline.enqueue {
            try? await Task.sleep(for: .milliseconds(50))
            await recorder.append(1)
        }
        pipeline.enqueue {
            await recorder.append(2)
        }

        await pipeline.drain()

        let values = await recorder.snapshot()
        #expect(values == [1, 2])
    }

    @Test
    func cancellingOneOverlappingDrainKeepsOtherDrainWorkAlive() async {
        let pipeline = WatchSnapshotImportPipeline()
        let recorder = WatchImportRecorder()
        let firstLease = pipeline.beginDrain()
        let secondLease = pipeline.beginDrain()
        pipeline.enqueue {
            do {
                try await Task.sleep(for: .milliseconds(50))
                await recorder.append(1)
            } catch {
                return
            }
        }

        pipeline.endDrain(firstLease, cancelled: true)
        let acceptedSecondOperation = pipeline.enqueue {
            await recorder.append(2)
        }
        await pipeline.drain()
        pipeline.endDrain(secondLease, cancelled: false)

        let values = await recorder.snapshot()
        #expect(acceptedSecondOperation)
        #expect(values == [1, 2])
    }

    @Test
    func productionTransportRejectsNonProductionRuntimes() {
        #expect(WatchSnapshotTransportRuntime.isEnabled(
            environment: [:],
            screenshotModeEnabled: false
        ))
        #expect(!WatchSnapshotTransportRuntime.isEnabled(
            environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"],
            screenshotModeEnabled: false
        ))
        #expect(!WatchSnapshotTransportRuntime.isEnabled(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"],
            screenshotModeEnabled: false
        ))
        #expect(!WatchSnapshotTransportRuntime.isEnabled(
            environment: [:],
            screenshotModeEnabled: true
        ))
    }

    @Test @MainActor
    func bundledFestivalSnapshotFitsApplicationContextBudget() throws {
        let extraData = try #require(loadExtraDataFromResource(fileName: "extra_data"))
        let loader = DataLoader(cacheURL: FileManager.default.temporaryDirectory)
        let festivalData: FestivalData
        switch loader.loadBundledFestivalDataBackup(extraData: extraData) {
        case .loaded(let data), .stale(let data):
            festivalData = data
        case .notFound, .unparsable:
            Issue.record("Could not load the bundled festival snapshot fixture")
            return
        }
        let result = WatchSnapshotBuilder().build(WatchSnapshotBuildInput(
            festivalYear: DataStore.year,
            revision: 1,
            generatedAt: referenceDate,
            environment: .production,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: .bundledBackup,
                festivalDataUpdatedAt: nil,
                refreshCheckedAt: referenceDate,
                profileCloudRefreshedAt: nil,
                recommendationsGeneratedAt: nil
            ),
            events: festivalData.events,
            savedEventIDs: [],
            ratingsByArtistID: [:],
            estimatedDurationsByEventID: [:],
            recommendations: WatchRecommendationSnapshot(
                state: .unavailable,
                generatedAt: nil,
                orderedEventIDs: []
            ),
            friends: WatchFriendSnapshot(state: .unavailable, updatedAt: nil),
            friendProfiles: [],
            transitionEvaluator: ScheduleTransitionEvaluator(
                transferEstimator: StageTransferEstimator(
                    stages: festivalData.stages,
                    matrix: .empty
                ),
                calendar: TestFixtures.festivalCalendar
            )
        ))

        let data = try WatchSnapshotCodec().encode(result.envelope)

        #expect(data.count <= WatchSnapshotCodec.defaultMaximumEncodedByteCount)
        #expect(result.envelope.payload.events.count == festivalData.events.count)
    }

    @Test
    func revisionGeneratorStaysMonotonicWhenClockMovesBackwards() {
        let suiteName = "WatchSnapshotRevisionGeneratorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var now = Date(timeIntervalSince1970: 2_000)
        let generator = WatchSnapshotRevisionGenerator(
            userDefaults: defaults,
            festivalYear: 2026,
            now: { now }
        )

        let first = generator.next()
        now = Date(timeIntervalSince1970: 1_000)
        let second = generator.next()

        #expect(second == first + 1)
    }

    @Test
    func nextEventTimelineSwitchesOnlyAtKnownSemanticBoundaries() {
        let savedEvent = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(60 * 60),
            endDate: referenceDate.addingTimeInterval(2 * 60 * 60)
        )
        let laterProgramEvent = makeTimelineEvent(
            id: 2,
            startDate: referenceDate.addingTimeInterval(3 * 60 * 60),
            endDate: referenceDate.addingTimeInterval(4 * 60 * 60),
            isSaved: false
        )
        let state = makeTimelineState(events: [laterProgramEvent, savedEvent])

        let projection = distantFreshnessProjector.project(
            state: state,
            now: referenceDate
        )

        #expect(projection.entries.map(\.content) == [
            .event(savedEvent, phase: .upcoming),
            .event(savedEvent, phase: .ongoing),
            .planEnded,
            .festivalEnded,
        ])
        #expect(projection.entries.map(\.date) == [
            referenceDate,
            savedEvent.startDate,
            savedEvent.endDate,
            laterProgramEvent.endDate,
        ])
        #expect(!projection.reloadAtEnd)
    }

    @Test
    func overlappingEventDoesNotFallBackToAnEarlierStillRunningEvent() {
        let longEvent = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(-30 * 60),
            endDate: referenceDate.addingTimeInterval(2 * 60 * 60)
        )
        let laterEvent = makeTimelineEvent(
            id: 2,
            startDate: referenceDate.addingTimeInterval(30 * 60),
            endDate: referenceDate.addingTimeInterval(60 * 60)
        )
        let futureProgramEvent = makeTimelineEvent(
            id: 3,
            startDate: referenceDate.addingTimeInterval(3 * 60 * 60),
            endDate: referenceDate.addingTimeInterval(4 * 60 * 60),
            isSaved: false
        )
        let state = makeTimelineState(
            events: [longEvent, laterEvent, futureProgramEvent]
        )

        #expect(distantFreshnessProjector.entry(
            for: state,
            at: referenceDate
        ).content == .event(longEvent, phase: .ongoing))
        #expect(distantFreshnessProjector.entry(
            for: state,
            at: laterEvent.startDate
        ).content == .event(laterEvent, phase: .ongoing))
        #expect(distantFreshnessProjector.entry(
            for: state,
            at: laterEvent.endDate
        ).content == .planEnded)
    }

    @Test
    func simultaneousStartsPreferLongestEventThenStableID() {
        let shorterEvent = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(60 * 60),
            endDate: referenceDate.addingTimeInterval(2 * 60 * 60)
        )
        let higherID = makeTimelineEvent(
            id: 3,
            startDate: shorterEvent.startDate,
            endDate: referenceDate.addingTimeInterval(3 * 60 * 60)
        )
        let lowerID = makeTimelineEvent(
            id: 2,
            startDate: shorterEvent.startDate,
            endDate: higherID.endDate
        )
        let state = makeTimelineState(
            events: [shorterEvent, higherID, lowerID]
        )

        let entry = distantFreshnessProjector.entry(
            for: state,
            at: shorterEvent.startDate
        )

        #expect(entry.content == .event(lowerID, phase: .ongoing))
    }

    @Test
    func emptyPlanStatesDoNotClaimTheFestivalEndedTooEarly() {
        let pastSavedEvent = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(-2 * 60 * 60),
            endDate: referenceDate.addingTimeInterval(-60 * 60)
        )
        let futureProgramEvent = makeTimelineEvent(
            id: 2,
            startDate: referenceDate.addingTimeInterval(60 * 60),
            endDate: referenceDate.addingTimeInterval(2 * 60 * 60),
            isSaved: false
        )

        #expect(distantFreshnessProjector.entry(
            for: makeTimelineState(events: []),
            at: referenceDate
        ).content == .programUnavailable)
        #expect(distantFreshnessProjector.entry(
            for: makeTimelineState(events: [futureProgramEvent]),
            at: referenceDate
        ).content == .noSavedEvents)
        #expect(distantFreshnessProjector.entry(
            for: makeTimelineState(events: [pastSavedEvent, futureProgramEvent]),
            at: referenceDate
        ).content == .planEnded)
        #expect(distantFreshnessProjector.entry(
            for: makeTimelineState(events: [pastSavedEvent]),
            at: referenceDate
        ).content == .festivalEnded)
    }

    @Test
    func unconfirmedEmptyPlanNeverLooksLikeAConfirmedEmptyPlan() {
        let futureProgramEvent = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(60 * 60),
            endDate: referenceDate.addingTimeInterval(2 * 60 * 60),
            isSaved: false
        )
        let state = makeTimelineState(
            events: [futureProgramEvent],
            missingSavedEventCount: nil
        )

        let widgetEntry = distantFreshnessProjector.entry(
            for: state,
            at: referenceDate
        )
        let dayPlan = distantDayPlanProjector.project(
            state: state,
            at: referenceDate
        )

        #expect(widgetEntry.content == .planUnavailable)
        #expect(widgetEntry.planCompleteness == .unknown)
        #expect(dayPlan.content == .planUnavailable)
        #expect(dayPlan.planCompleteness == .unknown)
    }

    @Test
    func widgetCarriesIncompletePlanStatusAlongsideKnownNextEvent() {
        let event = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(60 * 60),
            endDate: referenceDate.addingTimeInterval(2 * 60 * 60)
        )

        let entry = distantFreshnessProjector.entry(
            for: makeTimelineState(
                events: [event],
                missingSavedEventCount: 2
            ),
            at: referenceDate
        )

        #expect(entry.content == .event(event, phase: .upcoming))
        #expect(entry.planCompleteness == .incomplete(missingSavedEventCount: 2))
    }

    @Test
    func unavailableStateNeverLeaksAResidualSnapshotIntoTheWidget() {
        let event = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(60 * 60),
            endDate: referenceDate.addingTimeInterval(2 * 60 * 60)
        )
        let availableState = makeTimelineState(events: [event])
        let unavailableState = WatchSnapshotState(
            snapshot: availableState.snapshot,
            availability: .unavailable(.wrongStoredFestivalYear(
                received: 2027,
                expected: 2026
            )),
            importDiagnostic: nil
        )

        let projection = distantFreshnessProjector.project(
            state: unavailableState,
            now: referenceDate
        )

        #expect(projection.entries.map(\.content) == [
            .unavailable(.wrongStoredFestivalYear(
                received: 2027,
                expected: 2026
            )),
        ])
    }

    @Test
    func freshEventStaysVisibleWhenItsSnapshotBecomesStale() {
        let event = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(2 * 60 * 60),
            endDate: referenceDate.addingTimeInterval(4 * 60 * 60)
        )
        let policy = WatchSnapshotFreshnessPolicy(
            maximumFestivalDataAge: 60 * 60,
            maximumRecommendationAge: 24 * 60 * 60,
            maximumFriendDataAge: 24 * 60 * 60,
            maximumSnapshotAge: 24 * 60 * 60,
            maximumClockSkew: 5 * 60
        )

        let projection = WatchNextEventTimelineProjector(
            freshnessPolicy: policy
        ).project(
            state: makeTimelineState(events: [event]),
            now: referenceDate
        )

        #expect(projection.entries.first?.content == .event(
            event,
            phase: .upcoming
        ))
        #expect(projection.entries.first?.isStale == false)
        let staleEntry = projection.entries.first { $0.isStale }
        #expect(staleEntry?.date == referenceDate.addingTimeInterval(60 * 60 + 1))
        #expect(staleEntry?.content == .event(event, phase: .upcoming))
    }

    @Test
    func unrelatedRecommendationAndFriendAgesDoNotStaleNextEvent() {
        let event = makeTimelineEvent(
            id: 1,
            startDate: referenceDate.addingTimeInterval(2 * 60 * 60),
            endDate: referenceDate.addingTimeInterval(4 * 60 * 60),
            friendSaveCount: 0
        )
        let oldDate = referenceDate.addingTimeInterval(-2 * 24 * 60 * 60)
        let snapshot = WatchSnapshotEnvelope(
            schemaVersion: WatchSnapshotEnvelope.currentSchemaVersion,
            festivalYear: 2026,
            revision: 1,
            generatedAt: referenceDate,
            environment: .production,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: .remote,
                festivalDataUpdatedAt: referenceDate,
                refreshCheckedAt: referenceDate,
                profileCloudRefreshedAt: oldDate,
                recommendationsGeneratedAt: oldDate
            ),
            payload: WatchFestivalSnapshot(
                events: [event],
                recommendations: WatchRecommendationSnapshot(
                    state: .available,
                    generatedAt: oldDate,
                    orderedEventIDs: []
                ),
                friends: WatchFriendSnapshot(
                    state: .available,
                    updatedAt: oldDate
                ),
                planTransitions: [],
                planOverlaps: []
            )
        )
        let state = WatchSnapshotState(
            snapshot: snapshot,
            availability: .stale([
                .recommendationsTooOld,
                .friendDataTooOld,
            ]),
            importDiagnostic: nil
        )

        let entry = WatchNextEventTimelineProjector().entry(
            for: state,
            at: referenceDate
        )

        #expect(entry.content == .event(event, phase: .upcoming))
        #expect(!entry.isStale)
    }

    @Test
    func longPlansAreChunkedInsteadOfProducingUnboundedTimelines() {
        let events = (0..<4).map { index in
            makeTimelineEvent(
                id: index,
                startDate: referenceDate.addingTimeInterval(
                    TimeInterval(index * 2 + 1) * 60 * 60
                ),
                endDate: referenceDate.addingTimeInterval(
                    TimeInterval(index * 2 + 2) * 60 * 60
                )
            )
        }

        let projection = WatchNextEventTimelineProjector(
            freshnessPolicy: distantFreshnessPolicy,
            maximumEntryCount: 3
        ).project(
            state: makeTimelineState(events: events),
            now: referenceDate
        )

        #expect(projection.entries.count == 3)
        #expect(projection.reloadAtEnd)
    }

    @Test
    func eventDeepLinksCarryFestivalYearAndRejectOtherRoutes() throws {
        let url = try #require(WatchDeepLink.eventURL(
            festivalYear: 2026,
            eventID: 101
        ))

        #expect(WatchDeepLink.event(from: url) == WatchEventDeepLink(
            festivalYear: 2026,
            eventID: 101
        ))
        let incompleteURL = try #require(URL(
            string: "rudolstadt-watch://event/2026"
        ))
        let wrongSchemeURL = try #require(URL(
            string: "https://event/2026/101"
        ))
        #expect(WatchDeepLink.event(from: incompleteURL) == nil)
        #expect(WatchDeepLink.event(from: wrongSchemeURL) == nil)
    }

    @Test
    func localizedStageNameFallsBackWhenFestivalDataOmitsOneLanguage() {
        let event = WatchEventSnapshot(
            id: 1,
            artistID: 2,
            artistName: "Artist",
            stageID: 3,
            stageNumber: nil,
            stageNameGerman: "  Bühne  ",
            stageNameEnglish: "   ",
            festivalDay: 3,
            startDate: referenceDate,
            endDate: referenceDate.addingTimeInterval(60 * 60),
            isSaved: true,
            hasPositiveRating: false,
            recommendationRank: nil,
            friendSaveCount: nil
        )

        #expect(event.localizedStageName(
            locale: Locale(identifier: "de_DE")
        ) == "Bühne")
        #expect(event.localizedStageName(
            locale: Locale(identifier: "en_US")
        ) == "Bühne")
    }

    @Test
    func dayPlanUsesTheBerlinFiveAMFestivalBoundary() throws {
        let earlyMorningEvent = makeTimelineEvent(
            id: 1,
            startDate: TestFixtures.date(dayInJuly: 4, hour: 1, minute: 30),
            endDate: TestFixtures.date(dayInJuly: 4, hour: 2, minute: 30),
            festivalDay: 3
        )
        let eveningEvent = makeTimelineEvent(
            id: 2,
            startDate: TestFixtures.date(dayInJuly: 4, hour: 20, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 4, hour: 21, minute: 0),
            festivalDay: 4
        )
        let state = makeTimelineState(events: [eveningEvent, earlyMorningEvent])

        let beforeBoundary = distantDayPlanProjector.project(
            state: state,
            at: TestFixtures.date(dayInJuly: 4, hour: 2, minute: 0)
        )
        let afterBoundary = distantDayPlanProjector.project(
            state: state,
            at: TestFixtures.date(dayInJuly: 4, hour: 5, minute: 0)
        )

        let earlyPlan = try #require(beforeBoundary.content.plan)
        #expect(earlyPlan.festivalDay == 3)
        #expect(earlyPlan.ongoingEvents.map(\.id) == [earlyMorningEvent.id])
        let eveningPlan = try #require(afterBoundary.content.plan)
        #expect(eveningPlan.festivalDay == 4)
        #expect(eveningPlan.upcomingEvents.map(\.id) == [eveningEvent.id])
    }

    @Test
    func dayPlanKeepsAllSimultaneousEventsAndExistingPlanFacts() throws {
        let now = TestFixtures.date(dayInJuly: 3, hour: 20, minute: 0)
        let firstOngoing = makeTimelineEvent(
            id: 1,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 19, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 21, minute: 0)
        )
        let secondOngoing = makeTimelineEvent(
            id: 2,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 19, minute: 30),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 20, minute: 30)
        )
        let upcoming = makeTimelineEvent(
            id: 3,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 21, minute: 15),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 22, minute: 15)
        )
        let otherDay = makeTimelineEvent(
            id: 4,
            startDate: TestFixtures.date(dayInJuly: 4, hour: 20, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 4, hour: 21, minute: 0),
            festivalDay: 4
        )
        let transition = WatchPlanTransitionSnapshot(
            fromEventID: secondOngoing.id,
            toEventID: upcoming.id,
            status: .tight,
            walkingMinutes: 8,
            projectedLatenessMinutes: nil,
            certainty: .estimated
        )
        let state = makeTimelineState(
            events: [otherDay, upcoming, secondOngoing, firstOngoing],
            planTransitions: [transition],
            planOverlaps: [WatchPlanOverlapSnapshot(
                firstEventID: firstOngoing.id,
                secondEventID: secondOngoing.id,
                overlapMinutes: 30
            )]
        )

        let projection = distantDayPlanProjector.project(state: state, at: now)
        let plan = try #require(projection.content.plan)

        #expect(plan.ongoingEvents.map(\.id) == [1, 2])
        #expect(plan.upcomingEvents.map(\.id) == [3])
        #expect(plan.ongoingEvents.map(\.conflictMinutes) == [30, 30])
        #expect(plan.upcomingEvents.first?.incomingTransition == transition)
    }

    @Test
    func dayPlanKeepsARelevantTransitionFromAJustEndedEvent() throws {
        let previous = makeTimelineEvent(
            id: 1,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 19, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 20, minute: 0)
        )
        let upcoming = makeTimelineEvent(
            id: 2,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 20, minute: 10),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 21, minute: 10)
        )
        let transition = WatchPlanTransitionSnapshot(
            fromEventID: previous.id,
            toEventID: upcoming.id,
            status: .tight,
            walkingMinutes: 12,
            projectedLatenessMinutes: nil,
            certainty: .known
        )
        let state = makeTimelineState(
            events: [previous, upcoming],
            planTransitions: [transition]
        )

        let projection = distantDayPlanProjector.project(
            state: state,
            at: TestFixtures.date(dayInJuly: 3, hour: 20, minute: 1)
        )
        let plan = try #require(projection.content.plan)

        #expect(plan.ongoingEvents.isEmpty)
        #expect(plan.upcomingEvents.first?.incomingTransition == transition)
    }

    @Test
    func dayPlanOnlyShowsFriendCountsWhileFriendAndSnapshotDataAreFresh() throws {
        let now = TestFixtures.date(dayInJuly: 3, hour: 20, minute: 0)
        let event = makeTimelineEvent(
            id: 1,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 21, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 22, minute: 0),
            friendSaveCount: 2
        )
        let freshState = makeTimelineState(
            events: [event],
            generatedAt: now,
            friends: WatchFriendSnapshot(state: .available, updatedAt: now)
        )
        let oldFriendState = makeTimelineState(
            events: [event],
            generatedAt: now,
            friends: WatchFriendSnapshot(
                state: .available,
                updatedAt: now.addingTimeInterval(-2 * 24 * 60 * 60)
            )
        )
        let oldSnapshotState = makeTimelineState(
            events: [event],
            generatedAt: now.addingTimeInterval(-2 * 24 * 60 * 60),
            friends: WatchFriendSnapshot(state: .available, updatedAt: now)
        )

        let freshPlan = try #require(
            WatchDayPlanProjector(calendar: TestFixtures.festivalCalendar)
                .project(state: freshState, at: now)
                .content.plan
        )
        let oldFriendPlan = try #require(
            WatchDayPlanProjector(calendar: TestFixtures.festivalCalendar)
                .project(state: oldFriendState, at: now)
                .content.plan
        )
        let oldSnapshotPlan = try #require(
            WatchDayPlanProjector(calendar: TestFixtures.festivalCalendar)
                .project(state: oldSnapshotState, at: now)
                .content.plan
        )

        #expect(freshPlan.upcomingEvents.first?.friendSaveCount == 2)
        #expect(oldFriendPlan.upcomingEvents.first?.friendSaveCount == nil)
        #expect(oldSnapshotPlan.upcomingEvents.first?.friendSaveCount == nil)
    }

    @Test
    func dayPlanDistinguishesDailyAndFestivalEndStates() {
        let now = TestFixtures.date(dayInJuly: 3, hour: 20, minute: 0)
        let pastSaved = makeTimelineEvent(
            id: 1,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 18, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 19, minute: 0)
        )
        let futureProgram = makeTimelineEvent(
            id: 2,
            startDate: TestFixtures.date(dayInJuly: 3, hour: 21, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 3, hour: 22, minute: 0),
            isSaved: false
        )
        let tomorrowSaved = makeTimelineEvent(
            id: 3,
            startDate: TestFixtures.date(dayInJuly: 4, hour: 20, minute: 0),
            endDate: TestFixtures.date(dayInJuly: 4, hour: 21, minute: 0),
            festivalDay: 4
        )
        let projector = distantDayPlanProjector

        #expect(projector.project(
            state: makeTimelineState(events: [pastSaved, futureProgram]),
            at: now
        ).content == .planEnded)
        #expect(projector.project(
            state: makeTimelineState(events: [futureProgram, tomorrowSaved]),
            at: now
        ).content == .noSavedEventsToday)
        #expect(projector.project(
            state: makeTimelineState(events: [tomorrowSaved]),
            at: TestFixtures.date(dayInJuly: 2, hour: 20, minute: 0)
        ).content == .noFestivalToday)
        #expect(projector.project(
            state: makeTimelineState(events: [pastSaved]),
            at: now
        ).content == .festivalEnded)
        #expect(projector.project(
            state: makeTimelineState(
                events: [futureProgram],
                missingSavedEventCount: 1
            ),
            at: now
        ).content == .planUnavailable)
    }

    @Test
    func negativeMissingSavedEventCountIsRejected() throws {
        let state = makeTimelineState(
            events: [makeTimelineEvent(
                id: 1,
                startDate: referenceDate.addingTimeInterval(60 * 60),
                endDate: referenceDate.addingTimeInterval(2 * 60 * 60)
            )],
            missingSavedEventCount: -1
        )
        let snapshot = try #require(state.snapshot)
        let data = try WatchSnapshotCodec().encode(snapshot)

        #expect(WatchSnapshotValidator(expectedFestivalYear: 2026).validate(
            data,
            currentRevision: nil
        ) == .rejected(.invalidPayload(.invalidPlanContract)))
    }

    private var referenceDate: Date {
        Date(timeIntervalSince1970: 1_782_998_400)
    }

    private var distantFreshnessPolicy: WatchSnapshotFreshnessPolicy {
        WatchSnapshotFreshnessPolicy(
            maximumFestivalDataAge: 365 * 24 * 60 * 60,
            maximumRecommendationAge: 365 * 24 * 60 * 60,
            maximumFriendDataAge: 365 * 24 * 60 * 60,
            maximumSnapshotAge: 365 * 24 * 60 * 60,
            maximumClockSkew: 5 * 60
        )
    }

    private var distantFreshnessProjector: WatchNextEventTimelineProjector {
        WatchNextEventTimelineProjector(
            freshnessPolicy: distantFreshnessPolicy
        )
    }

    private var distantDayPlanProjector: WatchDayPlanProjector {
        WatchDayPlanProjector(
            freshnessPolicy: distantFreshnessPolicy,
            calendar: TestFixtures.festivalCalendar
        )
    }

    private func makeTimelineState(
        events: [WatchEventSnapshot],
        missingSavedEventCount: Int? = 0,
        generatedAt: Date? = nil,
        friends: WatchFriendSnapshot = WatchFriendSnapshot(
            state: .unavailable,
            updatedAt: nil
        ),
        planTransitions: [WatchPlanTransitionSnapshot] = [],
        planOverlaps: [WatchPlanOverlapSnapshot] = []
    ) -> WatchSnapshotState {
        let generatedAt = generatedAt ?? referenceDate
        let snapshot = WatchSnapshotEnvelope(
            schemaVersion: WatchSnapshotEnvelope.currentSchemaVersion,
            festivalYear: 2026,
            revision: 1,
            generatedAt: generatedAt,
            environment: .production,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: .remote,
                festivalDataUpdatedAt: generatedAt,
                refreshCheckedAt: generatedAt,
                profileCloudRefreshedAt: nil,
                recommendationsGeneratedAt: nil
            ),
            payload: WatchFestivalSnapshot(
                events: events,
                missingSavedEventCount: missingSavedEventCount,
                recommendations: WatchRecommendationSnapshot(
                    state: .unavailable,
                    generatedAt: nil,
                    orderedEventIDs: []
                ),
                friends: friends,
                planTransitions: planTransitions,
                planOverlaps: planOverlaps
            )
        )
        return WatchSnapshotState(
            snapshot: snapshot,
            availability: .available,
            importDiagnostic: nil
        )
    }

    private func makeTimelineEvent(
        id: Int,
        startDate: Date,
        endDate: Date,
        isSaved: Bool = true,
        friendSaveCount: Int? = nil,
        festivalDay: Int = 3
    ) -> WatchEventSnapshot {
        WatchEventSnapshot(
            id: id,
            artistID: 1_000 + id,
            artistName: "Artist \(id)",
            stageID: 2_000 + id,
            stageNumber: id,
            stageNameGerman: "Bühne \(id)",
            stageNameEnglish: "Stage \(id)",
            festivalDay: festivalDay,
            startDate: startDate,
            endDate: endDate,
            isSaved: isSaved,
            hasPositiveRating: false,
            recommendationRank: nil,
            friendSaveCount: friendSaveCount
        )
    }

    private func makeEnvelope(
        schemaVersion: Int = WatchSnapshotEnvelope.currentSchemaVersion,
        festivalYear: Int = 2026,
        revision: UInt64,
        environment: WatchSnapshotEnvironment = .production,
        festivalDataSource: WatchFestivalDataSource = .remote,
        recommendationGeneratedAt: Date? = nil,
        artistName: String = "Duo Ruut"
    ) -> WatchSnapshotEnvelope {
        let recommendationGeneratedAt = recommendationGeneratedAt ?? referenceDate
        let startDate = referenceDate.addingTimeInterval(60 * 60)
        let event = WatchEventSnapshot(
            id: 101,
            artistID: 201,
            artistName: artistName,
            stageID: 301,
            stageNumber: 1,
            stageNameGerman: "Große Bühne",
            stageNameEnglish: "Main Stage",
            festivalDay: 3,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(60 * 60),
            isSaved: true,
            hasPositiveRating: true,
            recommendationRank: 0,
            friendSaveCount: 0
        )
        return WatchSnapshotEnvelope(
            schemaVersion: schemaVersion,
            festivalYear: festivalYear,
            revision: revision,
            generatedAt: referenceDate,
            environment: environment,
            freshness: WatchSnapshotFreshness(
                festivalDataSource: festivalDataSource,
                festivalDataUpdatedAt: referenceDate,
                refreshCheckedAt: referenceDate,
                profileCloudRefreshedAt: referenceDate,
                recommendationsGeneratedAt: recommendationGeneratedAt
            ),
            payload: WatchFestivalSnapshot(
                events: [event],
                recommendations: WatchRecommendationSnapshot(
                    state: .available,
                    generatedAt: recommendationGeneratedAt,
                    orderedEventIDs: [event.id]
                ),
                friends: WatchFriendSnapshot(
                    state: .available,
                    updatedAt: referenceDate
                ),
                planTransitions: [],
                planOverlaps: []
            )
        )
    }

    private func compressedWireData(_ json: String) throws -> Data {
        try (Data(json.utf8) as NSData).compressed(using: .lzfse) as Data
    }
}

private final class InMemoryWatchSnapshotPersistence: WatchSnapshotDataPersisting {
    var data: Data?
    var failReads: Bool
    var failWrites: Bool
    private(set) var writeCount = 0

    init(
        data: Data? = nil,
        failReads: Bool = false,
        failWrites: Bool = false
    ) {
        self.data = data
        self.failReads = failReads
        self.failWrites = failWrites
    }

    func read() throws -> Data? {
        if failReads {
            throw TestPersistenceError.readFailed
        }
        return data
    }

    func replaceAtomically(with data: Data) throws {
        if failWrites {
            throw TestPersistenceError.writeFailed
        }
        writeCount += 1
        self.data = data
    }
}

private enum TestPersistenceError: Error {
    case readFailed
    case writeFailed
}

private actor WatchImportRecorder {
    private var values = [Int]()

    func append(_ value: Int) {
        values.append(value)
    }

    func snapshot() -> [Int] {
        values
    }
}
