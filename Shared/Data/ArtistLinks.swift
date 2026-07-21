import Foundation

enum ArtistAppleMusicPreviewSelection: Equatable {
    case automatic
    case disabled
    case songURL(String)
}

struct ArtistLinks {
    var spotifyURL: String?
    var appleMusicURL: String?
    var appleMusicPreviewSelection: ArtistAppleMusicPreviewSelection

    var hasLinks: Bool {
        spotifyURL != nil || appleMusicURL != nil
    }

    var appleMusicPreviewReference: AppleMusicCatalogReference? {
        switch appleMusicPreviewSelection {
        case .automatic:
            guard let appleMusicURL else {
                return nil
            }
            return AppleMusicCatalogReference(urlString: appleMusicURL)
        case .disabled:
            return nil
        case .songURL(let previewURL):
            guard let reference = AppleMusicCatalogReference(
                urlString: previewURL
            ), reference.kind == .song else {
                return nil
            }
            return reference
        }
    }
}

func normalizeArtistLinkKey(_ input: String) -> String {
    input
        .replacingOccurrences(of: "&#34;", with: "\"")
        .replacingOccurrences(of: "“", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "’", with: "'")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
}

func parseArtistLinks() -> [String: ArtistLinks] {
    let resource = "\(DataStore.year)_artist_urls"
    let fallbackResource = "2026_artist_urls"
    let selectedResource: String
    let filepath: String
    if let currentFilepath = Bundle.main.path(
        forResource: resource,
        ofType: "csv"
    ) {
        selectedResource = resource
        filepath = currentFilepath
    } else if let fallbackFilepath = Bundle.main.path(
        forResource: fallbackResource,
        ofType: "csv"
    ) {
        selectedResource = fallbackResource
        filepath = fallbackFilepath
    } else {
        print("File not found")
        return [:]
    }

    do {
        let contents = try String(contentsOfFile: filepath, encoding: .utf8)
        let previewContents = loadArtistPreviewContents(
            forLinkResource: selectedResource
        )
        return parseArtistLinks(
            contents: contents,
            previewContents: previewContents
        )
    } catch {
        print("Error reading the file: \(error.localizedDescription)")
        return [:]
    }
}

func parseArtistLinks(
    contents: String,
    previewContents: String? = nil
) -> [String: ArtistLinks] {
    let previewSelections =
        previewContents.map(parseArtistPreviewSelections) ?? [:]
    var artistDict = [String: ArtistLinks]()

    for row in contents.components(separatedBy: .newlines) {
        let columns = row.components(separatedBy: "~")
        guard columns.count >= 3 else {
            continue
        }

        let artistName = columns[0].trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !artistName.isEmpty, artistName != "Artist Name" else {
            continue
        }

        let normalizedArtistName = normalizeArtistLinkKey(artistName)
        let spotifyPart = columns[1].trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let appleMusicPart = columns[2].trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let links = ArtistLinks(
            spotifyURL: spotifyPart.isEmpty ? nil : spotifyPart,
            appleMusicURL: appleMusicPart.isEmpty ? nil : appleMusicPart,
            appleMusicPreviewSelection:
                previewSelections[artistName]
                ?? previewSelections[normalizedArtistName]
                ?? .automatic
        )

        artistDict[artistName] = links
        if artistDict[normalizedArtistName] == nil {
            artistDict[normalizedArtistName] = links
        }
    }

    return artistDict
}

private func parseArtistPreviewSelections(
    _ contents: String
) -> [String: ArtistAppleMusicPreviewSelection] {
    var previewSelections = [String: ArtistAppleMusicPreviewSelection]()

    for row in contents.components(separatedBy: .newlines) {
        let columns = row.components(separatedBy: "~")
        guard columns.count >= 2 else {
            continue
        }

        let artistName = columns[0].trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let selectionValue = columns[1].trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !artistName.isEmpty,
              artistName != "Artist Name",
              !selectionValue.isEmpty
        else {
            continue
        }

        let selection: ArtistAppleMusicPreviewSelection =
            selectionValue.caseInsensitiveCompare("disabled") == .orderedSame
            ? .disabled
            : .songURL(selectionValue)
        previewSelections[artistName] = selection
        let normalizedArtistName = normalizeArtistLinkKey(artistName)
        if previewSelections[normalizedArtistName] == nil {
            previewSelections[normalizedArtistName] = selection
        }
    }

    return previewSelections
}

private func loadArtistPreviewContents(
    forLinkResource linkResource: String
) -> String? {
    let suffix = "_artist_urls"
    guard linkResource.hasSuffix(suffix) else {
        return nil
    }

    let yearPrefix = linkResource.dropLast(suffix.count)
    let previewResource = "\(yearPrefix)_artist_preview_urls"
    guard let filepath = Bundle.main.path(
        forResource: previewResource,
        ofType: "csv"
    ) else {
        return nil
    }
    return try? String(contentsOfFile: filepath, encoding: .utf8)
}
