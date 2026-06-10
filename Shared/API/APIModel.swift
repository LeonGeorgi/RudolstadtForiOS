import Foundation
import OSLog

struct APIRudolstadtData: Codable {
    let areas: [APIArea]
    let artists: [APIArtist]
    let events: [APIEvent]
    let stages: [APIStage]
    let tags: [APITag]
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
        dateFormatter.timeZone = TimeZone(identifier: timezone)

        return dateFormatter.date(from: date)
    }

    func getDateAsGermanString() -> String? {
        // e.g. "06.07.2025"
        let dateFormatter = DateFormatter()
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

enum APIStageCategory: String, Codable {
    case cityticket = "cityticket"
    case comboticket = "comboticket"
    case information = "information"
}

struct APIStage: Codable {
    let id: Int
    let title: String
    let titleEN: String
    let description: String?
    let descriptionEN: String?
    let lat: Double
    let lon: Double
    let area: Int
    let category: APIStageCategory
    let mapNumber: Int

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
