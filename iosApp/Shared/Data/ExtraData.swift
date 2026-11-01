import Foundation
import RudolstadtCore

typealias ExtraDataCollection = ProgramExtras
typealias BrowseTaxonomyEntry = RudolstadtCore.BrowseTaxonomyEntry

extension ProgramExtras: @unchecked @retroactive Sendable {
    static func empty() -> ProgramExtras { KotlinCore.bridge.emptyProgramExtras() }
}

extension RudolstadtCore.BrowseTaxonomyEntry: @unchecked @retroactive Sendable {
    var localizedLabel: String { localizedLabel(locale: .current) }
    func localizedLabel(locale: Locale) -> String {
        locale.appLanguageCodeIdentifier == "de" ? labelDE : labelEN
    }
}

func loadExtraDataFromResource(fileName: String) -> ExtraDataCollection? {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else { return nil }
    do {
        return try KotlinCore.bridge.decodeProgramExtras(sourceJSON: String(contentsOf: url, encoding: .utf8))
    } catch {
        AppLog.data.error("Invalid supplemental data: \(error.localizedDescription)")
        return nil
    }
}

func loadBrowseTaxonomyFromResource(fileName: String) -> [BrowseTaxonomyEntry]? {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else { return nil }
    do {
        return try KotlinCore.bridge.decodeBrowseTaxonomy(sourceJSON: String(contentsOf: url, encoding: .utf8))
    } catch {
        AppLog.data.error("Invalid browse taxonomy: \(error.localizedDescription)")
        return nil
    }
}
