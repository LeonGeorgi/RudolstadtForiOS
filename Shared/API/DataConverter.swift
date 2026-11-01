import Foundation
import OSLog

func convertAPIRudolstadtDataToEntities(
    apiData: APIRudolstadtData,
    extraData: ExtraDataCollection
) -> FestivalData {
    let areaRecords = uniqueRecords(apiData.areas, id: \.id)
    let artistRecords = uniqueRecords(apiData.artists, id: \.id)
    let stageRecords = uniqueRecords(apiData.stages, id: \.id)
    let tagRecords = uniqueRecords(apiData.tags, id: \.id)
    let eventRecords = uniqueRecords(apiData.events, id: \.id)
    let tags = tagRecords.values.map(convertAPITagToTag)
    var artists = artistRecords.values.map {
        convertAPIArtistToArtist(
            apiArtist: $0, extraData: extraData,
            tags: tagRecords.values, events: eventRecords.values)
    }
    let areas = areaRecords.values.map(convertAPIAreaToArea)
    var stages = stageRecords.values.compactMap {
        convertAPIStageToStage(apiStage: $0, areas: areas)
    }
    var artistIDs = Set(artists.map(\.id))
    var stageIDs = Set(stages.map(\.id))
    for event in eventRecords.values {
        let artistID = event.artist > 0 ? event.artist : -event.id
        let stageID = event.stage > 0 ? event.stage : -event.id
        if artistIDs.insert(artistID).inserted { artists.append(.missing(id: artistID)) }
        if stageIDs.insert(.numeric(stageID)).inserted { stages.append(.missing(id: stageID)) }
    }
    artists.sort {
        let a = normalize(string: $0.name, locale: Locale(identifier: "en_US_POSIX"))
        let b = normalize(string: $1.name, locale: Locale(identifier: "en_US_POSIX"))
        return a == b ? $0.id < $1.id : a < b
    }
    stages.sort {
        switch ($0.stageNumber, $1.stageNumber) {
        case let (a?, b?) where a != b: return a < b
        case (_?, nil): return true
        case (nil, _?): return false
        default: return $0.id < $1.id
        }
    }
    let events = eventRecords.values.compactMap {
        convertAPIEventToEvent(apiEvent: $0, stages: stages, artists: artists, tags: tags)
    }.sorted(by: Event.precedes)
    return FestivalData(
        artists: artists, areas: areas, stages: stages, events: events,
        omittedRecordCount: apiData.omittedRecordCount + areaRecords.omitted + artistRecords.omitted
            + stageRecords.omitted + tagRecords.omitted + eventRecords.omitted,
        artistSimilarities: .bundled,
        walkingDistanceMatrix: StageWalkingDistanceProvider.bundled,
        identity: FestivalIdentity(festivalID: "rudolstadt", editionID: String(FestivalConfiguration.year)))
}

private func uniqueRecords<Value>(_ values: [Value], id: KeyPath<Value, Int>)
    -> (values: [Value], omitted: Int)
{
    let counts = Dictionary(grouping: values, by: { $0[keyPath: id] }).mapValues(\.count)
    let unique = values.filter { $0[keyPath: id] > 0 && counts[$0[keyPath: id]] == 1 }
    return (unique, values.count - unique.count)
}

func convertAPIArtistCategoryToArtistType(
    apiCategory: APIArtistCategory,
    apiTagsForAritst: [APITag]
)
    -> ArtistType
{
    if apiCategory == .dancing {
        return .dance
    }
    if apiCategory == .festivalPlus {
        return .other
    }
    if apiCategory != .concert {
        return .other
    }
    if apiTagsForAritst.contains(where: { $0.title == "Straßenmusik" }) {
        return .street
    }
    return .stage
}

func convertAPIArtistToArtist(
    apiArtist: APIArtist,
    extraData: ExtraDataCollection,
    tags: [APITag],
    events: [APIEvent]
) -> Artist {
    guard !apiArtist.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .missing(id: apiArtist.id)
    }
    let eventsForArtist = events.filter { event in
        event.artist == apiArtist.id
    }
    let tagsForArist = eventsForArtist.flatMap { event in
        event.tags.compactMap { tagId in
            tags.first(where: { $0.id == tagId })
        }
    }
    let artistType = convertAPIArtistCategoryToArtistType(
        apiCategory: apiArtist.category,
        apiTagsForAritst: tagsForArist
    )
    let extaArtistData = extraData.data[apiArtist.name]
    let ai = AIArtistData(
        summaryDE: extaArtistData?.de?.summary,
        summaryEN: extaArtistData?.en?.summary,
        tagsDE: extaArtistData?.de?.tags ?? [],
        tagsEN: extaArtistData?.en?.tags ?? [],
        browseGenreIDs: extaArtistData?.browseGenres ?? [],
        flags: extaArtistData?.en?.countries ?? extaArtistData?.de?.countries ?? []
    )
    let countries = (apiArtist.country ?? "").decodingHTMLCharacterReferences()
    return Artist(
        id: apiArtist.id,
        hiddenFromArtistList: apiArtist.hideArtist,
        artistType: artistType,
        name: apiArtist.name.decodingHTMLCharacterReferences(),
        countries: countries,
        countryCodes: parseArtistCountryCodes(countries),
        url: apiArtist.website,
        facebookID: apiArtist.facebook,
        youtubeID: apiArtist.video,
        instagram: apiArtist.instagram,
        descriptionGerman: apiArtist.descriptionDE.decodingHTMLCharacterReferences(),
        descriptionEnglish: apiArtist.descriptionEN.decodingHTMLCharacterReferences(),
        thumbImageUrlString: rudolstadtArtistImageURL("https://www.rudolstadt-festival.de/" + apiArtist.imgThumb),
        fullImageUrlString: rudolstadtArtistImageURL("https://www.rudolstadt-festival.de/" + apiArtist.imgFull),
        ai: ai,
    )
}

func convertAPINewsItemToNewsItem(apiNewsItem: APINewsItem) -> NewsItem {
    let date = apiNewsItem.time.getDateAsGermanString()
    let time = apiNewsItem.time.getTimeAsGermanString()
    if date == nil || time == nil {
        AppLog.news.error(
            "Failed to parse date or time for news item \(apiNewsItem.id)"
        )
    }
    return NewsItem(
        id: apiNewsItem.id,
        languageCode: apiNewsItem.language,
        dateAsString: date ?? "",
        timeAsString: time ?? "",
        shortDescription: apiNewsItem.title.decodingHTMLCharacterReferences(),
        longDescription: apiNewsItem.teaser.decodingHTMLCharacterReferences(),
        content: apiNewsItem.text.decodingHTMLCharacterReferences(),
    )
}

func convertAPIAreaToArea(apiArea: APIArea) -> Area {
    return Area(
        id: apiArea.id,
        germanName: apiArea.title.decodingHTMLCharacterReferences(),
        englishName: apiArea.titleEN.decodingHTMLCharacterReferences(),
    )
}

func convertAPIEventToEvent(
    apiEvent: APIEvent,
    stages: [Stage],
    artists: [Artist],
    tags: [Tag]
) -> Event? {
    guard apiEvent.id > 0 else { return nil }
    let stageID = apiEvent.stage > 0 ? apiEvent.stage : -apiEvent.id
    let artistID = apiEvent.artist > 0 ? apiEvent.artist : -apiEvent.id
    let stage = stages.first { $0.id == .numeric(stageID) } ?? .missing(id: stageID)
    let artist = artists.first { $0.id == artistID } ?? .missing(id: artistID)
    let parsedStart = apiEvent.start.getDate()
    let calendar = FestivalDateUtilities.festivalCalendar
    let wrongYear =
        parsedStart.map { calendar.component(.year, from: $0) != FestivalConfiguration.year }
        ?? false
    let legacyDay =
        wrongYear ? nil : FestivalDateUtilities.festivalDate(apiEvent.day, format: "dd.MM.yyyy")
    let start =
        wrongYear
        ? nil
        : parsedStart
            ?? FestivalDateUtilities.festivalDate(
                apiEvent.day + " " + apiEvent.time, format: "dd.MM.yyyy HH:mm")
    return Event(
        id: apiEvent.id, startDate: start, knownDate: legacyDay,
        stage: stage, artist: artist,
        tags: apiEvent.tags.compactMap { id in tags.first { $0.id == String(id) } })
}

func convertAPIStageCategoryToStageType(apiCategory: APIStageCategory)
    -> StageType
{
    switch apiCategory {
    case .cityticket:
        return .festivalAndDayTicket
    case .comboticket:
        return .festivalTicket
    case .information:
        return .other
    case .unknown:
        return .unknown
    }
}

func convertAPIStageToStage(apiStage: APIStage, areas: [Area]) -> Stage? {
    guard !apiStage.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return .missing(id: apiStage.id)
    }
    let area = areas.first(where: { $0.id == apiStage.area })
        ?? fallbackArea(forMissingID: apiStage.area)
    let stageType = convertAPIStageCategoryToStageType(
        apiCategory: apiStage.category
    )
    return Stage(
        id: apiStage.id,
        germanName: apiStage.title.decodingHTMLCharacterReferences(),
        englishName: apiStage.titleEN.decodingHTMLCharacterReferences(),
        germanDescription: apiStage.description?.decodingHTMLCharacterReferences(),
        englishDescription: apiStage.descriptionEN?.decodingHTMLCharacterReferences(),
        stageNumber: apiStage.mapNumber,
        latitude: apiStage.lat ?? .nan,
        longitude: apiStage.lon ?? .nan,
        area: area,
        stageType: stageType,
    )
}

private func fallbackArea(forMissingID id: Int) -> Area {
    Area(
        id: id,
        germanName: "Sonstige Orte",
        englishName: "Other locations"
    )
}

func convertAPITagToTag(apiTag: APITag) -> Tag {
    return Tag(
        id: apiTag.id,
        germanName: apiTag.title.decodingHTMLCharacterReferences(),
        englishName: apiTag.titleEN.decodingHTMLCharacterReferences(),
    )
}

extension String {
    func decodingHTMLCharacterReferences() -> String {
        var result = self

        let hexPattern = #"&#x([0-9A-Fa-f]+);"#
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let matches = regex.matches(
                in: result,
                range: NSRange(result.startIndex..., in: result)
            )

            for match in matches.reversed() {
                guard
                    let fullRange = Range(match.range(at: 0), in: result),
                    let codeRange = Range(match.range(at: 1), in: result),
                    let scalar = UInt32(result[codeRange], radix: 16),
                    let unicodeScalar = UnicodeScalar(scalar)
                else {
                    continue
                }
                result.replaceSubrange(fullRange, with: String(unicodeScalar))
            }
        }

        let decimalPattern = #"&#([0-9]+);"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let matches = regex.matches(
                in: result,
                range: NSRange(result.startIndex..., in: result)
            )

            for match in matches.reversed() {
                guard
                    let fullRange = Range(match.range(at: 0), in: result),
                    let codeRange = Range(match.range(at: 1), in: result),
                    let scalar = UInt32(result[codeRange], radix: 10),
                    let unicodeScalar = UnicodeScalar(scalar)
                else {
                    continue
                }
                result.replaceSubrange(fullRange, with: String(unicodeScalar))
            }
        }

        return result
    }
}


func rudolstadtArtistImageURL(_ value: String) -> String {
    let placeholders: Set<String> = ["aaaplatzhalter-jj406147npwtqwg.jpg", "aaaplatzhalter-eev4gvb1gk8384g.jpg"]
    guard let url = URL(string: value) else { return "" }
    return placeholders.contains(url.lastPathComponent.lowercased()) ? "" : value
}
