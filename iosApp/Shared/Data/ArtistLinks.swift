import Foundation
import RudolstadtCore

enum ArtistAppleMusicPreviewSelection: Equatable, Sendable {
    case automatic
    case disabled
    case songURL(String)
}

typealias ArtistLinks = CuratedArtistLinks
extension CuratedArtistLinks: @unchecked @retroactive Sendable {
    convenience init(
        spotifyURL: String? = nil, appleMusicURL: String? = nil,
        appleMusicPreviewSelection: ArtistAppleMusicPreviewSelection
    ) {
        let preview: String; let url: String?
        switch appleMusicPreviewSelection {
        case .automatic: preview = "automatic"; url = nil
        case .disabled: preview = "disabled"; url = nil
        case .songURL(let value): preview = "songURL"; url = value
        }
        self.init(
            spotifyURL: spotifyURL, appleMusicURL: appleMusicURL, preview: preview, previewURL: url)
    }
    var appleMusicPreviewSelection: ArtistAppleMusicPreviewSelection {
        switch preview {
        case "disabled": return .disabled
        case "songURL":
            return previewURL.map(ArtistAppleMusicPreviewSelection.songURL) ?? .automatic
        default: return .automatic
        }
    }
    var core: CuratedArtistLinks { self }
    var hasLinks: Bool {
        spotifyURL != nil || appleMusicURL != nil
    }

    var appleMusicPreviewReference: AppleMusicCatalogReference? {
        MediaLinks.shared.previewReference(
            links: self,
            parse: { value in
                URL(string: value).map(MediaURLParts.init)
            })
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
    let values = KotlinCore.bridge.curatedLinks(contents: contents, previewContents: previewContents,
        normalize: { normalizeArtistLinkKey($0) })
    return values
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
