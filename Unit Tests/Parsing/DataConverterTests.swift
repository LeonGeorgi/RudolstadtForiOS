import Foundation
import Testing
@testable import Rudolstadt

struct DataConverterTests {
    @Test
    func stageConversionFallsBackWhenAreaIsMissing() throws {
        let stage = try #require(
            convertAPIStageToStage(
                apiStage: APIStage(
                    id: 44,
                    title: "Lutherkirche",
                    titleEN: "Lutherkirche",
                    description: nil,
                    descriptionEN: nil,
                    lat: 50.719038,
                    lon: 11.327535,
                    area: 0,
                    category: .comboticket,
                    mapNumber: 8
                ),
                areas: [
                    Area(
                        id: 2,
                        germanName: "Heinepark",
                        englishName: "Heinepark"
                    ),
                    Area(
                        id: 3,
                        germanName: "Innenstadt",
                        englishName: "Inner City"
                    ),
                ]
            )
        )

        #expect(stage.area.id == 0)
        #expect(stage.area.germanName == "Sonstige Orte")
        #expect(stage.area.englishName == "Other locations")
    }

    @Test
    func newsItemConversionDecodesNumericCharacterReferences() {
        let apiNewsItem = APINewsItem(
            id: 42,
            title: "Interview &#40;extended&#41;",
            language: "en",
            teaser: "Quote: &#34;Hello&#34;",
            text: "Hex works too: &#x28;test&#x29;",
            time: APITime(
                date: "2025-07-06 14:00:00.000000",
                timezoneType: 3,
                timezone: "Europe/Berlin"
            )
        )

        let newsItem = convertAPINewsItemToNewsItem(apiNewsItem: apiNewsItem)

        #expect(newsItem.shortDescription == "Interview (extended)")
        #expect(newsItem.longDescription == "Quote: \"Hello\"")
        #expect(newsItem.content == "Hex works too: (test)")
    }

    @Test
    func countryParserHandlesMultipleEnglishCountries() {
        #expect(
            parseArtistCountryCodes("Germany / Burkina Faso")
                == ["DEU", "BFA"]
        )
        #expect(
            parseArtistCountryCodes("USA, Mexico and Canada")
                == ["USA", "MEX", "CAN"]
        )
    }

    @Test
    func countryParserHandlesGermanAndAliasNames() {
        #expect(
            parseArtistCountryCodes("Deutschland, Österreich und Schweiz")
                == ["DEU", "AUT", "CHE"]
        )
        #expect(
            parseArtistCountryCodes("Scotland & Germany")
                == ["GBR", "DEU"]
        )
    }

    @Test
    func localizedCountryNameUsesExplicitLocale() {
        #expect(
            localizedCountryName(
                forRegionCode: "DEU",
                locale: Locale(identifier: "de_DE")
            ) == "Deutschland"
        )
        #expect(
            localizedCountryName(
                forRegionCode: "DEU",
                locale: Locale(identifier: "en_US")
            ) == "Germany"
        )
    }

    @Test
    func artistCountryDescriptionKeepsUKNationsSeparate() {
        #expect(
            localizedArtistCountryDescription(
                rawValue: "Scotland & England",
                countryCodes: ["GBR"],
                locale: Locale(identifier: "de_DE")
            ) == "Schottland und England"
        )
        #expect(
            localizedArtistCountryDescription(
                rawValue: "SCO / Northern Ireland / Wales",
                countryCodes: ["GBR"],
                locale: Locale(identifier: "en_US")
            ) == "Scotland, Northern Ireland, and Wales"
        )
    }

    @Test
    func artistCountryDescriptionStillLocalizesRegularCountries() {
        #expect(
            localizedArtistCountryDescription(
                rawValue: "Scotland & Germany",
                countryCodes: ["GBR", "DEU"],
                locale: Locale(identifier: "de_DE")
            ) == "Schottland und Deutschland"
        )
    }

    @Test
    func countryParserHandlesAPIProvidedAlpha3CodesAndAliases() {
        #expect(parseArtistCountryCodes("DEU") == ["DEU"])
        #expect(parseArtistCountryCodes("JAP | DEU") == ["JPN", "DEU"])
        #expect(parseArtistCountryCodes("ENG") == ["GBR"])
        #expect(parseArtistCountryCodes("SUI") == ["CHE"])
        #expect(parseArtistCountryCodes("POR") == ["PRT"])
        #expect(parseArtistCountryCodes("SAF") == ["ZAF"])
    }

    @Test
    func artistConversionParsesStructuredCountryCodes() {
        let artist = convertAPIArtistToArtist(
            apiArtist: APIArtist(
                id: 10,
                category: .concert,
                hideArtist: false,
                name: "Test Artist",
                country: "Côte d’Ivoire / France",
                website: nil,
                video: nil,
                facebook: nil,
                instagram: nil,
                soundcloud: nil,
                imgThumb: "/thumb.jpg",
                imgFull: "/full.jpg",
                descriptionDE: "",
                descriptionEN: ""
            ),
            extraData: .empty(),
            tags: [],
            events: []
        )

        #expect(artist.countryCodes == ["CIV", "FRA"])
    }

    @Test
    func attributedStringMarksPlainURLsAsLinks() throws {
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "Read more at https://example.com/news",
            artists: []
        )
        let expectedURL = try #require(URL(string: "https://example.com/news"))

        #expect(attributedString.runs.compactMap(\.link) == [expectedURL])
    }

    @Test
    func extractYouTubeVideoIDSupportsWatchAndShortLinks() throws {
        let watchURL = try #require(
            URL(string: "https://www.youtube.com/watch?v=QNJL6nfu__Q")
        )
        let shortURL = try #require(
            URL(string: "https://youtu.be/YO1ERhWMeXc")
        )
        let shortsURL = try #require(
            URL(string: "https://www.youtube.com/shorts/abc123XYZ_9")
        )

        #expect(extractYouTubeVideoID(from: watchURL) == "QNJL6nfu__Q")
        #expect(extractYouTubeVideoID(from: shortURL) == "YO1ERhWMeXc")
        #expect(extractYouTubeVideoID(from: shortsURL) == "abc123XYZ_9")
    }

    @Test
    func detectedURLsDeduplicatesAcrossMultipleStrings() {
        let urls = detectedURLs(
            in: [
                "https://example.com",
                "Video https://youtu.be/YO1ERhWMeXc",
                "Duplicate https://example.com",
            ]
        )

        #expect(
            urls.map(\.absoluteString)
                == [
                    "https://example.com",
                    "https://youtu.be/YO1ERhWMeXc",
                ]
        )
    }

    @Test
    func attributedStringAddsArtistLink() {
        let artist = TestFixtures.artist(id: 77, name: "BandAdriatica")
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "Tonight: BandAdriatica live",
            artists: [artist]
        )

        #expect(
            attributedString.runs.contains { run in
                run.link == inlineArtistLinkURL(for: artist)
            }
        )
    }

    @Test
    func attributedStringLinksOnlyFirstArtistOccurrence() {
        let artist = TestFixtures.artist(id: 78, name: "BandAdriatica")
        let attributedString = attributedStringWithDetectedLinksAndArtistMentions(
            "BandAdriatica meets BandAdriatica after the show",
            artists: [artist]
        )
        let artistLinks = attributedString.runs.compactMap(\.link).filter { link in
            link == inlineArtistLinkURL(for: artist)
        }

        #expect(artistLinks.count == 1)
    }
}
