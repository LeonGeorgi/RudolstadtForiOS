#if DEBUG
import Foundation
import OSLog
import RudolstadtCore

/// An offline, isolated fixture. Its registration and resources exist only in Debug.
struct FantasyFestivalDataProvider: FestivalDataProviding {
    static let identity = FestivalIdentity(festivalID: "fantasy", editionID: "2027")
    let bundle: Bundle

    init(bundle: Bundle = .main) { self.bundle = bundle }

    static func makeAdapter() -> FestivalSourceAdapter {
        let provider = Self()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = FestivalConfiguration.timeZone
        guard let start = calendar.date(from: DateComponents(year: 2027, month: 7, day: 15, hour: 5)),
              let end = calendar.date(byAdding: .day, value: 4, to: start) else {
            preconditionFailure("Invalid bundled Fantasy Festival dates")
        }
        let introduction = bilingual(
            "150 echte Acts, frei erfundene Konzerte und Bühnen. Kein angekündigtes Festival. Nur für Debug-Tests; alle Bilder sind offline verfügbar.",
            "150 real acts with imaginary concerts and stages. This is not an announced festival. For Debug testing only; all images are available offline.")
        let metadata = FestivalMetadata(
            identity: identity, name: bilingual("Fantasy Festival", "Fantasy Festival"),
            editionLabel: bilingual("2027 · Debug", "2027 · Debug"), editionKind: .experimental,
            dateRange: DateInterval(start: start, end: end), timeZone: calendar.timeZone,
            defaultContentLanguage: LanguageTag("de"), officialLinks: [],
            presentation: FestivalPresentation(logoURL: nil, accentColorHex: "#9A35C9"),
            notices: [],
            userDataPolicy: FestivalUserDataPolicy(
                savedEvents: .editable, artistRatings: .editable, artistNotes: .editable))
        return FestivalSourceAdapter(
            metadata: metadata, services: FestivalServices(), loadingStrategy: .bundledOnly,
            source: provider, bundledSource: .bundledExperiment, dayBoundaryHour: 5,
            includesAreas: true, includesAdmission: false, offersAutomaticPlanning: true,
            informationPages: [FestivalInformationPage(
                id: "fantasy-about", title: bilingual("Über das Testfestival", "About the test festival"),
                content: .article(FestivalContent(text: introduction, format: .plainText)),
                systemImageName: "wrench.and.screwdriver", links: [], relatedPlaceIDs: [],
                sourceURL: nil, updatedAt: nil)] + provider.sourceCreditPages())
    }

    var cacheModificationDate: Date? { nil }
    var isCacheStale: Bool { false }
    func loadCachedData() -> FileLoadingResult<FestivalData> { .notFound }
    func deleteCache() -> Bool { true }
    func loadArtistLinks() -> [String: ArtistLinks] { [:] }
    func loadBrowseTaxonomy() -> [BrowseTaxonomyEntry] {
        Self.genres.map { BrowseTaxonomyEntry(id: $0, labelDE: $0, labelEN: $0) }
    }

    func loadBundledData() -> FileLoadingResult<FestivalData> {
        do { return .loaded(try load()) }
        catch {
            AppLog.data.error("Cannot load Fantasy Festival: \(error.localizedDescription)")
            return .unparsable
        }
    }

    func refresh() async throws -> FestivalData {
        try Task.checkCancellation()
        let data = try load()
        try Task.checkCancellation()
        return data
    }

    private func readFixture() throws -> (Fixture, URL) {
        guard let directory = bundle.resourceURL?.appendingPathComponent("FantasyFestival", isDirectory: true) else {
            throw FestivalLoadingError.unavailable
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(Fixture.self, from: Data(contentsOf: directory.appendingPathComponent("program.json")))
        return (fixture, directory)
    }

    private func sourceCreditPages() -> [FestivalInformationPage] {
        do {
            let (fixture, _) = try readFixture()
            let links = try fixture.artists.flatMap { artist -> [FestivalLink] in
                guard let source = URL(string: artist.photoSourceURL) else {
                    throw FestivalLoadingError.invalidSnapshot
                }
                var links = [FestivalLink(
                    id: "photo-\(artist.id)",
                    title: bilingual("\(artist.name): \(artist.photoCredit)", "\(artist.name): \(artist.photoCredit)"),
                    destination: source, openingMode: .externalBrowser)]
                if !artist.photoLicenseURL.isEmpty {
                    guard let license = URL(string: artist.photoLicenseURL) else {
                        throw FestivalLoadingError.invalidSnapshot
                    }
                    links.append(FestivalLink(
                        id: "license-\(artist.id)",
                        title: bilingual("Lizenz: \(artist.photoLicense)", "License: \(artist.photoLicense)"),
                        destination: license, openingMode: .externalBrowser))
                }
                return links
            }
            let textLinks = try fixture.artists.flatMap { artist in
                try artist.descriptionSources.map { source -> FestivalLink in
                    guard let url = URL(string: source.revisionURL), url.scheme == "https" else {
                        throw FestivalLoadingError.invalidSnapshot
                    }
                    return FestivalLink(
                        id: "text-\(artist.id)-\(source.language)",
                        title: bilingual("\(artist.name) · Wikipedia (\(source.language))", "\(artist.name) · Wikipedia (\(source.language))"),
                        destination: url, openingMode: .externalBrowser)
                }
            }
            guard let textLicenseURL = URL(string: "https://creativecommons.org/licenses/by-sa/4.0/") else {
                throw FestivalLoadingError.invalidSnapshot
            }
            return [FestivalInformationPage(
                id: "fantasy-photo-credits", title: bilingual("Bildnachweise", "Photo credits"),
                content: .article(FestivalContent(text: bilingual(
                    "Alle Fotos stammen von Wikimedia Commons. Sie wurden für die Offline-Nutzung verkleinert und als JPEG gespeichert. Die Links nennen die Urheber, Originaldateien und jeweiligen Lizenzen. Die abgebildeten Acts sind nicht mit diesem fiktiven Testfestival verbunden.",
                    "All photos come from Wikimedia Commons. They were resized and saved as JPEG for offline use. The links identify the authors, original files and individual licenses. The pictured acts are not affiliated with this fictional test festival."), format: .plainText)),
                systemImageName: "photo", links: links, relatedPlaceIDs: [], sourceURL: nil, updatedAt: nil),
                FestivalInformationPage(
                    id: "fantasy-text-credits", title: bilingual("Textquellen und Lizenzen", "Text sources and licenses"),
                    content: .article(FestivalContent(text: bilingual(
                        "Die Künstlerbeschreibungen sind Auszüge aus den deutschen und englischen Wikipedia-Artikeln unter CC BY-SA 4.0. Sie wurden in Klartext umgewandelt und teilweise gekürzt; einzelne Quellenmarkierungen wurden entfernt. Die Links führen zu den verwendeten Artikelversionen. Die Versionsgeschichten nennen die beteiligten Wikipedia-Autorinnen und -Autoren. Die Lizenz gilt für die Artikeltexte.",
                        "Artist descriptions are excerpts from German and English Wikipedia articles under CC BY-SA 4.0. They were converted to plain text and sometimes shortened, with citation markers removed where present. The links lead to the article revisions used. Article histories identify the Wikipedia contributors. The license applies to the article texts."), format: .plainText)),
                    systemImageName: "text.book.closed",
                    links: [FestivalLink(id: "text-license", title: bilingual("Textlizenz: CC BY-SA 4.0", "Text license: CC BY-SA 4.0"),
                        destination: textLicenseURL, openingMode: .externalBrowser)] + textLinks,
                    relatedPlaceIDs: [], sourceURL: nil, updatedAt: nil)]
        } catch {
            AppLog.data.error("Cannot load Fantasy Festival source credits: \(error.localizedDescription)")
            return []
        }
    }

    private func load() throws -> FestivalData {
        let (fixture, directory) = try readFixture()
        guard fixture.schemaVersion == 1, fixture.festivalID == Self.identity.festivalID,
              String(fixture.year) == Self.identity.editionID, fixture.timeZone == "Europe/Berlin",
              fixture.artists.count == 150, fixture.stages.count == 12, fixture.events.count == 500,
              Set(fixture.artists.map(\.id)).count == 150,
              Set(fixture.artists.map(\.image)).count == 150,
              Set(fixture.stages.map(\.id)).count == 12,
              Set(fixture.events.map(\.id)).count == 500 else {
            throw FestivalLoadingError.invalidSnapshot
        }
        func imageURL(_ path: String, folder: String) throws -> URL {
            guard path.hasPrefix(folder + "/"), !path.contains(".."), path.hasSuffix(".jpg") else {
                throw FestivalLoadingError.invalidSnapshot
            }
            let url = directory.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw FestivalLoadingError.unavailable
            }
            return url
        }
        let artists = try fixture.artists.map { record in
            var links = [FestivalLink]()
            for (id, title, value) in [
                ("website", "Wikipedia", record.sourceURL),
                ("photo", record.photoCredit, record.photoSourceURL)
            ] {
                guard let url = URL(string: value), url.scheme == "https" else {
                    throw FestivalLoadingError.invalidSnapshot
                }
                links.append(FestivalLink(id: id, title: bilingual(title, title),
                    destination: url, openingMode: .externalBrowser))
            }
            return Artist(
                id: record.id, name: record.name,
                details: ArtistDetails(
                    descriptions: FestivalContent(
                        text: bilingual(
                            record.descriptionDE + "\n\nText: Wikipedia (CC BY-SA 4.0, Auszug).\nFoto: " + record.photoCredit,
                            record.descriptionEN + "\n\nText: Wikipedia (CC BY-SA 4.0, excerpt).\nPhoto: " + record.photoCredit), format: .plainText),
                    thumbnailURL: try imageURL(record.thumbnail, folder: "thumbnails"),
                    imageURL: try imageURL(record.image, folder: "images"),
                    countryCodes: [record.countryCode], links: links,
                    keywords: [LanguageTag("de"): [record.genre], LanguageTag("en"): [record.genre]]),
                groupIDs: ["artist-kind": ["1"], "genre": [record.genre]])
        }
        let areas = [
            Area(id: 1, germanName: "Sternenpark", englishName: "Starlight Park"),
            Area(id: 2, germanName: "Flussviertel", englishName: "Riverside Quarter"),
            Area(id: 3, germanName: "Nachtgarten", englishName: "Night Garden")
        ]
        let stages = try fixture.stages.map { record -> Stage in
            guard let area = areas.first(where: { $0.id == record.areaID }) else {
                throw FestivalLoadingError.invalidSnapshot
            }
            return Stage(
                id: record.id, germanName: record.nameDE, englishName: record.nameEN,
                germanDescription: "Fiktive Bühne für das Fantasy Festival. Die Kartenposition ist ein Testpunkt.",
                englishDescription: "Imaginary Fantasy Festival stage. The map position is a test location.",
                stageNumber: record.id, latitude: record.latitude, longitude: record.longitude,
                area: area, stageType: .unknown, locationIsApproximate: true)
        }
        let artistsByID = Dictionary(uniqueKeysWithValues: artists.map { ($0.id, $0) })
        let stagesByID = Dictionary(uniqueKeysWithValues: stages.map { ($0.id, $0) })
        let tags = Dictionary(uniqueKeysWithValues: Self.genres.map {
            ($0, Tag(id: $0, title: bilingual($0, $0)))
        })
        let events = try fixture.events.map { record -> Event in
            guard let artist = artistsByID[record.artistID],
                  let stage = stagesByID[.numeric(record.stageID)], let tag = tags[record.tagID],
                  (1...1440).contains(record.durationMinutes) else {
                throw FestivalLoadingError.invalidSnapshot
            }
            return Event(id: record.id, startDate: record.start, knownDate: nil,
                stage: stage, artist: artist, tag: tag, durationMinutes: record.durationMinutes)
        }
        return FestivalData(
            artists: artists, areas: areas, stages: stages, events: events,
            festivalYear: fixture.year, identity: Self.identity,
            features: FestivalFeatures(eventDetails: .available(EventDetailsFeature(contents: []))))
    }

    private static let genres = [
        "Afrobeat", "Blues", "Country", "Electronic", "Folk", "Funk", "Hip-Hop",
        "Jazz", "Latin", "Metal", "Pop", "Punk", "Reggae", "Rock", "Soul", "World"
    ]

    private struct Fixture: Decodable {
        let schemaVersion: Int
        let festivalID: String
        let year: Int
        let timeZone: String
        let artists: [ArtistRecord]
        let stages: [StageRecord]
        let events: [EventRecord]
    }
    private struct ArtistRecord: Decodable {
        let id: Int
        let name: String
        let countryCode: String
        let genre: String
        let image: String
        let thumbnail: String
        let sourceURL: String
        let photoSourceURL: String
        let photoCredit: String
        let photoLicense: String
        let photoLicenseURL: String
        let descriptionDE: String
        let descriptionEN: String
        let descriptionSources: [DescriptionSource]
    }
    private struct DescriptionSource: Decodable {
        let language: String
        let revisionURL: String
    }
    private struct StageRecord: Decodable {
        let id: Int
        let nameDE: String
        let nameEN: String
        let areaID: Int
        let latitude: Double
        let longitude: Double
    }
    private struct EventRecord: Decodable {
        let id: Int
        let artistID: Int
        let stageID: Int
        let start: Date
        let durationMinutes: Int
        let tagID: String
    }
}
#endif
