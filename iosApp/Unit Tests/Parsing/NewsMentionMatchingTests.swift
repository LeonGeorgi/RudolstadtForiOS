import Foundation
import UIKit
import Testing
import RudolstadtCore
import Nuke
@testable import Rudolstadt

struct NewsMentionMatchingTests {
    @Test @MainActor
    func previewAttachmentsHostTheirLoadingContentAtTheReservedSize() throws {
        let rich = newsAttributedText("https://example.com/news", mentions: [], isSubtitle: false,
                                      font: .systemFont(ofSize: 17), accent: .systemPurple,
                                      colorScheme: .dark, maxWidth: 320)
        let attachment = try #require(rich.attribute(.attachment, at: 0, effectiveRange: nil) as? NewsInlineAttachment)
        let textView = UITextView(usingTextLayoutManager: true)
        textView.attributedText = rich
        let location = try #require(textView.textLayoutManager?.textContentManager?.documentRange.location)
        let provider = try #require(attachment.viewProvider(for: textView, location: location, textContainer: textView.textContainer))
        provider.loadView()
        let hosted = try #require(provider.view)
        #expect(hosted.bounds.size == CGSize(width: 320, height: 92))
        #expect(!hosted.isUserInteractionEnabled)
    }

    @Test @MainActor
    func previewCardBoundsStayIdenticalWhileLoadingLoadedAndMissingMetadata() {
        let url = "https://example.com/news"
        let empty = NewsLinkPreview(url: url, domain: "example.com", title: nil, imageURL: nil, fetchedAtMillis: 0, fetched: false)
        let loaded = NewsLinkPreview(url: url, domain: "example.com", title: "A longer title that wraps onto a second line", imageURL: "https://example.com/cover.jpg", fetchedAtMillis: 1, fetched: true)
        for fontSize: CGFloat in [17, 34] {
            for width: CGFloat in [180, 320] {
                let bounds = [[:], [url: empty], [url: loaded]].map { previews in
                    let text = newsAttributedText(url, mentions: [], isSubtitle: false, font: .systemFont(ofSize: fontSize),
                                                 accent: .systemPurple, colorScheme: .dark, maxWidth: width, previews: previews)
                    let attachment = text.attribute(.attachment, at: 0, effectiveRange: nil) as? NewsInlineAttachment
                    #expect(attachment?.usesTextAttachmentView == true)
                    return attachment?.bounds
                }
                #expect(bounds[0] == bounds[1])
                #expect(bounds[1] == bounds[2])
                #expect(bounds[0]?.size == CGSize(width: width, height: 92 * fontSize / 17))
            }
        }
    }

    @Test @MainActor
    func cachedImagesAreAvailableSynchronouslyAndMailSymbolsKeepTheirAspectRatio() {
        var configuration = ImagePipeline.Configuration()
        configuration.imageCache = ImageCache()
        let pipeline = ImagePipeline(configuration: configuration)
        let url = URL(string: "https://cache-test.invalid/artist.jpg")!
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 10)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 10))
        }
        #expect(cachedRemoteImage(for: url, pipeline: pipeline) == nil)
        pipeline.cache[url] = ImageContainer(image: image)
        #expect(cachedRemoteImage(for: url, pipeline: pipeline) === image)
        let target = CGRect(x: 8, y: 5, width: 16, height: 16)
        let fitted = newsAspectFitRect(imageSize: CGSize(width: 20, height: 14), target: target)
        #expect(fitted.width == 16)
        #expect(abs(fitted.height - 11.2) < 0.01)
        #expect(fitted.midX == target.midX)
        #expect(fitted.midY == target.midY)
    }

    @Test @MainActor
    func emailBadgesRetainCompositionUrlAndExposeOnlyTheAddressForCopying() {
        let full = "mailto:band%2Blive%40example.com?subject=Festival"
        let text = "Kontakt: music27@rudolstadt-festival.de."
        let rich = newsAttributedText(text, mentions: [], isSubtitle: false,
                                     font: .systemFont(ofSize: 17), accent: .systemPurple, colorScheme: .light)
        var chip: NewsInlineAttachment?
        rich.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rich.length)) { value, _, _ in
            if let attachment = value as? NewsInlineAttachment { chip = attachment }
        }
        #expect(chip?.displayLabel == "music27@rudolstadt-festival.de")
        #expect(chip?.destination.scheme == "mailto")
        #expect(NewsMailLinks.shared.address(url: full) == "band+live@example.com")
        let explicit = newsAttributedText(full, mentions: [], isSubtitle: false,
                                         font: .systemFont(ofSize: 17), accent: .systemPurple, colorScheme: .light)
        #expect((explicit.attribute(.attachment, at: 0, effectiveRange: nil) as? NewsInlineAttachment)?.destination.absoluteString == full)
        #expect(rich.string == "Kontakt: \u{FFFC}.")
        #expect(chip?.bounds.height == 26)
    }

    @Test @MainActor
    func previewCardsRemainVisibleWithoutMetadataAndAlwaysCropImagesToFill() {
        let full = "https://example.com/story"
        let empty = NewsLinkPreview(url: full, domain: "example.com", title: nil, imageURL: nil, fetchedAtMillis: 0, fetched: false)
        let rich = newsAttributedText(full, mentions: [], isSubtitle: false,
                                     font: .systemFont(ofSize: 17), accent: .systemBlue, colorScheme: .dark,
                                     maxWidth: 320, previews: [full: empty])
        let card = rich.attribute(.attachment, at: 0, effectiveRange: nil) as? NewsInlineAttachment
        #expect(card?.destination.absoluteString == full)
        #expect(card?.displayLabel == "example.com/…")
        #expect(card?.bounds.size == CGSize(width: 320, height: 92))
        #expect(card?.image != nil)
        let square = CGRect(x: 10, y: 10, width: 72, height: 72)
        let crop = newsAspectFillRect(imageSize: CGSize(width: 1920, height: 1080), target: square)
        #expect(crop.height == 72)
        #expect(crop.width == 128)
        #expect(crop.midX == square.midX)
        #expect(crop.midY == square.midY)
    }

    @Test @MainActor
    func inlineImagesAndNumbersPreserveTextAndTheirNavigationLinks() {
        let artist = TestFixtures.artist(id: 42, name: "Band")
        let stage = TestFixtures.stage(id: 8, stageNumber: 8, germanName: "Lutherkirche", englishName: "Lutherkirche")
        let text = "Band und Lutherkirche. https://example.com/Band"
        let mentions = newsInlineMentions(texts: [text], artists: [artist], stages: [stage])
        let rich = newsAttributedText(text, mentions: mentions, isSubtitle: false,
                                     font: .systemFont(ofSize: 17), accent: .systemBlue, colorScheme: .light)
        #expect(rich.string.replacingOccurrences(of: "\u{FFFC}", with: "")
            .replacingOccurrences(of: "\u{2060}", with: "") == "Band und Lutherkirche. ")
        var attachments: [(NSTextAttachment, URL?)] = []
        rich.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rich.length)) { value, range, _ in
            if let attachment = value as? NSTextAttachment {
                attachments.append((attachment, rich.attribute(.link, at: range.location, effectiveRange: nil) as? URL))
                #expect(rich.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int == 0)
                if (attachment as? NewsInlineAttachment)?.displayLabel == nil {
                    #expect(rich.attribute(.underlineStyle, at: range.location + 1, effectiveRange: nil) as? Int == 0)
                }
            }
        }
        #expect(attachments.count == 3)
        #expect(attachments.first?.0.bounds.height == 18)
        #expect(attachments[1].0.bounds.height == 20)
        #expect(attachments.first?.1 == inlineArtistLinkURL(for: artist))
        #expect(attachments[1].1 == inlineStageLinkURL(for: stage))
        for name in ["Band", "Lutherkirche"] {
            let range = (rich.string as NSString).range(of: name)
            #expect(rich.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int == NSUnderlineStyle.single.rawValue)
        }
        #expect(attachments.last?.1 == URL(string: "https://example.com/Band"))
        #expect((attachments.last?.0 as? NewsInlineAttachment)?.displayLabel == "example.com/…")
    }

    @Test @MainActor
    func webBadgesKeepFullUrlsAndFitNarrowWidthsWithLargeText() {
        let full = "https://www.example.com/very/long/path?language=de#tickets"
        let rich = newsAttributedText("Mehr: \(full).", mentions: [], isSubtitle: false,
                                     font: .systemFont(ofSize: 34), accent: .systemBlue, colorScheme: .dark, maxWidth: 100)
        var chip: NewsInlineAttachment?
        rich.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rich.length)) { value, range, _ in
            guard let attachment = value as? NewsInlineAttachment else { return }
            chip = attachment
            #expect(rich.attribute(.link, at: range.location, effectiveRange: nil) as? URL == URL(string: full))
            #expect(rich.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int == 0)
        }
        #expect(chip?.destination.absoluteString == full)
        #expect(chip?.displayLabel == "example.com/…")
        #expect(chip?.bounds.width == 100)
        #expect(rich.string == "Mehr: \u{FFFC}.")
    }

    @Test @MainActor
    func inlineSymbolsScaleWithLargerTextAndUnnumberedPlacesHaveNoBlankAttachment() {
        let artist = TestFixtures.artist(id: 42, name: "Band")
        let stage = TestFixtures.stage(id: 9, germanName: "Park", englishName: "Park")
        let text = "Band im Park"
        let mentions = newsInlineMentions(texts: [text], artists: [artist], stages: [stage])
        let rich = newsAttributedText(text, mentions: mentions, isSubtitle: false,
                                     font: .systemFont(ofSize: 34), accent: .systemBlue, colorScheme: .dark)
        let attachment = rich.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        #expect(attachment?.bounds.height == 36)
        #expect(attachment?.bounds.width == 44)
        #expect(rich.string.filter { $0 == "\u{FFFC}" }.count == 1)
        let park = (rich.string as NSString).range(of: "Park")
        #expect(rich.attribute(.link, at: park.location, effectiveRange: nil) as? URL == inlineStageLinkURL(for: stage))
    }

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
    func artistMentionRangesPreserveOriginalUnicodeRanges() {
        let text = "🎶 Straße: La Nin\u{0303}a! LA NIÑA."
        let ranges = artistMentionRanges(in: text, candidate: "La Nina")

        #expect(ranges.map { String(text[$0]) } == ["La Nin\u{0303}a", "LA NIÑA"])
        #expect(ranges.map { NSRange($0, in: text) } == [
            NSRange(location: 11, length: 8),
            NSRange(location: 21, length: 7),
        ])
    }

    @Test
    func artistMentionRangesFoldWidthAndIncludeTrailingAccent() {
        let text = "ＢＡＮＤ, Band\u{0301}! SuperBand."
        let ranges = artistMentionRanges(in: text, candidate: "Band")

        #expect(ranges.map { String(text[$0]) } == ["ＢＡＮＤ", "Band\u{0301}"])
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
