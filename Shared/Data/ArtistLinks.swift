import Foundation

struct ArtistLinks {
    var spotifyURL: String?
    var appleMusicURL: String?
}

func parseArtistLinks() -> [String: ArtistLinks] {
    guard let filepath = Bundle.main.path(forResource: "2024_artist_urls", ofType: "csv") else {
        print("File not found")
        return [:]
    }

    do {
        let contents = try String(contentsOfFile: filepath)
        let rows = contents.components(separatedBy: "\n")
        
        var artistDict = [String: ArtistLinks]()
        
        for row in rows {
            let columns = row.components(separatedBy: "~")
            if columns.count >= 3 {
                let artistName = columns[0].trimmingCharacters(in: .newlines)
                let spotifyURL = columns[1].isEmpty ? nil : columns[1].trimmingCharacters(in: .newlines)
                let appleMusicURL = columns[2].isEmpty ? nil : columns[2].trimmingCharacters(in: .newlines)
                
                let links = ArtistLinks(spotifyURL: spotifyURL, appleMusicURL: appleMusicURL)
                print("Artist: \(artistName), Spotify: \(spotifyURL ?? "nil"), Apple Music: \(appleMusicURL ?? "nil")")
                artistDict[artistName] = links
            }
        }
        
        return artistDict
    } catch {
        print("Error reading the file: \(error.localizedDescription)")
        return [:]
    }
}
