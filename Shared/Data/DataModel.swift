import Foundation

struct Artist: Identifiable {
    let id: Int
    let artistType: ArtistType
    let someNumber: Int
    let name: String
    let countries: String
    let url: String?
    let facebookID: String?
    let youtubeID: String?
    let imageName: String?
    let descriptionGerman: String?
    let descriptionEnglish: String?

    var formattedDescription: String? {
        let isGerman = Locale.current.languageCode == "de"
        return (isGerman ? descriptionGerman : descriptionEnglish)?.replacingOccurrences(
                of: " ?<br> ?",
                with: "\n", options: [.regularExpression]
        )
    }

    var thumbImageUrl: URL? {
        guard var imageName = imageName else {
            return nil
        }
        imageName = imageName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? imageName

        if artistType == .street {
            return URL(string: "\(ImageUrlUtil.streetMusicThumbUrl)/\(imageName)")
        }

        return URL(string: "\(ImageUrlUtil.thumbUrl)/\(imageName)")
    }

    var fullImageUrl: URL? {
        guard var imageName = imageName else {
            return nil
        }
        imageName = imageName.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? imageName
        if artistType == .street {
            return URL(string: "\(ImageUrlUtil.streetMusicFullUrl)/\(imageName)")
        }
        return URL(string: "\(ImageUrlUtil.fullImageUrl)/\(imageName)")
    }


    func matches(searchTerm: String) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        return normalize(string: name).contains(searchTerm) ||
                (formattedDescription.map {
                            normalize(string: $0)
                        }?
                        .contains(searchTerm) ?? false)
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

    var englishName: String {
        switch self {
        case .stage: return "Stage music"
        case .dance: return "Dance"
        case .street: return "Street music"
        case .other: return "Other"
        }
    }


    var localizedName: String {
        if Locale.current.languageCode == "de" {
            return germanName
        } else {
            return englishName
        }
    }
}

struct Area: Identifiable, Hashable {
    let id: Int
    let germanName: String
    let englishName: String

    var localizedName: String {
        if Locale.current.languageCode == "de" {
            return germanName
        } else {
            return englishName
        }
    }

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

    var festivalDay: Int {
        if festivalHour >= 24 {
            return dayInJuly - 1
        } else {
            return dayInJuly
        }
    }

    var secondaryInformation: String {
        if let tag = tag {
            return "\(timeAsString) (\(tag.localizedName))"
        } else {
            return timeAsString
        }
    }

    var shortInformation: String {
        if let tag = tag {
            return "\(stage.localizedName) (\(tag.localizedName))"
        } else {
            return stage.localizedName
        }
    }

    func matches(searchTerm: String) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        let normalizedArtistName = normalize(string: artist.name)
        let normalizedStageName = normalize(string: stage.localizedName)
        let normalizedTagName = tag.map {
            normalize(string: $0.localizedName)
        }
        let normalizedTimeAsString = normalize(string: timeAsString)
        let normalizedWeekDay = normalize(string: weekDay)
        let normalizedShortWeekDay = normalize(string: shortWeekDay)
        return searchTerm.split(separator: " ").allSatisfy { subTerm in
            normalizedArtistName.contains(subTerm) ||
                    normalizedStageName.contains(subTerm) ||
                    (normalizedTagName?.contains(subTerm) ?? false) ||
                    normalizedTimeAsString.contains(subTerm) ||
                    normalizedWeekDay.contains(subTerm) ||
                    normalizedShortWeekDay.contains(subTerm)
        }
    }

    var date: Date {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = dayInJuly
        //dateComponents.timeZone = TimeZone(abbreviation: "CEST")
        let splittedTime = timeAsString.split(separator: ":")
        dateComponents.hour = Int(splittedTime[0])
        dateComponents.minute = Int(splittedTime[1])

        let userCalendar = Calendar.current // user calendar
        return userCalendar.date(from: dateComponents)!
    }
    
    func endDate(durationInMinutes: Int) -> Date {
        date.addingTimeInterval(Double(durationInMinutes) * 60)
    }

    var festivalDate: Date {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = festivalDay
        //dateComponents.timeZone = TimeZone(abbreviation: "CEST")

        let userCalendar = Calendar.current
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

    func intersects(with other: Event, event1Duration: Int, event2Duration: Int) -> Bool {
        festivalDay == other.festivalDay &&
                !(startTimeInMinutes > other.startTimeInMinutes + event2Duration || startTimeInMinutes + event1Duration < other.startTimeInMinutes)
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

    var isInCurrentLanguage: Bool {
        let appIsInGerman = Locale.current.languageCode == "de"
        let languageIsGerman = languageCode == "de"
        return appIsInGerman == languageIsGerman
    }

    var formattedLongDescription: String {
        NewsItem.format(string: longDescription)
    }

    var formattedContent: String {
        NewsItem.format(string: content)
    }

    func matches(searchTerm: String) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        let normalizedDate = normalize(string: dateAsString)
        let normalizedTime = normalize(string: timeAsString)
        let normalizedShortDescription = normalize(string: shortDescription)
        let normalizedLongDescription = normalize(string: formattedLongDescription)
        let normalizedContent = normalize(string: formattedContent)
        return searchTerm.split(separator: " ").allSatisfy { subTerm in
            normalizedDate.contains(subTerm) ||
                    normalizedTime.contains(subTerm) ||
                    normalizedShortDescription.contains(subTerm) ||
                    normalizedLongDescription.contains(subTerm) ||
                    normalizedContent.contains(subTerm)
        }
    }


    static func format(string: String) -> String {
        let stringWithNewLines = string.replacingOccurrences(of: " ?<br> ?", with: "\n", options: [.regularExpression])
                .replacingOccurrences(of: "&#39;", with: "'")
                .replacingOccurrences(of: "&#34;", with: "\"")
                .trimmingCharacters(in: .whitespacesAndNewlines)

        
        return stringWithNewLines
        /*guard let data = stringWithNewLines.data(using: .utf8) else {
            return stringWithNewLines
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let result = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return stringWithNewLines
        }

        return result.string*/
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
        lhs.id == rhs.id
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
    let stageType: StageType

    var localizedName: String {
        if Locale.current.languageCode == "de" {
            return germanName
        } else {
            return englishName
        }
    }

    var localizedDescription: String? {
        if Locale.current.languageCode == "de" {
            return germanDescription
        } else {
            return englishDescription
        }
    }

    func matches(searchTerm: String) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        return normalize(string: localizedName).contains(searchTerm) ||
                normalize(string: area.localizedName).contains(searchTerm) ||
                (localizedDescription.map {
                            normalize(string: $0)
                        }?
                        .contains(searchTerm) ?? false) ||
                stageNumber.map {
                            String($0)
                        }?
                        .contains(searchTerm) ?? false
    }

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
            stageType: .festivalTicket
    )

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


enum StageType: Int, Identifiable, CaseIterable {
    var id: Int {
        self.rawValue
    }

    case festivalTicket = 1
    case festivalAndDayTicket = 2
    case other = 3
    case unknown = 4;

    var germanName: String {
        switch self {
        case .festivalTicket: return "Dauerkarte"
        case .festivalAndDayTicket: return "Dauer- und Tageskarte"
        case .other: return "Sonstige"
        case .unknown: return "Unbekannt"
        }
    }

    var englishName: String {
        switch self {
        case .festivalTicket: return "Festival ticket"
        case .festivalAndDayTicket: return "Day and festival ticket"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }


    var localizedName: String {
        if Locale.current.languageCode == "de" {
            return germanName
        } else {
            return englishName
        }
    }
}

struct Tag: Identifiable {
    let id: Int
    let germanName: String
    let englishName: String

    var localizedName: String {
        if Locale.current.languageCode == "de" {
            return germanName
        } else {
            return englishName
        }
    }

    static let example = Tag(
            id: 6,
            germanName: "Länderschwerpunkt",
            englishName: "Country Special"
    )
}

