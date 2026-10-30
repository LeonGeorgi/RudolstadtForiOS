import Combine
import Foundation
import RudolstadtCore

/// The native UI uses immutable Kotlin program objects and native presentation state.
/// Domain calls are typed. JSON is confined to source formats and the disk cache.
enum KotlinCore {
    static let bridge = CoreBridge()
    static func foldProgramText(_ value: String) -> String {
        normalize(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }
    private static let unicodeCollation = CoreTextCollation(localized: false)
    private static let localizedCollation = CoreTextCollation(localized: true)
    static func artistOverview(_ request: CoreDiscoveryRequest) -> [Int] {
        bridge.artistOverview(request: request, collation: unicodeCollation).map(\.intValue)
    }
    static func matchingArtists(
        _ index: ProgramArtistIndex, favoritesOnly: Bool, ratings: [String: Int],
        search: String, groups: [String: String]
    ) -> [Artist] {
        index.matching(
            favoritesOnly: favoritesOnly, ratings: ratings.mapValues { KotlinInt(value: Int32($0)) },
            search: search, groups: groups, collation: unicodeCollation)
    }
    static func friends(_ request: CoreDiscoveryRequest) -> [CoreFriendRecommendation] {
        bridge.friends(request: request, collation: localizedCollation)
    }
    static func ids<S: Sequence>(_ values: S) -> [KotlinLong] where S.Element == Int {
        values.map { KotlinLong(value: Int64($0)) }
    }
    static func ratings(_ values: [Int: Int]) -> [KotlinLong: KotlinInt] {
        Dictionary(
            uniqueKeysWithValues: values.map {
                (KotlinLong(value: Int64($0.key)), KotlinInt(value: Int32($0.value)))
            })
    }

}

extension FestivalPlaceID {
    var coreID: String {
        switch self {
        case .numeric(let value): return "n:\(value)"
        case .text(let value): return "t:\(value)"
        }
    }
}

struct CoreEvent {
    let event: Event
    let forPlanning: Bool
    var duration: Int?
    var eligible: Bool

    init(_ event: Event) { self.init(event, forPlanning: true) }
    init(_ event: Event, forPlanning: Bool) {
        self.event = event
        self.forPlanning = forPlanning
        duration = event.durationMinutes
        eligible = forPlanning ? event.eligibleForPlanning : true
    }
}

extension LocalizedText {
    init(core: [String: String]) {
        self.init(
            values: Dictionary(uniqueKeysWithValues: core.map { (LanguageTag($0.key), $0.value) }))
    }
    var core: [String: String] {
        Dictionary(uniqueKeysWithValues: values.map { ($0.key.identifier, $0.value) })
    }
}

extension FestivalLink {
    var core: ProgramLink {
        ProgramLink(
            linkID: id, titles: title.core, destination: destination.absoluteString,
            inAppBrowser: openingMode == .inAppBrowser)
    }
}
extension ProgramLink {
    var native: FestivalLink? {
        guard let url = URL(string: destination), url.scheme != nil else { return nil }
        return FestivalLink(
            id: linkID, title: LocalizedText(core: titles), destination: url,
            openingMode: inAppBrowser ? .inAppBrowser : .externalBrowser)
    }
}
extension ProgramArtistDetails {
    var nativePreview: FestivalMusicPreview {
        switch previewKind {
        case "disabled": return .disabled
        case "songURL":
            return previewURL.flatMap(URL.init(string:)).map(FestivalMusicPreview.songURL)
                ?? .disabled
        default: return .automatic
        }
    }
}
extension FestivalEventDuration {
    var core: EventDuration { EventDuration(minutes: Int32(minutes), isEstimated: isEstimated) }
}
extension FestivalDay {
    var core: OccurrenceDay {
        OccurrenceDay(
            date: ProgramDay(
                id: id, year: Int32(date.year), month: Int32(date.month),
                day: Int32(date.day), start: interval.start.timeIntervalSince1970,
                end: interval.end.timeIntervalSince1970), titles: title?.core)
    }
}
extension OccurrenceDay {
    var native: FestivalDay {
        FestivalDay(
            id: date.id,
            date: FestivalCalendarDate(
                year: Int(date.year), month: Int(date.month), day: Int(date.day)),
            title: titles.map(LocalizedText.init(core:)),
            interval: DateInterval(
                start: Date(timeIntervalSince1970: date.start),
                end: Date(timeIntervalSince1970: date.end)))
    }
}
extension FestivalProgram {
    /// Only the native context is constructed here. Catalogs and event relationships retain Kotlin objects.
    func native(festivalID: String = "rudolstadt", curated: Bool = true) throws -> FestivalData {
        FestivalData(
            artists: artists, areas: areas, stages: places.sorted(by: Stage.precedes),
            events: events.sorted(by: Event.precedes), omittedRecordCount: Int(omittedRecordCount),
            artistSimilarities: curated ? .bundled : nil,
            walkingDistanceMatrix: curated ? StageWalkingDistanceProvider.bundled : .empty,
            festivalYear: Int(year), sitePlan: try sitePlan?.native(),
            identity: FestivalIdentity(festivalID: festivalID, editionID: String(year)),
            features: FestivalFeatures(eventDetails: eventDetails.map { .available($0) } ?? .unsupported))
    }
}

extension SitePlan {
    func native() throws -> FestivalSitePlan {
        guard let source = URL(string: sourceURL) else {
            throw FestivalLoadingError.invalidSnapshot
        }
        let locations = try locations.map { value -> FestivalPlanLocation in
            guard let category = FestivalPlanCategory(rawValue: value.category) else {
                throw FestivalLoadingError.invalidSnapshot
            }
            return FestivalPlanLocation(
                id: value.id, category: category, nameDE: value.nameDE, nameEN: value.nameEN,
                noteDE: value.noteDE, noteEN: value.noteEN, reference: value.reference,
                stageID: value.stageID?.intValue,
                point: value.point.map { FestivalPlanPoint(x: $0.x, y: $0.y) },
                coordinate: value.coordinate.map {
                    FestivalCoordinate(
                        latitude: $0.latitude, longitude: $0.longitude,
                        isApproximate: $0.isApproximate,
                        sourceURL: $0.sourceURL.flatMap(URL.init(string:)))
                })
        }
        return FestivalSitePlan(
            resourceName: resourceName, sourceURL: source, sourceSHA256: sourceSHA256,
            coordinateSourceURL: coordinateSourceURL.flatMap(URL.init(string:)),
            locations: locations,
            background: background.map {
                FestivalPlanBackground(
                    resourceName: $0.resourceName, width: $0.width, height: $0.height,
                    sha256: $0.sha256)
            })
    }
}

typealias CoreFriendProfile = FriendProfile

extension FriendProfile {
    convenience init(_ profile: SharedFestivalProfile) {
        self.init(
            id: profile.profileID, displayName: profile.badge.displayName,
            savedEventIDs: profile.saved, artistPreferences: profile.preferences)
    }
}

typealias CoreFestivalDefinition = FestivalDefinition
extension FestivalDefinition {
    var earliestProgramDate: FestivalCalendarDate? {
        earliestCalendarDate.map {
            FestivalCalendarDate(year: Int($0.year), month: Int($0.month), day: Int($0.day))
        }
    }
}

private final class CoreTextCollation: NSObject, TextCollation {
    let localized: Bool
    init(localized: Bool) { self.localized = localized }
    func compare(a: String, b: String) -> Int32 {
        if localized { return Int32(a.localizedCaseInsensitiveCompare(b).rawValue) }
        return a == b ? 0 : a < b ? -1 : 1
    }
}

extension CoreEvent {
    var core: ProgramEvent {
        event.planningEvent(
            duration: duration.map { KotlinInt(value: Int32($0)) },
            eligible: eligible, forPlanning: forPlanning)
    }
}

extension FestivalArtistPreference {
    var core: ArtistPreference {
        ArtistPreference(artistID: Int64(artistID), rating: Int32(rating), iconName: iconName)
    }
}
extension FestivalArtistNote {
    var core: ArtistNote { ArtistNote(artistID: Int64(artistID), noteText: noteText) }
}

extension StageTransferEstimate {
    var core: Transfer {
        Transfer(
            distanceInMeters: distanceInMeters, walkingMinutes: Int32(walkingMinutes),
            source: source.rawValue)
    }
    init(_ value: Transfer) {
        self.init(
            distanceInMeters: value.distanceInMeters, walkingMinutes: Int(value.walkingMinutes),
            source: StageTransferSource(rawValue: value.source) ?? .directCoordinateEstimate)
    }
}
extension StageTransferPolicy {
    var core: TransferPolicy {
        TransferPolicy(
            walkingSpeedInMetersPerMinute: walkingSpeedInMetersPerMinute,
            coordinateDetourFactor: coordinateDetourFactor,
            maximumAnchorDistanceInMeters: maximumAnchorDistanceInMeters,
            maximumAnchorCount: Int32(maximumAnchorCount),
            knownRouteAirDistanceToleranceInMeters: knownRouteAirDistanceToleranceInMeters)
    }
}
extension ScheduleTransitionPolicy {
    var core: TransitionPolicy {
        TransitionPolicy(
            arrivalBufferMinutes: Int32(arrivalBufferMinutes),
            maximumMissedMinutes: Int32(maximumMissedMinutes),
            tightTransitionThresholdMinutes: Int32(tightTransitionThresholdMinutes),
            estimatedTransfersCanBlock: estimatedTransfersCanBlock)
    }
}
extension TransitionAssessment {
    var native: ScheduleTransitionAssessment { ScheduleTransitionAssessment(self) }
}
extension ScheduleTransitionAssessment {
    init(_ value: TransitionAssessment) {
        self.init(
            firstEventID: Int(value.firstEventID), secondEventID: Int(value.secondEventID),
            timeOverlapMinutes: Int(value.timeOverlapMinutes),
            availableTransferMinutes: value.availableTransferMinutes?.intValue,
            transfer: value.transfer.map(StageTransferEstimate.init),
            projectedLatenessMinutes: value.projectedLatenessMinutes?.intValue,
            status: ScheduleTransitionStatus(rawValue: value.status) ?? .unknown)
    }
}

extension FestivalData {
    var coreProgram: FestivalProgram {
        FestivalProgram(artists: artists, areas: areas, places: stages, events: events,
            omittedRecordCount: Int32(omittedRecordCount), year: Int32(festivalYear), sitePlan: sitePlan?.core,
            eventDetails: features.eventDetails.value)
    }
}

extension FestivalPlaceID {
    init(coreID: String) {
        if coreID.hasPrefix("n:"), let value = Int(coreID.dropFirst(2)) { self = .numeric(value) }
        else { self = .text(String(coreID.dropFirst(2))) }
    }
}

extension FestivalCoordinate {
    var core: PlanCoordinate {
        PlanCoordinate(latitude: latitude, longitude: longitude, isApproximate: isApproximate,
            sourceURL: sourceURL?.absoluteString)
    }
}

extension PlanCoordinate {
    var native: FestivalCoordinate {
        FestivalCoordinate(latitude: latitude, longitude: longitude, isApproximate: isApproximate,
            sourceURL: sourceURL.flatMap(URL.init(string:)))
    }
}

extension FestivalSitePlan {
    var core: SitePlan {
        SitePlan(resourceName: resourceName, sourceURL: sourceURL.absoluteString,
            sourceSHA256: sourceSHA256, coordinateSourceURL: coordinateSourceURL?.absoluteString,
            locations: locations.map {
                PlanLocation(id: $0.id, category: $0.category.rawValue, nameDE: $0.nameDE, nameEN: $0.nameEN,
                    noteDE: $0.noteDE, noteEN: $0.noteEN, reference: $0.reference,
                    stageID: $0.stageID.map { KotlinLong(value: Int64($0)) },
                    point: $0.point.map { MapPoint(x: $0.x, y: $0.y) }, coordinate: $0.coordinate?.core)
            }, background: background.map { PlanBackground(resourceName: $0.resourceName,
                width: $0.width, height: $0.height, sha256: $0.sha256) })
    }
}

extension RudolstadtPayload: @unchecked @retroactive Sendable {}
extension RudolstadtRecords: @unchecked @retroactive Sendable {}

extension FestivalDataSource {
    var core: String { String(describing: self) }
    init?(core: String) {
        switch core {
        case "remote": self = .remote
        case "cache": self = .cache
        case "staleCache": self = .staleCache
        case "bundledBackup": self = .bundledBackup
        case "bundledArchive": self = .bundledArchive
        case "bundledExperiment": self = .bundledExperiment
        case "preview": self = .preview
        case "screenshot": self = .screenshot
        default: return nil
        }
    }
}
extension Error {
    var appFailure: AppFailure {
        let error = self as? FestivalDataProviderError
        return AppFailure(
            reason: error?.reason.rawValue ?? "",
            owner: error.map { String(describing: $0.failure.owner) }
                ?? (self is URLError ? "connection" : "unknown"),
            httpStatus: error?.failure.httpStatusCode.map { KotlinInt(value: Int32($0)) })
    }
}
extension AppFailure {
    var native: FestivalDataDownloadFailure {
        let value: FestivalDataDownloadFailureOwner
        switch owner {
        case "festivalSide": value = .festivalSide
        case "appSide": value = .appSide
        case "connection": value = .connection
        default: value = .unknown
        }
        return FestivalDataDownloadFailure(owner: value, httpStatusCode: httpStatus?.intValue)
    }
}
extension ArtistPreference {
    var native: FestivalArtistPreference {
        FestivalArtistPreference(artistID: Int(artistID), rating: Int(rating), iconName: iconName)
    }
}

extension NewsSource {
    var core: String { String(describing: self) }
    init?(core: String) {
        switch core {
        case "remote": self = .remote
        case "cache": self = .cache
        case "bundle", "bundledBackup": self = .bundle
        case "screenshot": self = .screenshot
        default: return nil
        }
    }
}

extension FestivalIdentity {
    var core: RudolstadtCore.FestivalIdentity {
        RudolstadtCore.FestivalIdentity(festivalID: festivalID, editionID: editionID)
    }
}

/// SwiftUI observes notifications; values always come from the current shared snapshot.
@MainActor
class KotlinStateStore<State: AnyObject>: ObservableObject {
    nonisolated let objectWillChange = ObservableObjectPublisher()
    private let current: () -> State
    private var observation: StateSubscription?
    var state: State { current() }

    init(
        current: @escaping () -> State,
        observe: (@escaping (State) -> Void) -> StateSubscription
    ) {
        self.current = current
        observation = observe { [weak self] _ in self?.objectWillChange.send() }
    }
    deinit { observation?.cancel() }
}

extension KotlinDouble {
    var date: Date { Date(timeIntervalSince1970: doubleValue) }
}

typealias CoreDiscoveryArtist = DiscoveryArtist
typealias CoreDiscoveryRequest = DiscoveryRequest
typealias CoreFriendRecommendation = FriendRecommendation
extension DiscoveryArtist {
    convenience init(_ artist: Artist, locale: Locale = .current) {
        self.init(
            id: artist.artistID, name: artist.formattedName,
            normalizedName: normalizedArtistName(artist.name, locale: locale),
            hidden: artist.hiddenFromArtistList, isMetadataAvailable: artist.isMetadataAvailable)
    }
    var core: DiscoveryArtist { self }
}
extension DiscoveryRequest {
    convenience init(
        artists: [DiscoveryArtist] = [], profiles: [FriendProfile] = [], events: [CoreEvent] = [],
        excluded: Set<Int> = [], ratings: [Int: Int] = [:], savedEventIDs: Set<Int> = [],
        favoritesOnly: Bool = false, search: String = ""
    ) {
        self.init(
            artists: artists, profiles: profiles, events: events.map(\.core),
            excluded: Set(KotlinCore.ids(excluded)),
            ratings: KotlinCore.ratings(ratings), savedEventIDs: Set(KotlinCore.ids(savedEventIDs)),
            favoritesOnly: favoritesOnly, search: search)
    }
    var core: DiscoveryRequest { self }
}
extension ProgramDay {
    var native: FestivalDay {
        FestivalDay(
            id: id, date: FestivalCalendarDate(year: Int(year), month: Int(month), day: Int(day)),
            title: nil,
            interval: DateInterval(
                start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end)))
    }
}

typealias CoreLocation = PlaceLocation
typealias CoreMapGeometry = MapGeometry
extension PlaceLocation {
    convenience init(_ value: StageTransferLocation) {
        self.init(id: value.stageID.coreID, latitude: value.latitude, longitude: value.longitude)
    }
    var core: PlaceLocation { self }
}
extension MapGeometry {
    convenience init(_ map: FestivalMap) {
        let placeIDs: [String]; let coordinates: [PlaceLocation]; let positions: [MapPoint]
        let width: KotlinDouble?; let height: KotlinDouble?
        switch map.content {
        case .geographic(let values):
            placeIDs = values.keys.map(\.coreID)
            coordinates = values.map {
                PlaceLocation(
                    id: $0.key.coreID, latitude: $0.value.latitude, longitude: $0.value.longitude)
            }
            positions = []; width = nil; height = nil
        case .illustrated(let artwork, let values):
            placeIDs = values.keys.map(\.coreID); coordinates = []
            positions = values.values.map { MapPoint(x: $0.x, y: $0.y) }
            width = KotlinDouble(value: artwork.logicalSize.width);
            height = KotlinDouble(value: artwork.logicalSize.height)
        }
        self.init(
            id: map.id, placeIDs: placeIDs, coordinates: coordinates, positions: positions,
            width: width,
            height: height)
    }
    var core: MapGeometry { self }
}
