import Foundation

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
    let stringWithNewLines = string.replacingOccurrences(
        of: " ?<br> ?",
        with: "\n",
        options: [.regularExpression]
    )
    .replacingOccurrences(of: "&#34;", with: "\"")
    .replacingOccurrences(of: "&#35;", with: "#")
    .replacingOccurrences(of: "&#36;", with: "$")
    .replacingOccurrences(of: "&#37;", with: "%")
    .replacingOccurrences(of: "&#38;", with: "&")
    .replacingOccurrences(of: "&#39;", with: "'")
    .replacingOccurrences(of: "&#40;", with: "(")
    .replacingOccurrences(of: "&#41;", with: ")")
    .replacingOccurrences(of: "&#42;", with: "*")
    .replacingOccurrences(of: "&#43;", with: "+")
    .replacingOccurrences(of: "&#44;", with: ",")
    .replacingOccurrences(of: "&#45;", with: "-")
    .replacingOccurrences(of: "&nbsp;", with: " ")
    .replacingOccurrences(of: "&amp;", with: "&")
    .trimmingCharacters(in: .whitespacesAndNewlines)

    return stringWithNewLines
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
    guard let host = url.host?.lowercased() else {
        return nil
    }

    if host == "youtu.be" || host.hasSuffix(".youtu.be") {
        return sanitizedYouTubeVideoID(
            url.pathComponents.dropFirst().first ?? ""
        )
    }

    guard
        host.contains("youtube.com")
            || host.contains("youtube-nocookie.com")
    else {
        return nil
    }

    if
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
        let sanitizedID = sanitizedYouTubeVideoID(videoID)
    {
        return sanitizedID
    }

    let pathComponents = url.pathComponents.dropFirst()
    let markers = ["embed", "shorts", "live", "v"]

    for marker in markers {
        if
            let markerIndex = pathComponents.firstIndex(of: marker),
            pathComponents.index(after: markerIndex) < pathComponents.endIndex
        {
            return sanitizedYouTubeVideoID(
                pathComponents[pathComponents.index(after: markerIndex)]
            )
        }
    }

    return nil
}

func youtubeThumbnailURL(for videoID: String) -> URL? {
    URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg")
}

private func sanitizedYouTubeVideoID<S: StringProtocol>(_ candidate: S) -> String? {
    let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return nil
    }

    let allowedCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "-_")
    )
    let filtered = String(trimmed.unicodeScalars.filter {
        allowedCharacters.contains($0)
    })

    guard !filtered.isEmpty else {
        return nil
    }

    return filtered
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
