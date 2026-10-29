import Testing
@testable import Rudolstadt

struct NewsMentionMatchingTests {
    @Test
    func wholeMentionMatchRequiresBoundaryBefore() {
        let normalizedText = normalizeForNewsMentionMatch(
            "superBandAdriatica opens the night"
        )

        #expect(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "BandAdriatica"
            ) == nil
        )
    }

    @Test
    func wholeMentionMatchRequiresBoundaryAfter() {
        let normalizedText = normalizeForNewsMentionMatch(
            "BandAdriaticax returns for an encore"
        )

        #expect(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "BandAdriatica"
            ) == nil
        )
    }

    @Test
    func artistMentionRangesRequireWordBoundaries() throws {
        let text = "superBandAdriatica opens for BandAdriatica."
        let ranges = artistMentionRanges(
            in: text,
            candidate: "BandAdriatica"
        )

        #expect(ranges.count == 1)
        let range = try #require(ranges.first)
        #expect(String(text[range]) == "BandAdriatica")
    }

    @Test
    func wholeMentionMatchRejectsPartialTrailingWordMatch() {
        let normalizedText = normalizeForNewsMentionMatch(
            "La Nina headlines the evening"
        )

        #expect(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "La Ni"
            ) == nil
        )
    }

    @Test
    func wholeMentionMatchAllowsNormalizedPunctuationAndDiacritics() {
        let normalizedText = normalizeForNewsMentionMatch("Tonight: La Nina!")

        #expect(
            firstWholeMentionAppearanceIndex(
                in: normalizedText,
                candidate: "La Niña"
            ) == 8
        )
    }
}
