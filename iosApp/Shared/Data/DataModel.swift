import Foundation
import RudolstadtCore

// Views retain the shared immutable objects; these aliases allocate no Swift model copies.
typealias Artist = ProgramArtist
typealias Area = ProgramArea
typealias Stage = ProgramPlace
typealias Event = ProgramOccurrence
typealias Tag = ProgramTag

extension ProgramDetailCatalog: @unchecked @retroactive Sendable {}

/// Native program context: shared Kotlin objects plus platform services and loading state.
struct FestivalData: Sendable {
    var artists: [Artist] { didSet { detailCatalog = nil } }
    var areas: [Area]
    var stages: [Stage] { didSet { detailCatalog = nil } }
    var events: [Event] { didSet { detailCatalog = nil } }
    var detailCatalog: ProgramDetailCatalog? = nil
    var omittedRecordCount = 0
    var artistSimilarities: ArtistSimilarityCatalog? = nil { didSet { detailCatalog = nil } }
    var walkingDistanceMatrix: StageWalkingDistanceMatrix = .empty { didSet { detailCatalog = nil } }
    var festivalYear: Int = FestivalConfiguration.year { didSet { detailCatalog = nil } }
    var sitePlan: FestivalSitePlan? = nil
    var days: [FestivalDay] = []
    var identity: FestivalIdentity? = nil
    var provenance: FestivalDataProvenance? = nil
    var features = FestivalFeatures() { didSet { detailCatalog = nil } }
    var metadata: FestivalMetadata? = nil { didSet { detailCatalog = nil } }

    var eventDurations: [Int: Int] {
        Dictionary(
            uniqueKeysWithValues: events.compactMap { event in
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

/// Swift adds native formatting and protocol conformances to the Kotlin model.
/// Kotlin objects are immutable; enrichment replaces a value rather than mutating shared references.
extension ProgramArtist: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public typealias ID = Int
    public var id: Int { Int(artistID) }
    var details: ArtistDetails { content.native }
    var localizedSummaries: [LanguageTag: ArtistSummary] {
        Dictionary(uniqueKeysWithValues: summaries.map { (LanguageTag($0.language), $0.native) })
    }
    var groupIDs: [String: Set<String>] { groups.mapValues(Set.init) }
    var defaultContentLanguage: LanguageTag? { defaultLanguage.map(LanguageTag.init) }

    func replacing(
        details: ArtistDetails? = nil, groupIDs: [String: Set<String>]? = nil,
        summaries: [LanguageTag: ArtistSummary]? = nil,
        defaultContentLanguage: LanguageTag?? = nil
    ) -> Artist {
        withMetadata(
            content: details?.core ?? content,
            groups: groupIDs?.mapValues { $0.sorted() } ?? groups,
            summaries: summaries?.values.map(\.core) ?? self.summaries,
            defaultLanguage: defaultContentLanguage.map { $0?.identifier } ?? defaultLanguage)
    }

    var artistType: ArtistType {
        groups["artist-kind"]?.compactMap(Int.init).first.flatMap(ArtistType.init(rawValue:))
            ?? .other
    }
    var countries: String {
        content.countryDescription.map {
            LocalizedText(core: $0).resolved(defaultLanguage: defaultContentLanguage)
        } ?? ""
    }
    var countryCodes: [String] { content.countryCodes }
    var localizedDescriptions: FestivalContent? { content.descriptions.native }
    var localizedKeywords: [LanguageTag: [String]] {
        Dictionary(uniqueKeysWithValues: content.keywords.map { (LanguageTag($0.key), $0.value) })
    }
    var musicPreview: FestivalMusicPreview { content.nativePreview }
    var additionalLinks: [FestivalLink] { content.links.compactMap(\.native) }
    var thumbImageUrlString: String { thumbImageUrl?.absoluteString ?? "" }
    var fullImageUrlString: String { fullImageUrl?.absoluteString ?? "" }

    convenience init(
        id: Int, name: String, isListed: Bool = true, details: ArtistDetails? = nil,
        groupIDs: [String: Set<String>] = [:], summaries: [LanguageTag: ArtistSummary] = [:]
    ) {
        let details =
            details
            ?? ArtistDetails(
                descriptions: FestivalContent(text: bilingual(nil, nil), format: .plainText),
                thumbnailURL: nil, imageURL: nil, countryCodes: [], links: [])
        self.init(
            artistID: Int64(id), name: name, hiddenFromArtistList: !isListed,
            content: details.core, groups: groupIDs.mapValues { $0.sorted() },
            summaries: summaries.values.map(\.core), defaultLanguage: nil,
            isMetadataAvailable: !name.isEmpty, fallbackCountryFlags: [])
    }

    convenience init(
        id: Int, hiddenFromArtistList: Bool, artistType: ArtistType, name: String,
        countries: String, countryCodes: [String], url: String?, facebookID: String?,
        youtubeID: String?, instagram: String?, descriptionGerman: String?,
        descriptionEnglish: String?,
        thumbImageUrlString: String, fullImageUrlString: String, ai: AIArtistData?,
        isMetadataAvailable: Bool = true
    ) {
        func socialURL(_ value: String?, prefix: String) -> String? {
            guard let value, !value.isEmpty else { return nil }
            return value.contains("http") ? value : prefix + value
        }
        let links = [
            ("website", url),
            ("facebook", socialURL(facebookID, prefix: "https://www.facebook.com/")),
            ("youtube", socialURL(youtubeID, prefix: "https://www.youtube.com/watch?v=")),
            ("instagram", instagram),
        ]
        .compactMap { id, value -> FestivalLink? in
            guard let value, !value.isEmpty, let url = URL(string: value), url.scheme != nil else {
                return nil
            }
            return FestivalLink(
                id: id, title: LocalizedText(values: [LanguageTag("en"): id]),
                destination: url, openingMode: .externalBrowser)
        }
        let details = ArtistDetails(
            descriptions: FestivalContent(
                text: bilingual(descriptionGerman, descriptionEnglish), format: .html),
            thumbnailURL: Self.usableImageURL(from: thumbImageUrlString),
            imageURL: Self.usableImageURL(from: fullImageUrlString),
            countryCodes: countryCodes, links: links,
            countryDescription: bilingual(countries, countries),
            keywords: [LanguageTag("de"): ai?.tagsDE ?? [], LanguageTag("en"): ai?.tagsEN ?? []])
        let summaries = bilingual(ai?.summaryDE, ai?.summaryEN).values.map { language, text in
            ArtistSummary(text: text, language: language, origin: .aiGenerated, sourceURL: nil).core
        }
        self.init(
            artistID: Int64(id), name: name, hiddenFromArtistList: hiddenFromArtistList,
            content: details.core,
            groups: [
                "artist-kind": [String(artistType.rawValue)], "genre": ai?.browseGenreIDs ?? [],
            ],
            summaries: summaries, defaultLanguage: nil, isMetadataAvailable: isMetadataAvailable,
            fallbackCountryFlags: ai?.flags ?? [])
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
            id: id, hiddenFromArtistList: true, artistType: .other, name: "", countries: "",
            countryCodes: [], url: nil, facebookID: nil,
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
        if let localizedDescriptions {
            return formatString(
                localizedDescriptions.text.resolved(
                    locale: locale, defaultLanguage: defaultContentLanguage))
        }
        return nil
    }

    var thumbImageUrl: URL? {
        Self.usableImageURL(from: content.thumbnail ?? "")
    }

    var fullImageUrl: URL? {
        Self.usableImageURL(from: content.image ?? "")
    }

    var videoUrl: URL? { link("youtube") }
    var facebookUrl: URL? { link("facebook") }
    var instagramUrl: URL? { link("instagram") }

    func matches(searchTerm: String) -> Bool {
        matches(searchTerm: searchTerm, locale: .current)
    }

    func matches(searchTerm: String, locale: Locale) -> Bool {
        let fields = [name, formattedDescription(locale: locale) ?? ""].map {
            normalize(string: $0, locale: locale)
        }
        return KotlinCore.bridge.search(fields: fields, term: searchTerm, requireAllTerms: false)
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

    static func usableImageURL(from urlString: String) -> URL? {
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
    public var id: Int {
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

extension ProgramArea: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public typealias ID = Int
    public var id: Int { Int(areaID) }
    var name: LocalizedText { LocalizedText(core: names) }

    convenience init(id: Int, name: LocalizedText) {
        self.init(areaID: Int64(id), names: name.core)
    }
    convenience init(id: Int, germanName: String, englishName: String) {
        self.init(id: id, name: bilingual(germanName, englishName))
    }

    var germanName: String { names["de"] ?? "" }
    var englishName: String { names["en"] ?? "" }
    var localizedName: String { localizedName(locale: .current) }
    func localizedName(locale: Locale) -> String { name.resolved(locale: locale) }

    static let example = Area(id: 3, germanName: "Heinepark (City Park)", englishName: "City Park")
}

extension ProgramOccurrence: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public typealias ID = Int
    public var id: Int { Int(eventID) }
    var startDate: Date? { startTimestamp.map { Date(timeIntervalSince1970: $0.doubleValue) } }
    var knownDate: Date? { knownDateTimestamp.map { Date(timeIntervalSince1970: $0.doubleValue) } }
    var resolvedDuration: FestivalEventDuration? {
        eventDuration.map {
            FestivalEventDuration(minutes: Int($0.minutes), isEstimated: $0.isEstimated)
        }
    }
    var programDay: FestivalDay? { assignedDay?.native }
    var timeZone: TimeZone { TimeZone(identifier: zoneID) ?? .gmt }
    var durationMinutes: Int? { resolvedDuration?.minutes }

    func replacing(
        stage: Stage? = nil, artist: Artist? = nil, tags: [Tag]? = nil,
        resolvedDuration: FestivalEventDuration?? = nil, programDay: FestivalDay?? = nil,
        timeZone: TimeZone? = nil
    ) -> Event {
        withMetadata(
            stage: stage ?? self.stage, artist: artist ?? self.artist, tags: tags ?? self.tags,
            eventDuration: resolvedDuration.map { $0?.core } ?? eventDuration,
            assignedDay: programDay.map { $0?.core } ?? assignedDay,
            zoneID: timeZone?.identifier ?? zoneID)
    }

    var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = timeZone
        return result
    }

    var artistID: Int { artist.id }
    var placeID: FestivalPlaceID? { stage.isMetadataAvailable ? stage.id : nil }
    var festivalDayID: FestivalDay.ID? { programDay?.id }
    var duration: FestivalEventDuration? { resolvedDuration }
    var tag: Tag? { tags.first }

    convenience init(
        id: Int, startDate: Date?, knownDate: Date?, stage: Stage, artist: Artist,
        tag: Tag? = nil, tags: [Tag]? = nil, durationMinutes: Int? = nil,
        timeZone: TimeZone = FestivalConfiguration.timeZone,
        editorialContent: FestivalEditorialContent? = nil
    ) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let knownDate = startDate.map { calendar.startOfDay(for: $0) } ?? knownDate
        self.init(
            eventID: Int64(id),
            startTimestamp: startDate.map { KotlinDouble(value: $0.timeIntervalSince1970) },
            knownDateTimestamp: knownDate.map { KotlinDouble(value: $0.timeIntervalSince1970) },
            stage: stage, artist: artist,
            tags: tags ?? tag.map { [$0] } ?? [],
            eventDuration: durationMinutes.map {
                EventDuration(minutes: Int32($0), isEstimated: false)
            },
            assignedDay: nil, zoneID: timeZone.identifier, editorialContent: editorialContent)
    }

    convenience init(
        id: Int, dayInJuly: Int, timeAsString: String, stage: Stage, artist: Artist, tag: Tag?
    ) {
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

    var hasCompleteMetadata: Bool { eligibleForPlanning }

    var dayInJuly: Int {
        programDay?.date.day ?? knownDate.map { self.calendar.component(.day, from: $0) } ?? 0
    }

    var timeAsString: String {
        if let startDate {
            return startDate.formatted(
                Date.VerbatimFormatStyle(
                    format: "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
                    locale: Locale(identifier: "en_US_POSIX"), timeZone: timeZone, calendar: calendar))
        }
        return NSLocalizedString(
            knownDate == nil ? "event.date.unknown" : "event.time.unknown", comment: "")
    }

    var festivalHour: Int { Int(festivalHourValue) }
    func festivalHour(calendar: Calendar) -> Int { festivalHour }
    var startTimeInMinutes: Int { Int(startMinute) }
    func startTimeInMinutes(calendar: Calendar) -> Int { Int(startMinute) }
    // Zero means that no festival day is known; it must not become a day tab.
    var festivalDay: Int { Int(festivalDayNumber) }
    func festivalDay(calendar: Calendar) -> Int { Int(festivalDayNumber) }
    static func precedes(_ first: Event, _ second: Event) -> Bool {
        ProgramSchedule.shared.precedes(first: first, second: second)
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
        let fields = [
            artist.name, stage.localizedName(locale: locale),
            tag?.localizedName(locale: locale) ?? "", timeAsString,
            weekDay(calendar: calendar, locale: locale),
            shortWeekDay(calendar: calendar, locale: locale),
        ]
        .map { normalize(string: $0, locale: locale) }
        return KotlinCore.bridge.search(fields: fields, term: searchTerm, requireAllTerms: true)
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
        return knownDate.formatted(
            Date.VerbatimFormatStyle(
                format: "\(weekday: .wide)", locale: locale, timeZone: timeZone, calendar: self.calendar))
    }

    var shortWeekDay: String { shortWeekDay(calendar: .current, locale: .current) }
    func shortWeekDay(calendar: Calendar, locale: Locale) -> String {
        guard let knownDate else { return NSLocalizedString("event.date.unknown", comment: "") }
        return knownDate.formatted(
            Date.VerbatimFormatStyle(
                format: "\(weekday: .abbreviated)", locale: locale, timeZone: timeZone, calendar: self.calendar))
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

typealias NewsItem = NewsMessage
extension NewsMessage: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public typealias ID = Int
    public var id: Int { Int(newsID) }
    convenience init(
        id: Int, languageCode: String, dateAsString: String, timeAsString: String,
        shortDescription: String, longDescription: String, content: String
    ) {
        self.init(
            newsID: Int64(id), languageCode: languageCode, dateAsString: dateAsString,
            timeAsString: timeAsString, shortDescription: shortDescription, longDescription: longDescription,
            content: content)
    }

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
        let fields = [
            dateAsString, timeAsString, shortDescription, formattedLongDescription,
            formattedContent,
        ].map { normalize(string: $0, locale: locale) }
        return KotlinCore.bridge.search(fields: fields, term: searchTerm, requireAllTerms: true)
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

extension ProgramPlace: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public typealias ID = FestivalPlaceID
    public var id: ID {
        if placeKey.hasPrefix("n:"), let value = Int(placeKey.dropFirst(2)) {
            return .numeric(value)
        }
        return .text(String(placeKey.dropFirst(2)))
    }
    var stageType: StageType { StageType(rawValue: Int(typeCode)) ?? .unknown }
    var germanName: String { names["de"] ?? "" }
    var englishName: String { names["en"] ?? "" }
    var germanDescription: String? { localizedDescriptions?.text.text(in: LanguageTag("de")) }
    var englishDescription: String? { localizedDescriptions?.text.text(in: LanguageTag("en")) }
    var stageNumber: Int? { stageCode.flatMap(Int.init) }
    var defaultContentLanguage: LanguageTag? { defaultLanguage.map(LanguageTag.init) }
    var localizedNames: LocalizedText? { LocalizedText(core: names) }
    var localizedDescriptions: FestivalContent? { descriptions?.native }
    var admissionCategory: FestivalAdmissionCategory? { admission?.nativeAdmission }
    var mapCategory: MapCategory? { mapGrouping?.nativeMap }

    func replacing(
        localizedDescriptions: FestivalContent?? = nil,
        latitude: Double? = nil, longitude: Double? = nil, area: Area?? = nil,
        defaultContentLanguage: LanguageTag?? = nil, locationIsApproximate: Bool? = nil,
        stageCode: String?? = nil, admissionCategory: FestivalAdmissionCategory?? = nil,
        mapCategory: MapCategory?? = nil
    ) -> Stage {
        withMetadata(
            descriptions: localizedDescriptions.map { $0?.core } ?? descriptions,
            latitude: latitude ?? self.latitude, longitude: longitude ?? self.longitude,
            area: area ?? self.area,
            defaultLanguage: defaultContentLanguage.map { $0?.identifier } ?? defaultLanguage,
            locationIsApproximate: locationIsApproximate ?? self.locationIsApproximate,
            stageCode: stageCode ?? self.stageCode,
            admission: admissionCategory.map { $0?.core } ?? admission,
            mapGrouping: mapCategory.map { $0?.core } ?? mapGrouping)
    }

    var name: LocalizedText { localizedNames ?? bilingual(nil, nil) }
    var reference: String? { displayCode }

    var displayCode: String? {
        stageCode
    }

    static func precedes(_ lhs: Stage, _ rhs: Stage) -> Bool {
        switch (lhs.displayCode, rhs.displayCode) {
        case (let left?, let right?) where left != right:
            return left.compare(right, options: .numeric, locale: Locale(identifier: "en_US_POSIX"))
                == .orderedAscending
        case (_?, nil): return true
        case (nil, _?): return false
        default: return lhs.id < rhs.id
        }
    }

    var hasLocation: Bool {
        hasUsableLocation
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
        if let localizedDescriptions {
            return localizedDescriptions.text.resolved(
                locale: locale, defaultLanguage: defaultContentLanguage)
        }
        return nil
    }

    func matches(searchTerm: String) -> Bool {
        matches(searchTerm: searchTerm, locale: .current)
    }

    func matches(searchTerm: String, locale: Locale) -> Bool {
        let fields = [
            localizedName(locale: locale), area?.localizedName(locale: locale) ?? "",
            localizedDescription(locale: locale) ?? "", displayCode ?? "",
        ].map { normalize(string: $0, locale: locale) }
        return KotlinCore.bridge.search(fields: fields, term: searchTerm, requireAllTerms: false)
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

}

enum StageType: Int, Identifiable, CaseIterable {
    public var id: Int {
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

extension ProgramTag: @retroactive Identifiable, @unchecked @retroactive Sendable {
    public typealias ID = String
    public var id: String { tagID }
    var title: LocalizedText { LocalizedText(core: titles) }
    var introduction: LocalizedText? { introductionTexts.map(LocalizedText.init(core:)) }

    convenience init(
        id: String, title: LocalizedText, introduction: LocalizedText? = nil,
        isDiscoverable: Bool = true, showsOnTimeline: Bool = true,
        editorialContent: FestivalEditorialContent? = nil
    ) {
        self.init(
            tagID: id, titles: title.core, introductionTexts: introduction?.core,
            isDiscoverable: isDiscoverable, showsOnTimeline: showsOnTimeline,
            editorialContent: editorialContent)
    }

    convenience init(id: Int, germanName: String, englishName: String) {
        self.init(id: String(id), title: bilingual(germanName, englishName))
    }

    var germanName: String { title.text(in: LanguageTag("de")) ?? "" }
    var englishName: String { title.text(in: LanguageTag("en")) ?? "" }
    var localizedName: String { localizedName(locale: .current) }
    func localizedName(locale: Locale) -> String { title.resolved(locale: locale) }

    static let example = Tag(id: 6, germanName: "Länderschwerpunkt", englishName: "Country Special")
}

extension Stage {
    convenience init(
        id: FestivalPlaceID, germanName: String, englishName: String,
        germanDescription: String?, englishDescription: String?, stageNumber: Int?,
        latitude: Double, longitude: Double, area: Area?, stageType: StageType,
        isMetadataAvailable: Bool = true, locationIsApproximate: Bool = false,
        stageCode: String? = nil
    ) {
        self.init(
            placeKey: id.coreID, names: bilingual(germanName, englishName).core,
            descriptions: FestivalContent(
                text: bilingual(germanDescription, englishDescription), format: .plainText
            ).core,
            latitude: latitude, longitude: longitude, area: area,
            typeCode: Int32(stageType.rawValue),
            defaultLanguage: nil, isMetadataAvailable: isMetadataAvailable,
            locationIsApproximate: locationIsApproximate,
            stageCode: stageCode ?? stageNumber.map(String.init),
            admission: nil, mapGrouping: nil)
    }

    convenience init(
        id: Int, germanName: String, englishName: String,
        germanDescription: String?, englishDescription: String?, stageNumber: Int?,
        latitude: Double, longitude: Double, area: Area?, stageType: StageType,
        isMetadataAvailable: Bool = true, locationIsApproximate: Bool = false,
        stageCode: String? = nil
    ) {
        self.init(
            id: .numeric(id), germanName: germanName, englishName: englishName,
            germanDescription: germanDescription, englishDescription: englishDescription,
            stageNumber: stageNumber, latitude: latitude, longitude: longitude,
            area: area, stageType: stageType, isMetadataAvailable: isMetadataAvailable,
            locationIsApproximate: locationIsApproximate, stageCode: stageCode)
    }

    convenience init(id: FestivalPlaceID, name: LocalizedText, reference: String?) {
        self.init(
            placeKey: id.coreID, names: name.core, descriptions: nil,
            latitude: .nan, longitude: .nan, area: nil, typeCode: Int32(StageType.unknown.rawValue),
            defaultLanguage: nil, isMetadataAvailable: true, locationIsApproximate: false,
            stageCode: reference, admission: nil, mapGrouping: nil)
    }
}

extension Artist {
    func summary(locale: Locale = .current) -> String? {
        if !localizedSummaries.isEmpty {
            return LocalizedText(values: localizedSummaries.mapValues(\.text)).resolved(
                locale: locale, defaultLanguage: defaultContentLanguage
            ).nilIfEmpty()
        }
        return nil
    }
}

extension Artist {
    func keywordLabels(locale: Locale = .current) -> [String]? {
        let choices = localizedKeywords.filter { !$0.value.isEmpty }
        let keyText = LocalizedText(
            values: Dictionary(uniqueKeysWithValues: choices.keys.map { ($0, $0.identifier) }))
        if let key = keyText.resolved(locale: locale, defaultLanguage: defaultContentLanguage)
            .nilIfEmpty()
        {
            return choices[LanguageTag(key)]
        }
        return nil
    }
    var flagSymbols: [String] {
        let flags = countryCodes.compactMap(emojiFlag(forRegionCode:))
        return flags.isEmpty ? fallbackCountryFlags : flags
    }
}
