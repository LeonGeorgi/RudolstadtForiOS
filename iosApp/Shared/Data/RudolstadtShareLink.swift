import Foundation

struct ArtistShareLink: Equatable {
    private static let hosts = ["festival.leongeorgi.de", "rudolstadt.leongeorgi.de"]

    let year: Int
    let artistID: Int

    init(year: Int, artistID: Int) {
        self.year = year
        self.artistID = artistID
    }

    var url: URL? {
        guard (1000...9999).contains(year), artistID > 0 else { return nil }
        return KotlinCore.bridge.artistLink(year: Int32(year), artistID: Int64(artistID)).flatMap(URL.init(string:))
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(),
              Self.hosts.contains(host),
              components.user == nil,
              components.password == nil,
              components.port == nil || components.port == 443
        else {
            return nil
        }

        let canonical = "https://" + host + "/" + url.pathComponents.dropFirst().joined(separator: "/")
        let value = KotlinCore.bridge.parseArtistLink(value: canonical)
        guard let value else { return nil }
        let year = Int(value.year)
        let artistID = Int(value.artistID)
        self.init(year: year, artistID: artistID)
    }
}
