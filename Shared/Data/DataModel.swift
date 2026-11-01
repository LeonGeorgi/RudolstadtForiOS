import Foundation

/// The single program representation used by source adapters, calculations and views.
struct FestivalData: Sendable {
    var artists: [Artist]
    var areas: [Area]
    var stages: [Stage]
    var events: [Event]
    var omittedRecordCount = 0
    var artistSimilarities: ArtistSimilarityCatalog? = nil
    var walkingDistanceMatrix: StageWalkingDistanceMatrix = .empty
    var festivalYear: Int = FestivalConfiguration.year
    var sitePlan: FestivalSitePlan? = nil
    var days: [FestivalDay] = []
    var identity: FestivalIdentity? = nil
    var provenance: FestivalDataProvenance? = nil
    var features = FestivalFeatures()
    var metadata: FestivalMetadata? = nil

    var eventDurations: [Int: Int] {
        Dictionary(uniqueKeysWithValues: events.compactMap { event in
            event.durationMinutes.map { (event.id, $0) }
        })
    }

    var festivalMonth: Int {
        events.compactMap(\.knownDate).min().map {
            FestivalDateUtilities.festivalCalendar.component(.month, from: $0)
        } ?? 7
    }
}

struct AIArtistData: Sendable {
    let summaryDE: String?
    let summaryEN: String?
    let tagsDE: [String]
    let tagsEN: [String]
    let browseGenreIDs: [String]
    let flags: [String]

}

/// An artist's source-independent content. Views and source adapters share these values.
struct Artist: Identifiable, Sendable {
    let id: Int
    let hiddenFromArtistList: Bool
    let name: String
    var details: ArtistDetails
    var localizedSummaries: [LanguageTag: ArtistSummary] = [:]
    var groupIDs: [String: Set<String>] = [:]
    var defaultContentLanguage: LanguageTag? = nil
    var isMetadataAvailable = true
    private var fallbackCountryFlags: [String] = []

    var artistType: ArtistType {
        groupIDs["artist-kind"]?.compactMap(Int.init).first.flatMap(ArtistType.init(rawValue:)) ?? .other
    }
    var countries: String { details.countryDescription?.resolved(defaultLanguage: defaultContentLanguage) ?? "" }
    var countryCodes: [String] { details.countryCodes }
    var localizedDescriptions: FestivalContent? { details.descriptions }
    var localizedKeywords: [LanguageTag: [String]] { details.keywords }
    var musicPreview: FestivalMusicPreview {
        get { details.musicPreview }
        set { details.musicPreview = newValue }
    }
    var additionalLinks: [FestivalLink] {
        get { details.links }
        set { details.links = newValue }
    }
    var thumbImageUrlString: String { details.thumbnailURL?.absoluteString ?? "" }
    var fullImageUrlString: String { details.imageURL?.absoluteString ?? "" }

    init(id: Int, name: String, isListed: Bool = true, details: ArtistDetails? = nil,
         groupIDs: [String: Set<String>] = [:], summaries: [LanguageTag: ArtistSummary] = [:]) {
        self.id = id
        self.name = name
        self.hiddenFromArtistList = !isListed
        self.details = details ?? ArtistDetails(descriptions: FestivalContent(text: bilingual(nil, nil), format: .plainText),
            thumbnailURL: nil, imageURL: nil, countryCodes: [], links: [])
        self.groupIDs = groupIDs
        self.localizedSummaries = summaries
        self.isMetadataAvailable = !name.isEmpty
    }

    init(id: Int, hiddenFromArtistList: Bool, artistType: ArtistType, name: String,
         countries: String, countryCodes: [String], url: String?, facebookID: String?,
         youtubeID: String?, instagram: String?, descriptionGerman: String?, descriptionEnglish: String?,
         thumbImageUrlString: String, fullImageUrlString: String, ai: AIArtistData?,
         isMetadataAvailable: Bool = true) {
        self.id = id
        self.hiddenFromArtistList = hiddenFromArtistList
        self.name = name
        self.isMetadataAvailable = isMetadataAvailable
        self.fallbackCountryFlags = ai?.flags ?? []
        self.details = ArtistDetails(
            descriptions: FestivalContent(text: bilingual(descriptionGerman, descriptionEnglish), format: .html),
            thumbnailURL: Self.usableImageURL(from: thumbImageUrlString), imageURL: Self.usableImageURL(from: fullImageUrlString),
            countryCodes: countryCodes, links: [], countryDescription: bilingual(countries, countries),
            keywords: [LanguageTag("de"): ai?.tagsDE ?? [], LanguageTag("en"): ai?.tagsEN ?? []])
        groupIDs = ["artist-kind": [String(artistType.rawValue)], "genre": Set(ai?.browseGenreIDs ?? [])]
        let summaries = bilingual(ai?.summaryDE, ai?.summaryEN)
        localizedSummaries = Dictionary(uniqueKeysWithValues: summaries.values.map { language, text in
            (language, ArtistSummary(text: text, language: language, origin: .aiGenerated, sourceURL: nil))
        })
        func socialURL(_ value: String?, prefix: String) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return value.contains("http") ? value : prefix + value
        }
        additionalLinks = [("website", url), ("facebook", socialURL(facebookID, prefix: "https://www.facebook.com/")),
            ("youtube", socialURL(youtubeID, prefix: "https://www.youtube.com/watch?v=")), ("instagram", instagram)]
            .compactMap { id, value in
                guard let value, !value.isEmpty, let url = URL(string: value), url.scheme != nil else { return nil }
                return FestivalLink(id: id, title: LocalizedText(values: [LanguageTag("en"): id]),
                                    destination: url, openingMode: .externalBrowser)
            }
    }

    private func link(_ id: String) -> URL? { additionalLinks.first { $0.id == id }?.destination }
    var url: String? { link("website")?.absoluteString }
    var instagram: String? { link("instagram")?.absoluteString }
    var descriptionGerman: String? { localizedDescriptions?.text.text(in: LanguageTag("de")) }
    var descriptionEnglish: String? { localizedDescriptions?.text.text(in: LanguageTag("en")) }

    func displayName(locale: Locale = .current) -> String {
        isMetadataAvailable
            ? name
            : (locale.appLanguageCodeIdentifier == "de"
                ? "Künstler unbekannt" : "Artist unknown")
    }

    static func missing(id: Int) -> Artist {
        Artist(
            id: id, hiddenFromArtistList: true, artistType: .other, name: "", countries: "", countryCodes: [], url: nil, facebookID: nil,
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
        if let localizedDescriptions { return formatString(localizedDescriptions.text.resolved(locale: locale, defaultLanguage: defaultContentLanguage)) }
        return nil
    }

    var thumbImageUrl: URL? {
        details.thumbnailURL
    }

    var fullImageUrl: URL? {
        details.imageURL
    }

    var videoUrl: URL? { link("youtube") }
    var facebookUrl: URL? { link("facebook") }
    var instagramUrl: URL? { link("instagram") }

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

struct Area: Identifiable, Hashable, Sendable {
    let id: Int
    let name: LocalizedText

    init(id: Int, name: LocalizedText) {
        self.id = id
        self.name = name
    }

    init(id: Int, germanName: String, englishName: String) {
        self.init(id: id, name: bilingual(germanName, englishName))
    }

    var germanName: String { name.text(in: LanguageTag("de")) ?? "" }
    var englishName: String { name.text(in: LanguageTag("en")) ?? "" }
    var localizedName: String { localizedName(locale: .current) }
    func localizedName(locale: Locale) -> String { name.resolved(locale: locale) }

    static func == (lhs: Area, rhs: Area) -> Bool { lhs.id == rhs.id && lhs.name.values == rhs.name.values }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let example = Area(id: 3, germanName: "Heinepark (City Park)", englishName: "City Park")
}

struct Event: Identifiable, Sendable {
    var resolvedDuration: FestivalEventDuration? = nil
    var programDay: FestivalDay? = nil
    var timeZone: TimeZone = FestivalConfiguration.timeZone

    var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = timeZone
        return result
    }

    let id: Int
    let startDate: Date?
    // A known calendar day is distinct from a known instant.
    let knownDate: Date?
    var stage: Stage
    var artist: Artist
    var tags: [Tag]
    var durationMinutes: Int? { resolvedDuration?.minutes }

    var artistID: Int { artist.id }
    var placeID: FestivalPlaceID? { stage.isMetadataAvailable ? stage.id : nil }
    var festivalDayID: FestivalDay.ID? { programDay?.id }
    var duration: FestivalEventDuration? { resolvedDuration }
    var tag: Tag? { tags.first }

    init(
        id: Int, startDate: Date?, knownDate: Date?, stage: Stage, artist: Artist,
        tag: Tag? = nil, tags: [Tag]? = nil, durationMinutes: Int? = nil,
        timeZone: TimeZone = FestivalConfiguration.timeZone
    ) {
        self.id = id
        self.timeZone = timeZone
        self.startDate = startDate
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.knownDate =
            startDate.map { calendar.startOfDay(for: $0) }
            ?? knownDate
        self.stage = stage
        self.artist = artist
        self.tags = tags ?? tag.map { [$0] } ?? []
        self.resolvedDuration = durationMinutes.map { FestivalEventDuration(minutes: $0, isEstimated: false) }
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
        if programDay != nil {
            return startDate != nil && artist.isMetadataAvailable && stage.isMetadataAvailable && resolvedDuration != nil
        }
        return startDate != nil && artist.isMetadataAvailable && stage.isMetadataAvailable
            && stage.hasLocation && !stage.locationIsApproximate
            && stage.stageType != .unknown
    }

    var dayInJuly: Int {
        programDay?.date.day ?? knownDate.map { self.calendar.component(.day, from: $0) } ?? 0
    }

    var timeAsString: String {
        if let startDate {
            return formattedDate(startDate, pattern: "HH:mm", locale: Locale(identifier: "en_US_POSIX"))
        }
        return NSLocalizedString(
            knownDate == nil ? "event.date.unknown" : "event.time.unknown", comment: "")
    }

    var festivalHour: Int { festivalHour(calendar: self.calendar) }
    func festivalHour(calendar: Calendar) -> Int {
        guard let startDate else { return 0 }
        if let programDay {
            let start = self.calendar.startOfDay(for: programDay.interval.start)
            return Int(startDate.timeIntervalSince(start) / 3600)
        }
        let hour = self.calendar.component(.hour, from: startDate)
        return hour < 5 ? hour + 24 : hour
    }

    var startTimeInMinutes: Int {
        startTimeInMinutes(calendar: self.calendar)
    }
    func startTimeInMinutes(calendar: Calendar) -> Int {
        guard let startDate else { return 0 }
        return festivalHour * 60
            + self.calendar.component(.minute, from: startDate)
    }

    // Zero means that no festival day is known; it must not become a day tab.
    var festivalDay: Int { festivalDay(calendar: self.calendar) }
    func festivalDay(calendar: Calendar) -> Int {
        if let programDay { return programDay.date.day }
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

    var festivalDate: Date? { festivalDate(calendar: self.calendar) }
    func festivalDate(calendar: Calendar) -> Date? {
        if let programDay { return programDay.date.date(in: self.calendar) }
        guard let knownDate else { return nil }
        return self.calendar.date(
            byAdding: .day,
            value: startDate != nil && festivalHour >= 24 ? -1 : 0, to: knownDate)
    }

    var weekDay: String { weekDay(calendar: .current, locale: .current) }
    func weekDay(calendar: Calendar, locale: Locale) -> String {
        guard let knownDate else { return NSLocalizedString("event.date.unknown", comment: "") }
        return formattedDate(knownDate, pattern: "EEEE", locale: locale)
    }

    var shortWeekDay: String { shortWeekDay(calendar: .current, locale: .current) }
    func shortWeekDay(calendar: Calendar, locale: Locale) -> String {
        guard let knownDate else { return NSLocalizedString("event.date.unknown", comment: "") }
        return formattedDate(knownDate, pattern: "EE", locale: locale)
    }

    private func formattedDate(_ date: Date, pattern: String, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.string(from: date)
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

struct Stage: Identifiable, Hashable, Sendable {
    static func == (lhs: Stage, rhs: Stage) -> Bool {
        lhs.id == rhs.id
    }

    typealias ID = FestivalPlaceID
    let id: ID
    var germanName: String { localizedNames?.text(in: LanguageTag("de")) ?? "" }
    var englishName: String { localizedNames?.text(in: LanguageTag("en")) ?? "" }
    var germanDescription: String? { localizedDescriptions?.text.text(in: LanguageTag("de")) }
    var englishDescription: String? { localizedDescriptions?.text.text(in: LanguageTag("en")) }
    var stageNumber: Int? { stageCode.flatMap(Int.init) }
    var latitude: Double
    var longitude: Double
    var area: Area?
    let stageType: StageType
    var defaultContentLanguage: LanguageTag? = nil
    var isMetadataAvailable = true
    var locationIsApproximate = false
    var stageCode: String? = nil
    var localizedNames: LocalizedText? = nil
    var localizedDescriptions: FestivalContent? = nil
    var admissionCategory: FestivalAdmissionCategory? = nil
    var mapCategory: MapCategory? = nil

    var name: LocalizedText { localizedNames ?? bilingual(nil, nil) }
    var reference: String? { displayCode }

    var displayCode: String? {
        stageCode
    }

    static func precedes(_ lhs: Stage, _ rhs: Stage) -> Bool {
        switch (lhs.displayCode, rhs.displayCode) {
        case let (left?, right?) where left != right:
            return left.compare(right, options: .numeric, locale: Locale(identifier: "en_US_POSIX")) == .orderedAscending
        case (_?, nil): return true
        case (nil, _?): return false
        default: return lhs.id < rhs.id
        }
    }

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
        localizedNames?.resolved(locale: locale, defaultLanguage: defaultContentLanguage) ?? ""
    }

    var localizedDescription: String? {
        localizedDescription(locale: .current)
    }

    func localizedDescription(locale: Locale) -> String? {
        if let localizedDescriptions { return localizedDescriptions.text.resolved(locale: locale, defaultLanguage: defaultContentLanguage) }
        return nil
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
                string: (area?.localizedName(locale: locale) ?? ""),
                locale: locale
            ).contains(searchTerm)
            || (localizedDescription(locale: locale).map {
                normalize(string: $0, locale: locale)
            }?
            .contains(searchTerm) ?? false)
            || displayCode.map { normalize(string: $0, locale: locale) }?
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

struct Tag: Identifiable, Sendable {
    let id: String
    var title: LocalizedText
    var introduction: LocalizedText? = nil
    var isDiscoverable = true
    var showsOnTimeline = true

    init(id: String, title: LocalizedText, introduction: LocalizedText? = nil,
         isDiscoverable: Bool = true, showsOnTimeline: Bool = true) {
        self.id = id
        self.title = title
        self.introduction = introduction
        self.isDiscoverable = isDiscoverable
        self.showsOnTimeline = showsOnTimeline
    }

    init(id: Int, germanName: String, englishName: String) {
        self.init(id: String(id), title: bilingual(germanName, englishName))
    }

    var germanName: String { title.text(in: LanguageTag("de")) ?? "" }
    var englishName: String { title.text(in: LanguageTag("en")) ?? "" }
    var localizedName: String { localizedName(locale: .current) }
    func localizedName(locale: Locale) -> String { title.resolved(locale: locale) }

    static let example = Tag(id: 6, germanName: "Länderschwerpunkt", englishName: "Country Special")
}

extension Stage {
    init(id: FestivalPlaceID, germanName: String, englishName: String,
         germanDescription: String?, englishDescription: String?, stageNumber: Int?,
         latitude: Double, longitude: Double, area: Area?, stageType: StageType,
         isMetadataAvailable: Bool = true, locationIsApproximate: Bool = false,
         stageCode: String? = nil) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.area = area
        self.stageType = stageType
        self.isMetadataAvailable = isMetadataAvailable
        self.locationIsApproximate = locationIsApproximate
        self.stageCode = stageCode ?? stageNumber.map(String.init)
        self.localizedNames = bilingual(germanName, englishName)
        self.localizedDescriptions = FestivalContent(text: bilingual(germanDescription, englishDescription), format: .plainText)
    }

    init(id: Int, germanName: String, englishName: String,
         germanDescription: String?, englishDescription: String?, stageNumber: Int?,
         latitude: Double, longitude: Double, area: Area?, stageType: StageType,
         isMetadataAvailable: Bool = true, locationIsApproximate: Bool = false,
         stageCode: String? = nil) {
        self.init(id: .numeric(id), germanName: germanName, englishName: englishName,
                  germanDescription: germanDescription, englishDescription: englishDescription,
                  stageNumber: stageNumber, latitude: latitude, longitude: longitude,
                  area: area, stageType: stageType, isMetadataAvailable: isMetadataAvailable,
                  locationIsApproximate: locationIsApproximate, stageCode: stageCode)
    }

    init(id: FestivalPlaceID, name: LocalizedText, reference: String?) {
        self.init(id: id, germanName: "", englishName: "", germanDescription: nil, englishDescription: nil,
                  stageNumber: nil, latitude: .nan, longitude: .nan, area: nil, stageType: .unknown,
                  stageCode: reference)
        self.localizedNames = name
    }
}

extension Artist {
    func summary(locale: Locale = .current) -> String? {
        if !localizedSummaries.isEmpty {
            return LocalizedText(values: localizedSummaries.mapValues(\.text)).resolved(locale: locale, defaultLanguage: defaultContentLanguage).nilIfEmpty()
        }
        return nil
    }
}

extension Artist {
    func keywordLabels(locale: Locale = .current) -> [String]? {
        let choices = localizedKeywords.filter { !$0.value.isEmpty }
        let keyText = LocalizedText(values: Dictionary(uniqueKeysWithValues: choices.keys.map { ($0, $0.identifier) }))
        if let key = keyText.resolved(locale: locale, defaultLanguage: defaultContentLanguage).nilIfEmpty() { return choices[LanguageTag(key)] }
        return nil
    }
    var flagSymbols: [String] {
        let flags = countryCodes.compactMap(emojiFlag(forRegionCode:))
        return flags.isEmpty ? fallbackCountryFlags : flags
    }
}
