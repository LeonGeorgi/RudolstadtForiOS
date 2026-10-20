import Foundation

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
    var isMetadataAvailable = true

    func displayName(locale: Locale = .current) -> String {
        isMetadataAvailable
            ? name
            : (locale.appLanguageCodeIdentifier == "de"
                ? "Künstler unbekannt" : "Artist unknown")
    }

    static func missing(id: Int) -> Artist {
        Artist(
            id: id, hiddenFromArtistList: true, artistType: .other, someNumber: 0,
            name: "", countries: "", countryCodes: [], url: nil, facebookID: nil,
            youtubeID: nil, instagram: nil, descriptionGerman: nil, descriptionEnglish: nil,
            thumbImageUrlString: "", fullImageUrlString: "", ai: nil, isMetadataAvailable: false)
    }

    var formattedName: String {
        formatString(displayName())
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
    let id: Int
    let startDate: Date?
    // A known calendar day is distinct from a known instant.
    let knownDate: Date?
    let stage: Stage
    let artist: Artist
    let tags: [Tag]

    var tag: Tag? { tags.first }

    init(
        id: Int, startDate: Date?, knownDate: Date?, stage: Stage, artist: Artist,
        tag: Tag? = nil, tags: [Tag]? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.knownDate =
            startDate.map { FestivalDateUtilities.festivalCalendar.startOfDay(for: $0) }
            ?? knownDate
        self.stage = stage
        self.artist = artist
        self.tags = tags ?? tag.map { [$0] } ?? []
    }

    init(id: Int, dayInJuly: Int, timeAsString: String, stage: Stage, artist: Artist, tag: Tag?) {
        let day = String(format: "%02d.07.%04d", dayInJuly, FestivalConfiguration.year)
        let knownDate = FestivalDateUtilities.festivalDate(day, format: "dd.MM.yyyy")
        let parts = timeAsString.split(separator: ":").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let time: String
        if parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) {
            time = String(format: "%02d:%02d", hour, minute)
        } else {
            time = ""
        }
        self.init(
            id: id,
            startDate: FestivalDateUtilities.festivalDate(
                day + " " + time, format: "dd.MM.yyyy HH:mm"
            ), knownDate: knownDate, stage: stage, artist: artist, tag: tag)
    }

    var hasCompleteMetadata: Bool {
        startDate != nil && artist.isMetadataAvailable && stage.isMetadataAvailable
            && stage.hasLocation
            && stage.stageType != .unknown
    }

    var dayInJuly: Int {
        knownDate.map { FestivalDateUtilities.festivalCalendar.component(.day, from: $0) } ?? 0
    }

    var timeAsString: String {
        if let startDate {
            return FestivalDateUtilities.format(
                startDate, pattern: "HH:mm", locale: Locale(identifier: "en_US_POSIX"))
        }
        return NSLocalizedString(
            knownDate == nil ? "event.date.unknown" : "event.time.unknown", comment: "")
    }

    var festivalHour: Int { festivalHour(calendar: FestivalDateUtilities.festivalCalendar) }
    func festivalHour(calendar: Calendar) -> Int {
        guard let startDate else { return 0 }
        let hour = FestivalDateUtilities.festivalCalendar.component(.hour, from: startDate)
        return hour < 5 ? hour + 24 : hour
    }

    var startTimeInMinutes: Int {
        startTimeInMinutes(calendar: FestivalDateUtilities.festivalCalendar)
    }
    func startTimeInMinutes(calendar: Calendar) -> Int {
        guard let startDate else { return 0 }
        return festivalHour * 60
            + FestivalDateUtilities.festivalCalendar.component(.minute, from: startDate)
    }

    // Zero means that no festival day is known; it must not become a day tab.
    var festivalDay: Int { festivalDay(calendar: FestivalDateUtilities.festivalCalendar) }
    func festivalDay(calendar: Calendar) -> Int {
        guard knownDate != nil else { return 0 }
        return startDate != nil && festivalHour >= 24 ? dayInJuly - 1 : dayInJuly
    }

    static func precedes(_ first: Event, _ second: Event) -> Bool {
        switch (first.startDate, second.startDate) {
        case let (a?, b?) where a != b: return a < b
        case (_?, nil): return true
        case (nil, _?): return false
        default:
            switch (first.knownDate, second.knownDate) {
            case let (a?, b?) where a != b: return a < b
            case (_?, nil): return true
            case (nil, _?): return false
            default: return first.id < second.id
            }
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

    var date: Date? { startDate }
    func date(calendar: Calendar) -> Date? { startDate }

    func endDate(durationInMinutes: Int, calendar: Calendar = .current) -> Date? {
        startDate?.addingTimeInterval(Double(max(0, durationInMinutes)) * 60)
    }

    var festivalDate: Date? { festivalDate(calendar: FestivalDateUtilities.festivalCalendar) }
    func festivalDate(calendar: Calendar) -> Date? {
        guard let knownDate else { return nil }
        return FestivalDateUtilities.festivalCalendar.date(
            byAdding: .day,
            value: startDate != nil && festivalHour >= 24 ? -1 : 0, to: knownDate)
    }

    var weekDay: String { weekDay(calendar: .current, locale: .current) }
    func weekDay(calendar: Calendar, locale: Locale) -> String {
        guard let knownDate else { return NSLocalizedString("event.date.unknown", comment: "") }
        return FestivalDateUtilities.format(knownDate, pattern: "EEEE", locale: locale)
    }

    var shortWeekDay: String { shortWeekDay(calendar: .current, locale: .current) }
    func shortWeekDay(calendar: Calendar, locale: Locale) -> String {
        guard let knownDate else { return NSLocalizedString("event.date.unknown", comment: "") }
        return FestivalDateUtilities.format(knownDate, pattern: "EE", locale: locale)
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
        isInLanguage(.current)
    }

    func isInLanguage(_ locale: Locale) -> Bool {
        languageCode == (locale.appLanguageCodeIdentifier == "de" ? "de" : "en")
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
    var isMetadataAvailable = true

    var hasLocation: Bool {
        isMetadataAvailable && latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && (latitude != 0 || longitude != 0) // The festival API uses 0,0 for missing locations.
    }

    static func missing(id: Int) -> Stage {
        Stage(
            id: id, germanName: "Bühne unbekannt", englishName: "Stage unknown",
            germanDescription: nil, englishDescription: nil, stageNumber: nil,
            latitude: .nan, longitude: .nan,
            area: Area(id: 0, germanName: "Bereich unbekannt", englishName: "Area unknown"),
            stageType: .unknown, isMetadataAvailable: false)
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
