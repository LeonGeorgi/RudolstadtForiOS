import Foundation
import RudolstadtCore

extension Locale {
    var appLanguageCodeIdentifier: String? {
        language.languageCode?.identifier
    }
}

func normalize(string: String, locale: Locale = .current) -> String {
    string.folding(
        options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
        locale: locale
    ).trimmingCharacters(in: .whitespacesAndNewlines)
}

func formatString(_ string: String) -> String {
    KotlinCore.bridge.formatText(value: string)
    }

func detectedURLs(in text: String) -> [URL] {
    let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector?.matches(in: text, options: [], range: range).compactMap(\.url)
        ?? []
}

func detectedURLs(in texts: [String]) -> [URL] {
    var seen = Set<String>()
    return texts.flatMap(detectedURLs).filter { url in
        seen.insert(url.absoluteString).inserted
    }
}

func extractYouTubeVideoID(from url: URL) -> String? {
    MediaLinks.shared.youtube(parts: MediaURLParts(url))
}

func youtubeThumbnailURL(for videoID: String) -> URL? {
    URL(string: MediaLinks.shared.youtubeThumbnail(id: videoID))
}

extension Array {
    func withApplied(
        searchTerm rawSearchTerm: String,
        locale: Locale = .current,
        mapper: (Element) -> String
    ) -> [Element] {
        let trimmedSearchTerm = rawSearchTerm.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedSearchTerm.isEmpty {
            return self
        }

        let searchTerm = normalize(string: trimmedSearchTerm, locale: locale)
        return filter { element in
            normalize(string: mapper(element), locale: locale).contains(searchTerm)
        }
        .enumerated()
        .sorted { element1, element2 in
            let index1 = element1.offset
            let index2 = element2.offset

            let mapped1 = mapper(element1.element)
            let mapped2 = mapper(element2.element)

            let string1 = normalize(string: mapped1, locale: locale)
            let string2 = normalize(string: mapped2, locale: locale)

            let s1 = string1.starts(with: searchTerm)
            let s2 = string2.starts(with: searchTerm)

            return s1 && !s2 || ((s1 || s2) && index1 < index2)
        }
        .map {
            $0.element
        }
    }

    func withApplied(
        searchTerm rawSearchTerm: String,
        locale: Locale = .current,
        matcher: (Element, String) -> Bool
    ) -> [Element] {
        let trimmedSearchTerm = rawSearchTerm.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedSearchTerm.isEmpty {
            return self
        }

        let searchTerm = normalize(string: trimmedSearchTerm, locale: locale)
        return filter { element in
            matcher(element, searchTerm)
        }
    }
}
