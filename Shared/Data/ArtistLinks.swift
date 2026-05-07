import Foundation

struct ArtistLinks {
    var spotifyURL: String?
    var appleMusicURL: String?

    var hasLinks: Bool {
        spotifyURL != nil || appleMusicURL != nil
    }
}

func normalizeArtistLinkKey(_ input: String) -> String {
    input
        .replacingOccurrences(of: "&#34;", with: "\"")
        .replacingOccurrences(of: "“", with: "\"")
        .replacingOccurrences(of: "”", with: "\"")
        .replacingOccurrences(of: "’", with: "'")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}

func parseArtistLinks() -> [String: ArtistLinks] {
    let resource = "\(DataStore.year)_artist_urls"
    let fallbackResource = "2026_artist_urls"
    guard
        let filepath =
            Bundle.main.path(forResource: resource, ofType: "csv")
            ?? Bundle.main.path(forResource: fallbackResource, ofType: "csv")
    else {
        print("File not found")
        return [:]
    }

    do {
        let contents = try String(contentsOfFile: filepath, encoding: .utf8)
        let rows = contents.components(separatedBy: "\n")

        var artistDict = [String: ArtistLinks]()

        for row in rows {
            let columns = row.components(separatedBy: "~")
            if columns.count >= 3 {
                let spotifyPart = columns[1].trimmingCharacters(in: .newlines)
                let appleMusicPart = columns[2].trimmingCharacters(
                    in: .newlines
                )
                let artistName = columns[0].trimmingCharacters(in: .newlines)

                // Skip header line.
                if artistName == "Artist Name" {
                    continue
                }

                let spotifyURL = spotifyPart.isEmpty ? nil : spotifyPart
                let appleMusicURL =
                    appleMusicPart.isEmpty ? nil : appleMusicPart

                let links = ArtistLinks(
                    spotifyURL: spotifyURL,
                    appleMusicURL: appleMusicURL
                )
                artistDict[artistName] = links

                let normalizedArtistName = normalizeArtistLinkKey(artistName)
                if artistDict[normalizedArtistName] == nil {
                    artistDict[normalizedArtistName] = links
                }
            }
        }

        return artistDict
    } catch {
        print("Error reading the file: \(error.localizedDescription)")
        return [:]
    }
}
