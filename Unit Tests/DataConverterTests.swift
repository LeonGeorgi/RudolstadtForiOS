import XCTest
@testable import Rudolstadt

final class DataConverterTests: XCTestCase {
    func testNewsItemConversionDecodesNumericCharacterReferences() {
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

        XCTAssertEqual(newsItem.shortDescription, "Interview (extended)")
        XCTAssertEqual(newsItem.longDescription, "Quote: \"Hello\"")
        XCTAssertEqual(newsItem.content, "Hex works too: (test)")
    }
}
