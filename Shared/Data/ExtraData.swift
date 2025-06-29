import Foundation

/*
 {"data": {
   "Big Band Of Boom": {
     "en": {
       "summary": "Swing meets rock with electronic flair",
       "genres": [
         "Swing Rock",
         "Electro Swing"
       ],
       "countries": [
         "🇬🇧"
       ]
     },
     "de": {
       "summary": "Swing trifft Rock mit elektronischem Touch",
       "genres": [
         "Swing Rock",
         "Electro Swing"
       ],
       "countries": [
         "🇬🇧"
       ]
     }
   },
   ...
 }}
 */

struct ExtraDataEntryForLanguage: Codable {
    var summary: String?
    var genres: [String]?
    var countries: [String]?

    init(
        summary: String? = nil,
        genres: [String]? = nil,
        countries: [String]? = nil
    ) {
        self.summary = summary
        self.genres = genres
        self.countries = countries
    }

    static func empty() -> ExtraDataEntryForLanguage {
        return ExtraDataEntryForLanguage()
    }
}

struct ExtraDataEntry: Codable {
    var de: ExtraDataEntryForLanguage?
    var en: ExtraDataEntryForLanguage?

    init(
        de: ExtraDataEntryForLanguage? = nil,
        en: ExtraDataEntryForLanguage? = nil
    ) {
        self.de = de
        self.en = en
    }
    static func empty() -> ExtraDataEntry {
        return ExtraDataEntry(
            de: ExtraDataEntryForLanguage.empty(),
            en: ExtraDataEntryForLanguage.empty()
        )
    }
}

struct ExtraDataCollection: Codable {
    var data: [String: ExtraDataEntry]

    init(data: [String: ExtraDataEntry] = [:]) {
        self.data = data
    }

    static func empty() -> ExtraDataCollection {
        return ExtraDataCollection(data: [:])
    }
}

func loadExtraDataFromResource(fileName: String) -> ExtraDataCollection? {
    guard
        let url = Bundle.main.url(forResource: fileName, withExtension: "json")
    else {
        print("Could not find file \(fileName).json in bundle")
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let result = try decoder.decode(ExtraDataCollection.self, from: data)
        return result
    } catch {
        print("Error decoding \(fileName).json: \(error)")
        return nil
    }
}
