//
//  Artist.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation

struct Artist: Identifiable {
    let id: Int
    let artistType: ArtistType
    let someNumber: Int
    let name: String
    let countries: String // TODO: split into list
    let url: String?
    let facebookID: String?
    let youtubeID: String?
    let imageName: String?
    let descriptionGerman: String?
    let descriptionEnglish: String?

    var formattedDescription: String? {
        return descriptionGerman?.replacingOccurrences(of: " ?<br> ?", with: "\n", options: [.regularExpression])
    }

    var thumbImageUrl: URL? {
        guard let imageName = imageName else {
            return nil
        }
        return URL(string: "\(DataUpdater.thumbUrl)/\(imageName)")
    }

    var fullImageUrl: URL? {
        guard let imageName = imageName else {
            return nil
        }
        return URL(string: "\(DataUpdater.fullImageUrl)/\(imageName)")
    }

    static let example = Artist(
            id: 0,
            artistType: .stage,
            someNumber: 0,
            name: "Michael Jackson",
            countries: "USA",
            url: "http://www.michaeljackson.de/",
            facebookID: "michaeljackson",
            youtubeID: "QNJL6nfu__Q",
            imageName: "Michael_Jackson.jpg",
            descriptionGerman: "Michael Joseph Jackson (* 29. August 1958 in Gary, Indiana; † 25. Juni 2009 in Los Angeles, Kalifornien) war ein US-amerikanischer Sänger, Tänzer, Songwriter, Autor, Musik- und Filmproduzent sowie Musikmanager. <br> <br> Laut dem Guinness-Buch der Rekorde ist er der erfolgreichste Entertainer aller Zeiten und zugleich der Künstler, der weltweit die meisten Wohltätigkeitsorganisationen finanziell und repräsentativ unterstützte. Für sein Engagement wurde er mehrfach ausgezeichnet und zweimal für den Friedensnobelpreis nominiert. Aufgrund seiner Erfolge in der Musik wird er als „King of Pop“ bezeichnet.",
            descriptionEnglish: "foo fooo foooo"
    )
}


enum ArtistType: Int, Identifiable, CaseIterable {
    var id: Int {
        self.rawValue
    }

    case stage = 1
    case dance = 2
    case street = 3
    case other = 4;

    var germanName: String {
        switch self {
        case .stage: return "Bühnenmusik"
        case .dance: return "Tanz"
        case .street: return "Straßenmusik"
        case .other: return "Sonstige"
        }
    }
}

struct Area: Identifiable, Hashable {
    let id: Int
    let germanName: String
    let englishName: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let example = Area(
            id: 3,
            germanName: "Heinepark (City Park)",
            englishName: "City Park"
    )
}

struct Event: Identifiable {
    let id: Int
    let dayInJuly: Int
    let timeAsString: String
    let stage: Stage
    let artist: Artist
    let tag: Tag?

    var festivalHour: Int {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 5 {
            return hour + 24
        } else {
            return hour
        }
    }

    var startTimeInMinutes: Int {
        let minutes = Calendar.current.component(.minute, from: date)
        return festivalHour * 60 + minutes
    }

    var endTimeInMinutes: Int {
        startTimeInMinutes + 60
    }

    var festivalDay: Int {
        if festivalHour >= 24 {
            return dayInJuly - 1
        } else {
            return dayInJuly
        }
    }

    var secondaryInformation: String {
        if let tag = tag {
            return "\(timeAsString) (\(tag.germanName))"
        } else {
            return timeAsString
        }
    }

    var shortInformation: String {
        if let tag = tag {
            return "\(stage.germanName) (\(tag.germanName))"
        } else {
            return stage.germanName
        }
    }

    var date: Date {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = dayInJuly
        dateComponents.timeZone = TimeZone(abbreviation: "CEST")
        let splittedTime = timeAsString.split(separator: ":")
        dateComponents.hour = Int(splittedTime[0])
        dateComponents.minute = Int(splittedTime[1])

        let userCalendar = Calendar.current // user calendar
        return userCalendar.date(from: dateComponents)!
    }

    var festivalDate: Date {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = festivalDay
        dateComponents.timeZone = TimeZone(abbreviation: "CEST")

        let userCalendar = Calendar.current // user calendar
        return userCalendar.date(from: dateComponents)!
    }

    var weekDay: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: date)

    }

    var shortWeekDay: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EE"
        return dateFormatter.string(from: date)

    }

    func isAtDay(day: Int) -> Bool {
        return day == dayInJuly && timeAsString >= "05" || day == dayInJuly - 1 && timeAsString < "05"
    }

    static let example = Event(
            id: 1,
            dayInJuly: 6,
            timeAsString: "17:00",
            stage: .example,
            artist: .example,
            tag: .example
    )
}

struct NewsItem: Identifiable {
    let id: Int
    let languageCode: String
    let dateAsString: String
    let timeAsString: String
    let shortDescription: String
    let longDescription: String
    let content: String

    var formattedLongDescription: String {
        return longDescription.replacingOccurrences(of: " ?<br> ?", with: "\n", options: [.regularExpression])
                .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var formattedContent: String {
        return content.replacingOccurrences(of: " ?<br> ?", with: "\n", options: [.regularExpression])
    }

    static let example = NewsItem(
            id: 532,
            languageCode: "de",
            dateAsString: "05.10.2018",
            timeAsString: "12:24",
            shortDescription: "HINWEIS!",
            longDescription: "GefÃ¤lschte Mails im Namen des Festivals im Umlauf",
            content: "Man kennt es ja schon: StÃ¤ndig befinden sich eigenartige Zahlungsaufforderungen im Mailpostfach. Jetzt werden solche Mails auch mit Absendern verschickt, die vorgaukeln zum Rudolstadt-Festival zu gehÃ¶ren.<br>Eine ÃœberprÃ¼fung hat ergeben, dass aus unseren Systemen keine Daten abgefischt wurden. Falls Sie eine solche Mail erhalten haben, ist Ihre Adresse eher zufÃ¤llig in demselben Topf gelandet, aus dem wohl tausende Mails in unserem Namen verschickt wurden.<br>Darum die dringende WARNUNG vor Mails, die im Betreff Stichworte wie Rechnung, Zahlungsaufforderung, Merchandise, Bestellungseingang, Korrektur, Invoice u.Ã¤. enthalten! Auf KEINEN Fall mitgeschickte AnhÃ¤nge Ã¶ffnen! Ist das schon passiert, dann UNBEDINGT das eigene System mit einer entsprechenden Software auf SchÃ¤den scannen!<br>Sollten wider Erwarten doch weitere Spam-Mails kursieren, bitten wir um einen Hinweis. Danke dafÃ¼r und viele GrÃ¼ÃŸe vom Festival-Team!<br>"
    )
}

struct Stage: Identifiable, Hashable {
    static func ==(lhs: Stage, rhs: Stage) -> Bool {
        return lhs.id == rhs.id
    }

    let id: Int
    let germanName: String
    let englishName: String
    let germanDescription: String?
    let englishDescription: String?
    let stageNumber: Int?
    let latitude: Double
    let longitude: Double
    let area: Area
    let unknownNumber: Int?

    static let example = Stage(
            id: 24,
            germanName: "Große Bühne Heinepark",
            englishName: "Große Bühne Heinepark",
            germanDescription: "Große Bühne Heinepark",
            englishDescription: "Große Bühne Heinepark",
            stageNumber: 6,
            latitude: 50.717028,
            longitude: 11.341074,
            area: .example,
            unknownNumber: 1)

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Tag: Identifiable {
    let id: Int
    let germanName: String
    let englishName: String

    static let example = Tag(
            id: 6,
            germanName: "Länderschwerpunkt",
            englishName: "Country Special"
    )
}

