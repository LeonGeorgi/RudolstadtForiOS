/*
 {
 "id": 98,
 "category": "concert",
 "hide_artist": false,
 "name": "VagabunT",
 "country": "",
 "website": "http://vagabunt-music.com",
 "video": "",
 "facebook": "",
 "instagram": "https://www.instagram.com/vagabunt_music",
 "soundcloud": "",
 "img_thumb": "/assets/images/v/VagabunT-bdb0k0c5hb6mzqw.jpg",
 "img_full": "/assets/images/h/VagabunT-47a6czawm0gdw3r.jpg",
 "description_de": "VagabunT spielt eine Mélange aus französischem Straßenchanson, kolumbianischer Cumbia und portugiesischem Fado gepaart mit Reggae, Folk und griechischem Wein: ein Wechselspiel aus lebensfrohen und heiteren sowie gedankenverlorenen und besinnlichen Stücken.\n&nbsp;\nAntoine Mathey, g, voc <br>Margarete Franke, voc, cl <br>Steffen Wallendorf, b <br>Björn Reinemer, perc\n&nbsp;\nmargarete.franke@yahoo.com",
 "description_en": "French street chanson meets Colombian cumbia and Portuguese fado. Add a dash of reggae, folk and Greek wine and voilà! VagabunT.\nAntoine Mathey, g, voc <br>Margarete Franke, voc, cl <br>Steffen Wallendorf, b <br>Björn Reinemer, perc\nmargarete.franke@yahoo.com"
 },
 */

import Foundation

struct APIRudolstadtData: Codable {
    let news: [APINewsItem]
    let areas: [APIArea]
    let artists: [APIArtist]
    let events: [APIEvent]
    let stages: [APIStage]
    let tags: [APITag]
}

enum APIArtistCategory: String, Codable {
    case concert = "concert"
    case dancing = "dancing"
    case festivalPlus = "festival-plus"
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

/*
 {
 "id": 852,
 "title": "Interview with Ezé",
 "language": "en",
 "teaser": "Deutsche Welle broadcasts the French conversation in Burkina Faso.",
 "text": "\n\n\n                    \n                            \n    \n                        \n            We are happy for Ezé! Deutsche Welle has interviewed our 2025 RUTH Award winner. The interview was conducted in French by Konstanze Fischer for the Pulsations programme: Ezé comes from Burkina Faso, where the interview was broadcast.<br><br>Ezé Wendtoin : le micro pour faire danser et pour dénoncer\nDW: &#34;Le musicien burkinabè recevra en juillet le prestigieux prix allemand de la musique du monde. Une consécration, près de 10 ans après son installation en Allemagne.&#34;\n        \n    \n            \n\n\n\n",
 "time": {
 "date": "2025-05-07 14:52:00.000000",
 "timezone_type": 3,
 "timezone": "Europe/Berlin"
 }
 },
 */

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

/*
 {
 "id": 1,
 "title": "Heidecksburg",
 "title_en": "Castle"
 },
 */

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

/*
 {
 "id": 7,
 "start": {
 "date": "2025-07-06 13:00:00.000000",
 "timezone_type": 3,
 "timezone": "Europe/Berlin"
 },
 "day": "06.07.2025",
 "time": "13:00",
 "stage": 18,
 "artist": 33,
 "tags": [
 6
 ],
 "updated": {
 "date": "2025-04-03 14:25:00.000000",
 "timezone_type": 3,
 "timezone": "Europe/Berlin"
 }
 }
    */

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

/*
 {
 "id": 3,
 "title": "Große Bühne Heinepark",
 "title_en": "Big Stage Heinepark",
 "description": null,
 "description_en": null,
 "lat": 50.717267,
 "lon": 11.341624,
 "area": 2,
 "category": "comboticket",
 "map_number": 1
 },
 */

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

/*
 {
 "id": 4,
 "title": "RUTH",
 "title_en": "RUTH - World Music Award"
 },
    */

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
