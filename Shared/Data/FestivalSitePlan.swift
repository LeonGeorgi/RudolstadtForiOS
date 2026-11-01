import Foundation

extension FestivalCoordinate {
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && (latitude != 0 || longitude != 0)
    }
}

/// A point in the published diagram, measured from its top-left corner.
/// These values are not GPS coordinates or a basis for walking distances.
struct FestivalPlanPoint: Decodable, Equatable {
    let x: Double
    let y: Double

    var isValid: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }
}

enum FestivalPlanCategory: String, Decodable, CaseIterable {
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

struct FestivalPlanLocation: Decodable, Identifiable {
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
struct FestivalPlanBackground: Decodable {
    let resourceName: String
    let width: Double
    let height: Double
    let sha256: String

    func resourceURL(bundle: Bundle = .main) -> URL? {
        guard !resourceName.isEmpty, !resourceName.contains("/"), !resourceName.contains(".."),
              width.isFinite, height.isFinite, width > 0, height > 0 else { return nil }
        return bundle.url(forResource: resourceName, withExtension: "png")
            ?? bundle.url(forResource: resourceName, withExtension: "png", subdirectory: "FestivalBackup")
    }
}

struct FestivalSitePlan: Decodable {
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
        guard !resourceName.isEmpty, !resourceName.contains("/"), !resourceName.contains(".."),
              sourceURL.scheme == "https", !sourceSHA256.isEmpty,
              !locations.isEmpty, Set(locations.map(\.id)).count == locations.count
        else { return false }
        var linkedStageIDs = Set<Int>()
        for location in locations {
            guard !location.id.isEmpty, !location.nameDE.isEmpty, !location.nameEN.isEmpty,
                  location.point.map(\.isValid) ?? true,
                  location.coordinate.map(\.isValid) ?? true else { return false }
            if let stageID = location.stageID {
                guard location.category == .stage, stageIDs.contains(stageID),
                      linkedStageIDs.insert(stageID).inserted, location.point != nil
                else { return false }
            } else if location.category == .stage {
                return false
            }
        }
        return true
    }
}
