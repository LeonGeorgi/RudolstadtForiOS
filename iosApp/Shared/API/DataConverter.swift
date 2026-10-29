import Foundation
import OSLog
import RudolstadtCore

func sourceJSONString(_ data: Data) throws -> String {
    guard let json = String(data: data, encoding: .utf8) else {
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
    return json
}

func convertFestivalSourceToEntities(
    apiData: RudolstadtPayload,
    extraData: ExtraDataCollection
) throws -> FestivalData {
    try convertFestivalSourceToProgram(apiData: apiData, extraData: extraData).native()
}

func convertFestivalSourceToProgram(
    apiData: RudolstadtPayload, extraData: ExtraDataCollection
) throws -> FestivalProgram {
    try KotlinCore.bridge.programFromRudolstadtPayload(
        payload: apiData, extraData: extraData,
        year: Int32(FestivalConfiguration.year), fold: KotlinCore.foldProgramText)
}

func convertAPINewsItemToNewsItem(apiNewsItem: APINewsItem) -> NewsItem {
    apiNewsItem.message()
}

extension String {
    func decodingHTMLCharacterReferences() -> String {
        KotlinCore.bridge.decodeCharacterReferences(value: self)
    }
}

func rudolstadtArtistImageURL(_ value: String) -> String {
    let placeholders: Set<String> = [
        "aaaplatzhalter-jj406147npwtqwg.jpg", "aaaplatzhalter-eev4gvb1gk8384g.jpg",
    ]
    guard let url = URL(string: value) else { return "" }
    return placeholders.contains(url.lastPathComponent.lowercased()) ? "" : value
}
