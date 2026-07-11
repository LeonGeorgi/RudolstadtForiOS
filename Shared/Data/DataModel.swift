import Foundation
import CoreLocation

struct AIArtistData {
    let summaryDE: String?
    let summaryEN: String?
    let tagsDE: [String]
    let tagsEN: [String]
    let browseGenreIDs: [String]
    let flags: [String]

    var localizedSummary: String? {
        localizedSummary(locale: .current)
    }

    func localizedSummary(locale: Locale) -> String? {
        if locale.appLanguageCodeIdentifier == "de" {
            return summaryDE?.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return summaryEN?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var localizedTags: [String] {
        localizedTags(locale: .current)
    }

    func localizedTags(locale: Locale) -> [String] {
        if locale.appLanguageCodeIdentifier == "de" {
            return tagsDE
        } else {
            return tagsEN
        }
    }

    var hasContent: Bool {
        hasContent(locale: .current)
    }

    func hasContent(locale: Locale) -> Bool {
        let summary = localizedSummary(locale: locale)
        return summary?.isEmpty == false
            || !localizedTags(locale: locale).isEmpty
    }
}

struct Artist: Identifiable {
    private static let knownFestivalPlaceholderImageNames: Set<String> = [
        "aaaplatzhalter-jj406147npwtqwg.jpg",
        "aaaplatzhalter-eev4gvb1gk8384g.jpg",
    ]

    let id: Int
    let hiddenFromArtistList: Bool
    let artistType: ArtistType
    let someNumber: Int
    let name: String
    let countries: String
    let countryCodes: [String]
    let url: String?
    let facebookID: String?
    let youtubeID: String?
    let instagram: String?
    let descriptionGerman: String?
    let descriptionEnglish: String?
    let thumbImageUrlString: String
    let fullImageUrlString: String
    let ai: AIArtistData?

    var formattedName: String {
        formatString(name)
    }

    var formattedDescription: String? {
        formattedDescription(locale: .current)
    }

    func formattedDescription(locale: Locale) -> String? {
        let isGerman = locale.appLanguageCodeIdentifier == "de"
        let description = isGerman ? descriptionGerman : descriptionEnglish
        guard let description = description else {
            return nil
        }
        return formatString(description)
    }

    var thumbImageUrl: URL? {
        return Self.usableImageURL(from: thumbImageUrlString)
    }

    var fullImageUrl: URL? {
        return Self.usableImageURL(from: fullImageUrlString)
    }

    var videoUrl: URL? {
        guard let youtubeID = youtubeID else {
            return nil
        }
        if youtubeID.isEmpty {
            return nil
        }
        return URL(
            string: youtubeID.contains("http")
                ? youtubeID
                : "https://www.youtube.com/watch?v=\(youtubeID)"
        )
    }

    var facebookUrl: URL? {
        guard let facebookID = facebookID else {
            return nil
        }
        return URL(
            string: facebookID.contains("http")
                ? facebookID
                : "https://www.facebook.com/\(facebookID)"
        )
    }

    var instagramUrl: URL? {
        guard let instagram = instagram else {
            return nil
        }
        return URL(string: instagram)
    }

    func matches(searchTerm: String) -> Bool {
        matches(searchTerm: searchTerm, locale: .current)
    }

    func matches(searchTerm: String, locale: Locale) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        return normalize(string: name, locale: locale).contains(searchTerm)
            || (formattedDescription(locale: locale).map {
                normalize(string: $0, locale: locale)
            }?
            .contains(searchTerm) ?? false)
    }

    static let example = Artist(
        id: 0,
        hiddenFromArtistList: false,
        artistType: .stage,
        someNumber: 0,
        name: "Michael Jackson",
        countries: "USA",
        countryCodes: ["USA"],
        url: "http://www.michaeljackson.de/",
        facebookID: "michaeljackson",
        youtubeID: "QNJL6nfu__Q",
        instagram: "michaeljackson",
        descriptionGerman:
            "Michael Joseph Jackson (* 29. August 1958 in Gary, Indiana; † 25. Juni 2009 in Los Angeles, Kalifornien) war ein US-amerikanischer Sänger, Tänzer, Songwriter, Autor, Musik- und Filmproduzent sowie Musikmanager. <br> <br> Laut dem Guinness-Buch der Rekorde ist er der erfolgreichste Entertainer aller Zeiten und zugleich der Künstler, der weltweit die meisten Wohltätigkeitsorganisationen finanziell und repräsentativ unterstützte. Für sein Engagement wurde er mehrfach ausgezeichnet und zweimal für den Friedensnobelpreis nominiert. Aufgrund seiner Erfolge in der Musik wird er als „King of Pop“ bezeichnet.",
        descriptionEnglish:
            "Michael Jackson was an American singer, dancer, songwriter, and producer whose recordings and stagecraft reshaped global pop music. His work combined R&B, funk, soul, disco, rock, and theatrical choreography, turning live performance into a precise visual language. Albums like Off the Wall, Thriller, Bad, and Dangerous made him one of the most influential entertainers of the twentieth century.",
        thumbImageUrlString:
            "https://upload.wikimedia.org/wikipedia/commons/3/31/Michael_Jackson1_1988.jpg",
        fullImageUrlString:
            "https://upload.wikimedia.org/wikipedia/commons/3/31/Michael_Jackson1_1988.jpg",
        ai: AIArtistData(
            summaryDE:
                "Michael Jackson war ein US-amerikanischer Sänger, Tänzer und Musikproduzent. Er gilt als einer der erfolgreichsten Entertainer aller Zeiten.",
            summaryEN:
                "Michael Jackson was an American singer, dancer, and music producer. He is considered one of the most successful entertainers of all time.",
            tagsDE: ["Pop", "Rock", "Soul"],
            tagsEN: ["Pop", "Rock", "Soul"],
            browseGenreIDs: ["pop", "rock"],
            flags: ["🇺🇸"]
        )
    )

    private static func usableImageURL(from urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else {
            return nil
        }

        let fileName = (url.lastPathComponent.removingPercentEncoding
            ?? url.lastPathComponent)
            .lowercased()
        guard !knownFestivalPlaceholderImageNames.contains(fileName) else {
            return nil
        }

        return url
    }
}

enum ArtistType: Int, Identifiable, CaseIterable {
    var id: Int {
        self.rawValue
    }

    case stage = 1
    case dance = 2
    case street = 3
    case other = 4

    var okhslHue: Double {
        switch self {
        case .stage: return 0.00
        case .dance: return 0.25
        case .street: return 0.5
        case .other: return 0.75
        }
    }

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
        localizedName(locale: .current)
    }

    func localizedName(locale: Locale) -> String {
        if locale.appLanguageCodeIdentifier == "de" {
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
        localizedName(locale: .current)
    }

    func localizedName(locale: Locale) -> String {
        if locale.appLanguageCodeIdentifier == "de" {
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
    private static let walkingSpeedMetersPerMinute = 80.0
    private static let walkDistancesByStage = loadWalkDistancesByStage(
        fileName: "stage_walk_distances"
    )

    let id: Int
    let dayInJuly: Int
    let timeAsString: String
    let stage: Stage
    let artist: Artist
    let tag: Tag?

    var festivalHour: Int {
        festivalHour(calendar: .current)
    }

    func festivalHour(calendar: Calendar) -> Int {
        let hour = calendar.component(.hour, from: date(calendar: calendar))
        if hour < 5 {
            return hour + 24
        } else {
            return hour
        }
    }

    var startTimeInMinutes: Int {
        startTimeInMinutes(calendar: .current)
    }

    func startTimeInMinutes(calendar: Calendar) -> Int {
        let minutes = calendar.component(.minute, from: date(calendar: calendar))
        return festivalHour(calendar: calendar) * 60 + minutes
    }

    var festivalDay: Int {
        festivalDay(calendar: .current)
    }

    func festivalDay(calendar: Calendar) -> Int {
        if festivalHour(calendar: calendar) >= 24 {
            return dayInJuly - 1
        } else {
            return dayInJuly
        }
    }

    var secondaryInformation: String {
        secondaryInformation(locale: .current)
    }

    func secondaryInformation(locale: Locale) -> String {
        if let tag = tag {
            return "\(timeAsString) (\(tag.localizedName(locale: locale)))"
        } else {
            return timeAsString
        }
    }

    var shortInformation: String {
        shortInformation(locale: .current)
    }

    func shortInformation(locale: Locale) -> String {
        if let tag = tag {
            let stageName = stage.localizedName(locale: locale)
            let tagName = tag.localizedName(locale: locale)
            return "\(stageName) (\(tagName))"
        } else {
            return stage.localizedName(locale: locale)
        }
    }

    func matches(searchTerm: String) -> Bool {
        matches(
            searchTerm: searchTerm,
            calendar: .current,
            locale: .current
        )
    }

    func matches(
        searchTerm: String,
        calendar: Calendar,
        locale: Locale
    ) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        let normalizedArtistName = normalize(string: artist.name, locale: locale)
        let normalizedStageName = normalize(
            string: stage.localizedName(locale: locale),
            locale: locale
        )
        let normalizedTagName = tag.map {
            normalize(string: $0.localizedName(locale: locale), locale: locale)
        }
        let normalizedTimeAsString = normalize(
            string: timeAsString,
            locale: locale
        )
        let normalizedWeekDay = normalize(
            string: weekDay(calendar: calendar, locale: locale),
            locale: locale
        )
        let normalizedShortWeekDay = normalize(
            string: shortWeekDay(calendar: calendar, locale: locale),
            locale: locale
        )
        return searchTerm.split(separator: " ").allSatisfy { subTerm in
            normalizedArtistName.contains(subTerm)
                || normalizedStageName.contains(subTerm)
                || (normalizedTagName?.contains(subTerm) ?? false)
                || normalizedTimeAsString.contains(subTerm)
                || normalizedWeekDay.contains(subTerm)
                || normalizedShortWeekDay.contains(subTerm)
        }
    }

    var date: Date {
        date(calendar: .current)
    }

    func date(calendar: Calendar) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = dayInJuly
        //dateComponents.timeZone = TimeZone(abbreviation: "CEST")
        let splittedTime = timeAsString.split(separator: ":")
        dateComponents.hour = Int(splittedTime[0])
        dateComponents.minute = Int(splittedTime[1])

        guard let date = calendar.date(from: dateComponents) else {
            preconditionFailure("Could not create event date")
        }
        return date
    }

    func endDate(
        durationInMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        date(calendar: calendar).addingTimeInterval(
            Double(durationInMinutes) * 60
        )
    }

    var festivalDate: Date {
        festivalDate(calendar: .current)
    }

    func festivalDate(calendar: Calendar) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = DataStore.year
        dateComponents.month = 7
        dateComponents.day = festivalDay(calendar: calendar)
        //dateComponents.timeZone = TimeZone(abbreviation: "CEST")

        guard let date = calendar.date(from: dateComponents) else {
            preconditionFailure("Could not create festival date")
        }
        return date
    }

    var weekDay: String {
        weekDay(calendar: .current, locale: .current)
    }

    func weekDay(calendar: Calendar, locale: Locale) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = locale
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "EEEE"
        return dateFormatter.string(from: date(calendar: calendar))

    }

    var shortWeekDay: String {
        shortWeekDay(calendar: .current, locale: .current)
    }

    func shortWeekDay(calendar: Calendar, locale: Locale) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = locale
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "EE"
        return dateFormatter.string(from: date(calendar: calendar))

    }

    func intersects(with other: Event, event1Duration: Int, event2Duration: Int)
        -> Bool
    {
        intersects(
            with: other,
            event1Duration: event1Duration,
            event2Duration: event2Duration,
            maxAllowedMissedMinutes: 0
        )
    }

    func intersects(
        with other: Event,
        event1Duration: Int,
        event2Duration: Int,
        maxAllowedMissedMinutes: Int,
        arrivalBufferMinutes: Int = 0,
        calendar: Calendar = .current
    ) -> Bool {
        guard
            festivalDay(calendar: calendar)
                == other.festivalDay(calendar: calendar)
        else {
            return false
        }

        let firstStartsBeforeOrAtSecond =
            startTimeInMinutes(calendar: calendar)
            <= other.startTimeInMinutes(calendar: calendar)

        if firstStartsBeforeOrAtSecond {
            return missesTooMuchOfFollowingEvent(
                firstEvent: self,
                firstEventDuration: event1Duration,
                secondEvent: other,
                maxAllowedMissedMinutes: maxAllowedMissedMinutes,
                arrivalBufferMinutes: arrivalBufferMinutes,
                calendar: calendar
            )
        } else {
            return missesTooMuchOfFollowingEvent(
                firstEvent: other,
                firstEventDuration: event2Duration,
                secondEvent: self,
                maxAllowedMissedMinutes: maxAllowedMissedMinutes,
                arrivalBufferMinutes: arrivalBufferMinutes,
                calendar: calendar
            )
        }
    }

    private func missesTooMuchOfFollowingEvent(
        firstEvent: Event,
        firstEventDuration: Int,
        secondEvent: Event,
        maxAllowedMissedMinutes: Int,
        arrivalBufferMinutes: Int,
        calendar: Calendar
    ) -> Bool {
        let firstEventEnd =
            firstEvent.startTimeInMinutes(calendar: calendar)
            + firstEventDuration
        let transferMinutes = Self.walkingMinutes(
            from: firstEvent.stage,
            to: secondEvent.stage
        )
        let arrivalAtSecondEvent = firstEventEnd + transferMinutes
        let requiredArrivalTime =
            secondEvent.startTimeInMinutes(calendar: calendar)
            - arrivalBufferMinutes
        let missedMinutes = max(0, arrivalAtSecondEvent - requiredArrivalTime)
        return missedMinutes > maxAllowedMissedMinutes
    }

    private static func walkingMinutes(from firstStage: Stage, to secondStage: Stage) -> Int {
        if firstStage.id == secondStage.id {
            return 0
        }

        if let distanceInMeters = walkingDistanceInMeters(
            from: firstStage.id,
            to: secondStage.id
        ) {
            return max(1, Int(ceil(distanceInMeters / walkingSpeedMetersPerMinute)))
        }

        let firstLocation = CLLocation(
            latitude: firstStage.latitude,
            longitude: firstStage.longitude
        )
        let secondLocation = CLLocation(
            latitude: secondStage.latitude,
            longitude: secondStage.longitude
        )
        let airDistanceInMeters = secondLocation.distance(from: firstLocation)
        return max(1, Int(ceil(airDistanceInMeters / walkingSpeedMetersPerMinute)))
    }

    private static func walkingDistanceInMeters(from sourceStageID: Int, to targetStageID: Int)
        -> Double?
    {
        if let directDistance = walkDistancesByStage[sourceStageID]?[targetStageID] {
            return directDistance
        }
        if let inverseDistance = walkDistancesByStage[targetStageID]?[sourceStageID] {
            return inverseDistance
        }
        return nil
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

private func loadWalkDistancesByStage(fileName: String) -> [Int: [Int: Double]] {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
        print("Could not find file \(fileName).json in bundle")
        return [:]
    }

    do {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        return decoded.reduce(into: [Int: [Int: Double]]()) { partialResult, entry in
            guard let sourceStageId = Int(entry.key) else {
                return
            }
            let convertedTargets = entry.value.reduce(into: [Int: Double]()) {
                targetResult,
                targetEntry in
                guard let targetStageId = Int(targetEntry.key) else {
                    return
                }
                targetResult[targetStageId] = targetEntry.value
            }
            partialResult[sourceStageId] = convertedTargets
        }
    } catch {
        print("Error decoding \(fileName).json: \(error)")
        return [:]
    }
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
        isInLanguage(.current)
    }

    func isInLanguage(_ locale: Locale) -> Bool {
        let appIsInGerman = locale.appLanguageCodeIdentifier == "de"
        let languageIsGerman = languageCode == "de"
        return appIsInGerman == languageIsGerman
    }

    var formattedShortDescription: String {
        formatString(shortDescription)
    }

    var formattedLongDescription: String {
        formatString(longDescription)
    }

    var formattedContent: String {
        formatString(content)
    }

    func matches(searchTerm: String) -> Bool {
        matches(searchTerm: searchTerm, locale: .current)
    }

    func matches(searchTerm: String, locale: Locale) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        let normalizedDate = normalize(string: dateAsString, locale: locale)
        let normalizedTime = normalize(string: timeAsString, locale: locale)
        let normalizedShortDescription = normalize(
            string: shortDescription,
            locale: locale
        )
        let normalizedLongDescription = normalize(
            string: formattedLongDescription,
            locale: locale
        )
        let normalizedContent = normalize(
            string: formattedContent,
            locale: locale
        )
        return searchTerm.split(separator: " ").allSatisfy { subTerm in
            normalizedDate.contains(subTerm) || normalizedTime.contains(subTerm)
                || normalizedShortDescription.contains(subTerm)
                || normalizedLongDescription.contains(subTerm)
                || normalizedContent.contains(subTerm)
        }
    }

    static let example = NewsItem(
        id: 532,
        languageCode: "de",
        dateAsString: "05.10.2018",
        timeAsString: "12:24",
        shortDescription: "HINWEIS!",
        longDescription: "GefÃ¤lschte Mails im Namen des Festivals im Umlauf",
        content:
            "Man kennt es ja schon: StÃ¤ndig befinden sich eigenartige Zahlungsaufforderungen im Mailpostfach. Jetzt werden solche Mails auch mit Absendern verschickt, die vorgaukeln zum Rudolstadt-Festival zu gehÃ¶ren.<br>Eine ÃœberprÃ¼fung hat ergeben, dass aus unseren Systemen keine Daten abgefischt wurden. Falls Sie eine solche Mail erhalten haben, ist Ihre Adresse eher zufÃ¤llig in demselben Topf gelandet, aus dem wohl tausende Mails in unserem Namen verschickt wurden.<br>Darum die dringende WARNUNG vor Mails, die im Betreff Stichworte wie Rechnung, Zahlungsaufforderung, Merchandise, Bestellungseingang, Korrektur, Invoice u.Ã¤. enthalten! Auf KEINEN Fall mitgeschickte AnhÃ¤nge Ã¶ffnen! Ist das schon passiert, dann UNBEDINGT das eigene System mit einer entsprechenden Software auf SchÃ¤den scannen!<br>Sollten wider Erwarten doch weitere Spam-Mails kursieren, bitten wir um einen Hinweis. Danke dafÃ¼r und viele GrÃ¼ÃŸe vom Festival-Team!<br>"
    )
}

struct Stage: Identifiable, Hashable {
    static func == (lhs: Stage, rhs: Stage) -> Bool {
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
        localizedName(locale: .current)
    }

    func localizedName(locale: Locale) -> String {
        if locale.appLanguageCodeIdentifier == "de" {
            return germanName
        } else {
            return englishName
        }
    }

    var localizedDescription: String? {
        localizedDescription(locale: .current)
    }

    func localizedDescription(locale: Locale) -> String? {
        if locale.appLanguageCodeIdentifier == "de" {
            return germanDescription
        } else {
            return englishDescription
        }
    }

    func matches(searchTerm: String) -> Bool {
        matches(searchTerm: searchTerm, locale: .current)
    }

    func matches(searchTerm: String, locale: Locale) -> Bool {
        if searchTerm.isEmpty {
            return true
        }
        return normalize(
            string: localizedName(locale: locale),
            locale: locale
        ).contains(searchTerm)
            || normalize(
                string: area.localizedName(locale: locale),
                locale: locale
            ).contains(searchTerm)
            || (localizedDescription(locale: locale).map {
                normalize(string: $0, locale: locale)
            }?
            .contains(searchTerm) ?? false)
            || stageNumber.map {
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
    case unknown = 4

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
        localizedName(locale: .current)
    }

    func localizedName(locale: Locale) -> String {
        if locale.appLanguageCodeIdentifier == "de" {
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
        localizedName(locale: .current)
    }

    func localizedName(locale: Locale) -> String {
        if locale.appLanguageCodeIdentifier == "de" {
            return germanName
        } else {
            return englishName
        }
    }
    
    var isStageOrBuskers: Bool {
        return germanName == "Bühne" || germanName == "Straßenmusik"
    }

    static let example = Tag(
        id: 6,
        germanName: "Länderschwerpunkt",
        englishName: "Country Special"
    )
}
