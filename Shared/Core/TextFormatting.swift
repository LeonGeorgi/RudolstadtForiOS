import Foundation

extension Locale {
    var appLanguageCodeIdentifier: String? {
        language.languageCode?.identifier
    }
}

func normalize(string: String) -> String {
    string.folding(
        options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
        locale: Locale.current
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

extension Array {
    func withApplied(
        searchTerm rawSearchTerm: String,
        mapper: (Element) -> String
    ) -> [Element] {
        let trimmedSearchTerm = rawSearchTerm.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedSearchTerm.isEmpty {
            return self
        }

        let searchTerm = normalize(string: trimmedSearchTerm)
        return filter { element in
            normalize(string: mapper(element)).contains(searchTerm)
        }
        .enumerated()
        .sorted { element1, element2 in
            let index1 = element1.offset
            let index2 = element2.offset

            let mapped1 = mapper(element1.element)
            let mapped2 = mapper(element2.element)

            let string1 = normalize(string: mapped1)
            let string2 = normalize(string: mapped2)

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
        matcher: (Element, String) -> Bool
    ) -> [Element] {
        let trimmedSearchTerm = rawSearchTerm.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if trimmedSearchTerm.isEmpty {
            return self
        }

        let searchTerm = normalize(string: trimmedSearchTerm)
        return filter { element in
            matcher(element, searchTerm)
        }
    }
}
