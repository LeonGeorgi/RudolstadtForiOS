func convertAPIRudolstadtDataToEntities(apiData: APIRudolstadtData) -> Entities
{
    print("Converting API data to Entities...")
    print(
        "Artists: \(apiData.artists.count), Areas: \(apiData.areas.count), Stages: \(apiData.stages.count), Events: \(apiData.events.count), Tags: \(apiData.tags.count), News: \(apiData.news.count)"
    )
    let artists = apiData.artists.map(convertAPIArtistToArtist)
    let areas = apiData.areas.map(convertAPIAreaToArea)
    let stages = apiData.stages.compactMap {
        convertAPIStageToStage(apiStage: $0, areas: areas)
    }
    let tags = apiData.tags.map(convertAPITagToTag)
    let events = apiData.events.compactMap {
        convertAPIEventToEvent(
            apiEvent: $0,
            stages: stages,
            artists: artists,
            tags: tags
        )
    }.sorted { ev1, ev2 in
        ev1.date < ev2.date
    }
    let newsItems = apiData.news.map(convertAPINewsItemToNewsItem)

    return Entities(
        artists: artists,
        areas: areas,
        stages: stages,
        events: events,
        news: newsItems
    )
}

func convertAPIArtistCategoryToArtistType(apiCategory: APIArtistCategory)
    -> ArtistType
{
    switch apiCategory {
    case .concert:
        return .stage
    case .dancing:
        return .dance
    case .festivalPlus:
        return .other
    }
}

func convertAPIArtistToArtist(apiArtist: APIArtist) -> Artist {
    let artistType = convertAPIArtistCategoryToArtistType(
        apiCategory: apiArtist.category
    )
    return Artist(
        id: apiArtist.id,
        artistType: artistType,
        someNumber: 0,
        name: apiArtist.name,
        countries: apiArtist.country ?? "",
        url: apiArtist.website,
        facebookID: apiArtist.facebook,
        youtubeID: apiArtist.video,
        descriptionGerman: apiArtist.descriptionDE,
        descriptionEnglish: apiArtist.descriptionEN,
        thumbImageUrlString: "https://www.rudolstadt-festival.de/"
            + apiArtist.imgThumb,
        fullImageUrlString: "https://www.rudolstadt-festival.de/"
            + apiArtist.imgFull
    )
}

func convertAPINewsItemToNewsItem(apiNewsItem: APINewsItem) -> NewsItem {
    let date = apiNewsItem.time.getDateAsGermanString()
    let time = apiNewsItem.time.getTimeAsGermanString()
    if date == nil || time == nil {
        print(
            "Error converting date or time for news item with ID: \(apiNewsItem.id)"
        )
    }
    return NewsItem(
        id: apiNewsItem.id,
        languageCode: apiNewsItem.language,
        dateAsString: date ?? "",
        timeAsString: time ?? "",
        shortDescription: apiNewsItem.title,
        longDescription: apiNewsItem.teaser,
        content: apiNewsItem.text,
    )
}

func convertAPIAreaToArea(apiArea: APIArea) -> Area {
    return Area(
        id: apiArea.id,
        germanName: apiArea.title,
        englishName: apiArea.titleEN,
    )
}

func convertAPIEventToEvent(
    apiEvent: APIEvent,
    stages: [Stage],
    artists: [Artist],
    tags: [Tag]
) -> Event? {
    print(apiEvent)
    guard let dayInJuly = apiEvent.getDayInJuly() else {
        return nil
    }
    guard let stage = stages.first(where: { $0.id == apiEvent.stage.id }) else {
        return nil
    }
    guard let artist = artists.first(where: { $0.id == apiEvent.artist.id })
    else {
        return nil
    }
    let tags = apiEvent.tags.compactMap { tagId in
        tags.first(where: { $0.id == tagId })
    }
    return Event(
        id: apiEvent.id,
        dayInJuly: dayInJuly,
        timeAsString: apiEvent.time,
        stage: stage,
        artist: artist,
        tag: tags.first,  // TODO: Handle multiple tags
    )
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
    }
}

func convertAPIStageToStage(apiStage: APIStage, areas: [Area]) -> Stage? {
    guard let area = areas.first(where: { $0.id == apiStage.area.id }) else {
        return nil
    }
    let stageType = convertAPIStageCategoryToStageType(
        apiCategory: apiStage.category
    )
    return Stage(
        id: apiStage.id,
        germanName: apiStage.title,
        englishName: apiStage.titleEN,
        germanDescription: apiStage.description,
        englishDescription: apiStage.descriptionEN,
        stageNumber: apiStage.mapNumber,
        latitude: apiStage.lat,
        longitude: apiStage.lon,
        area: area,
        stageType: stageType,
    )
}

func convertAPITagToTag(apiTag: APITag) -> Tag {
    return Tag(
        id: apiTag.id,
        germanName: apiTag.title,
        englishName: apiTag.titleEN,
    )
}
