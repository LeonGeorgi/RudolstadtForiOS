import Foundation
import OSLog

struct APIRudolstadtData: Codable {
    let areas: [APIArea]
    let artists: [APIArtist]
    let events: [APIEvent]
    let stages: [APIStage]
    let tags: [APITag]
    var omittedRecordCount: Int = 0
}

enum APIArtistCategory: Codable, Equatable {
    case concert
    case dancing
    case festivalPlus
    case unknown(rawValue: String)

    var rawValue: String {
        switch self {
        case .concert:
            return "concert"
        case .dancing:
            return "dancing"
        case .festivalPlus:
            return "festival-plus"
        case .unknown(let rawValue):
            return rawValue
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "concert":
            self = .concert
        case "dancing":
            self = .dancing
        case "festival-plus":
            self = .festivalPlus
        default:
            AppLog.data.error(
                "Unknown artist category from API: \(rawValue, privacy: .public)"
            )
            self = .unknown(rawValue: rawValue)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct APIArtist: Codable {
    let id: Int
    let category: APIArtistCategory
    let hideArtist: Bool
    let name: String
    let country: String?
    let website: String?
    let video: String?
    let facebook: String?
    let instagram: String?
    let soundcloud: String?
    let imgThumb: String
    let imgFull: String
    let descriptionDE: String
    let descriptionEN: String

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case hideArtist = "hide_artist"
        case name
        case country
        case website
        case video
        case facebook
        case instagram
        case soundcloud
        case imgThumb = "img_thumb"
        case imgFull = "img_full"
        case descriptionDE = "description_de"
        case descriptionEN = "description_en"
    }
}

struct APITime: Codable {
    let date: String  // e.g. "2025-07-06 14:00:00.000000"
    let timezoneType: Int  // eg. 3
    let timezone: String  // e.g. "Europe/Berlin"

    enum CodingKeys: String, CodingKey {
        case date
        case timezoneType = "timezone_type"
        case timezone
    }

    func getDate() -> Date? {
        guard let zone = TimeZone(identifier: timezone) else { return nil }
        let parts = date.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].utf8.count == 6,
            parts[1].utf8.allSatisfy({ (48...57).contains($0) }),
            let microseconds = Double(parts[1]),
            let base = FestivalDateUtilities.parse(
                String(parts[0]),
                format: "yyyy-MM-dd HH:mm:ss", timeZone: zone)
        else { return nil }
        return base.addingTimeInterval(microseconds / 1_000_000)
    }

    func getDateAsGermanString() -> String? {
        // e.g. "06.07.2025"
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "dd.MM.yyyy"
        dateFormatter.timeZone = TimeZone(identifier: timezone)
        guard let date = getDate() else {
            return nil
        }
        return dateFormatter.string(from: date)
    }

    func getTimeAsGermanString() -> String? {
        // e.g. "14:00"
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = TimeZone(identifier: timezone)
        guard let date = getDate() else {
            return nil
        }
        return dateFormatter.string(from: date)
    }

}

struct APINewsItem: Codable {
    let id: Int
    let title: String
    let language: String
    let teaser: String
    let text: String
    let time: APITime

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case language
        case teaser
        case text
        case time
    }
}

struct APIArea: Codable {
    let id: Int
    let title: String
    let titleEN: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleEN = "title_en"
    }
}

struct APIEvent: Codable {
    let id: Int
    let start: APITime
    let day: String  // e.g. "05.07.2025"
    let time: String
    let stage: Int
    let artist: Int
    let tags: [Int]
    let updated: APITime

    enum CodingKeys: String, CodingKey {
        case id
        case start
        case day
        case time
        case stage
        case artist
        case tags
        case updated
    }

    func getDayInJuly() -> Int? {
        let dayInJuliy = day.split(separator: ".").first ?? ""
        return Int(dayInJuliy)
    }
}

// "cityticket"
// "comboticket"
// "information"

enum APIStageCategory: Codable, Equatable {
    case cityticket, comboticket, information
    case unknown(rawValue: String)

    var rawValue: String {
        switch self {
        case .cityticket: return "cityticket"
        case .comboticket: return "comboticket"
        case .information: return "information"
        case .unknown(let rawValue): return rawValue
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "cityticket": self = .cityticket
        case "comboticket": self = .comboticket
        case "information": self = .information
        default: self = .unknown(rawValue: value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct APIStage: Codable {
    let id: Int
    let title: String
    let titleEN: String
    let description: String?
    let descriptionEN: String?
    let lat: Double?
    let lon: Double?
    let area: Int
    let category: APIStageCategory
    let mapNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleEN = "title_en"
        case description
        case descriptionEN = "description_en"
        case lat
        case lon
        case area
        case category
        case mapNumber = "map_number"
    }
}

struct APITag: Codable {
    let id: Int
    let title: String
    let titleEN: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case titleEN = "title_en"
    }
}

// Consume one complete record even when it cannot be decoded. Structural JSON
// errors still fail the response; record failures remain visible after caching.
struct APIRecords<Value: Decodable>: Decodable {
    let values: [Value]
    let omittedCount: Int

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var values = [Value]()
        var omitted = 0
        while !container.isAtEnd {
            let record = try container.superDecoder()
            do { values.append(try Value(from: record)) } catch { omitted += 1 }
        }
        self.values = values
        omittedCount = omitted
    }
}

extension APIRudolstadtData {
    enum CodingKeys: String, CodingKey {
        case areas, artists, events, stages, tags, omittedRecordCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let areas = try c.decode(APIRecords<APIArea>.self, forKey: .areas)
        let artists = try c.decode(APIRecords<APIArtist>.self, forKey: .artists)
        let events = try c.decode(APIRecords<APIEvent>.self, forKey: .events)
        let stages = try c.decode(APIRecords<APIStage>.self, forKey: .stages)
        let tags = try c.decode(APIRecords<APITag>.self, forKey: .tags)
        self.init(
            areas: areas.values, artists: artists.values, events: events.values,
            stages: stages.values, tags: tags.values,
            omittedRecordCount: (try c.decodeIfPresent(Int.self, forKey: .omittedRecordCount) ?? 0)
                + areas.omittedCount + artists.omittedCount + events.omittedCount
                + stages.omittedCount + tags.omittedCount)
    }
}

extension APIEvent {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        // Missing or malformed metadata must not destroy an identifiable event.
        start =
            (try? c.decode(APITime.self, forKey: .start))
            ?? APITime(date: "", timezoneType: 3, timezone: "")
        updated = (try? c.decode(APITime.self, forKey: .updated)) ?? start
        day = (try? c.decode(String.self, forKey: .day)) ?? ""
        time = (try? c.decode(String.self, forKey: .time)) ?? ""
        stage = (try? c.decode(Int.self, forKey: .stage)) ?? 0
        artist = (try? c.decode(Int.self, forKey: .artist)) ?? 0
        tags = (try? c.decode(APIRecords<Int>.self, forKey: .tags).values) ?? []
    }
}

extension APIArtist {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        category =
            (try? c.decode(APIArtistCategory.self, forKey: .category)) ?? .unknown(rawValue: "")
        hideArtist = (try? c.decode(Bool.self, forKey: .hideArtist)) ?? false
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        country = try? c.decode(String.self, forKey: .country)
        website = try? c.decode(String.self, forKey: .website)
        video = try? c.decode(String.self, forKey: .video)
        facebook = try? c.decode(String.self, forKey: .facebook)
        instagram = try? c.decode(String.self, forKey: .instagram)
        soundcloud = try? c.decode(String.self, forKey: .soundcloud)
        imgThumb = (try? c.decode(String.self, forKey: .imgThumb)) ?? ""
        imgFull = (try? c.decode(String.self, forKey: .imgFull)) ?? ""
        descriptionDE = (try? c.decode(String.self, forKey: .descriptionDE)) ?? ""
        descriptionEN = (try? c.decode(String.self, forKey: .descriptionEN)) ?? ""
    }
}

extension APIStage {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        titleEN = (try? c.decode(String.self, forKey: .titleEN)) ?? title
        description = try? c.decode(String.self, forKey: .description)
        descriptionEN = try? c.decode(String.self, forKey: .descriptionEN)
        lat = try? c.decode(Double.self, forKey: .lat)
        lon = try? c.decode(Double.self, forKey: .lon)
        area = (try? c.decode(Int.self, forKey: .area)) ?? 0
        category =
            (try? c.decode(APIStageCategory.self, forKey: .category)) ?? .unknown(rawValue: "")
        mapNumber = try? c.decode(Int.self, forKey: .mapNumber)
    }
}
