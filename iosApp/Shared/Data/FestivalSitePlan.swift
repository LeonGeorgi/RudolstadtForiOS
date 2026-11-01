import Foundation
import RudolstadtCore
import OSLog

extension FestivalCoordinate {
    var isValid: Bool {
        KotlinCore.bridge.usableCoordinates(latitude: latitude, longitude: longitude)
    }
}

/// A point in the published diagram, measured from its top-left corner.
/// These values are not GPS coordinates or a basis for walking distances.
struct FestivalPlanPoint: Codable, Equatable {
    let x: Double
    let y: Double

    var isValid: Bool {
        KotlinCore.bridge.validPlanPoint(x: x, y: y)
    }
}

enum FestivalPlanCategory: String, Codable, CaseIterable {
    case stage, entrance, food, parking, toilets, firstAid, service, activity

    var localizationKey: String { "site_plan.category.\(rawValue)" }

    var symbolName: String {
        switch self {
        case .stage: "music.mic"
        case .entrance: "door.left.hand.open"
        case .food: "fork.knife"
        case .parking: "parkingsign.circle"
        case .toilets: "figure.stand.dress.line.vertical.figure"
        case .firstAid: "cross.case"
        case .service: "info.circle"
        case .activity: "figure.play"
        }
    }
}

struct FestivalPlanLocation: Codable, Identifiable {
    let id: String
    let category: FestivalPlanCategory
    let nameDE: String
    let nameEN: String
    let noteDE: String?
    let noteEN: String?
    let reference: String?
    let stageID: Int?
    let point: FestivalPlanPoint?
    let coordinate: FestivalCoordinate?

    func localizedName(locale: Locale = .current) -> String {
        locale.appLanguageCodeIdentifier == "de" ? nameDE : nameEN
    }

    func localizedNote(locale: Locale = .current) -> String? {
        locale.appLanguageCodeIdentifier == "de" ? noteDE : noteEN
    }

    func matches(_ searchTerm: String, locale: Locale = .current) -> Bool {
        let text = [localizedName(locale: locale), localizedNote(locale: locale), reference]
            .compactMap { $0 }.joined(separator: " ")
        return searchTerm.isEmpty || normalize(string: text, locale: locale)
                .contains(normalize(string: searchTerm, locale: locale))
    }
}

/// Bundle these bytes without PNG optimization so the imported checksum stays valid.
struct FestivalPlanBackground: Codable {
    let resourceName: String
    let width: Double
    let height: Double
    let sha256: String

    func resourceURL(bundle: Bundle = .main) -> URL? {
        guard KotlinCore.bridge.validPlanBackground(name: resourceName, width: width, height: height) else { return nil }
        return bundle.url(forResource: resourceName, withExtension: "png")
            ?? bundle.url(forResource: resourceName, withExtension: "png", subdirectory: "FestivalBackup")
    }
}

struct FestivalSitePlan: Codable {
    let resourceName: String
    let sourceURL: URL
    let sourceSHA256: String
    let coordinateSourceURL: URL?
    let locations: [FestivalPlanLocation]
    let background: FestivalPlanBackground?

    func resourceURL(bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: resourceName, withExtension: "pdf")
            ?? bundle.url(forResource: resourceName, withExtension: "pdf", subdirectory: "FestivalBackup")
    }

    func location(forStageID id: FestivalPlaceID) -> FestivalPlanLocation? {
        locations.first { $0.stageID.map(FestivalPlaceID.numeric) == id }
    }

    func location(forStageID id: Int) -> FestivalPlanLocation? {
        location(forStageID: .numeric(id))
    }

    func isValid(stageIDs: Set<Int>) -> Bool {
        core.valid(stageIDs: Set(KotlinCore.ids(stageIDs)))
    }
}
