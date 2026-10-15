import Foundation

struct ArtistShareLink: Equatable {
    private static let host = "rudolstadt.leongeorgi.de"

    let year: Int
    let artistID: Int

    init(year: Int, artistID: Int) {
        self.year = year
        self.artistID = artistID
    }

    var url: URL? {
        guard (1000...9999).contains(year), artistID > 0 else {
            return nil
        }
        return URL(string: "https://\(Self.host)/\(year)/artists/\(artistID)")
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == Self.host,
              components.user == nil,
              components.password == nil,
              components.port == nil || components.port == 443
        else {
            return nil
        }

        let path = url.pathComponents
        guard path.count == 4,
              path[1].count == 4,
              let year = Int(path[1]), year > 0,
              String(year) == path[1],
              path[2] == "artists",
              let artistID = Int(path[3]), artistID > 0,
              String(artistID) == path[3]
        else {
            return nil
        }

        self.init(year: year, artistID: artistID)
    }
}
