import Foundation

/*
 {"data": {
   "Big Band Of Boom": {
     "browse_genres": ["swing", "electronic"],
     "en": {
       "summary": "Swing meets rock with electronic flair",
       "tags": [
         "Swing Rock",
         "Electro Swing"
       ],
       "countries": [
         "🇬🇧"
       ]
     },
     "de": {
       "summary": "Swing trifft Rock mit elektronischem Touch",
       "tags": [
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
    var tags: [String]?
    var countries: [String]?

    init(
        summary: String? = nil,
        tags: [String]? = nil,
        countries: [String]? = nil
    ) {
        self.summary = summary
        self.tags = tags
        self.countries = countries
    }

    static func empty() -> ExtraDataEntryForLanguage {
        return ExtraDataEntryForLanguage()
    }
}

struct ExtraDataEntry: Codable {
    var browseGenres: [String]
    var de: ExtraDataEntryForLanguage?
    var en: ExtraDataEntryForLanguage?

    enum CodingKeys: String, CodingKey {
        case browseGenres = "browse_genres"
        case de
        case en
    }

    init(
        browseGenres: [String] = [],
        de: ExtraDataEntryForLanguage? = nil,
        en: ExtraDataEntryForLanguage? = nil
    ) {
        self.browseGenres = browseGenres
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

struct BrowseTaxonomyEntry: Codable, Hashable {
    let id: String
    let labelDE: String
    let labelEN: String

    enum CodingKeys: String, CodingKey {
        case id
        case labelDE = "label_de"
        case labelEN = "label_en"
    }

    var localizedLabel: String {
        if Locale.current.languageCode == "de" {
            return labelDE
        } else {
            return labelEN
        }
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

func loadBrowseTaxonomyFromResource(fileName: String) -> [BrowseTaxonomyEntry]? {
    guard
        let url = Bundle.main.url(forResource: fileName, withExtension: "json")
    else {
        print("Could not find file \(fileName).json in bundle")
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let result = try decoder.decode([BrowseTaxonomyEntry].self, from: data)
        return result
    } catch {
        print("Error decoding \(fileName).json: \(error)")
        return nil
    }
}
