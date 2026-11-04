import Foundation
import RudolstadtCore

struct ArtistShareLink: Equatable {
    private static let hosts = ["festival.leongeorgi.de", "rudolstadt.leongeorgi.de"]

    let year: Int
    let artistID: Int
    let eventID: Int?

    init(year: Int, artistID: Int, eventID: Int? = nil) {
        self.year = year
        self.artistID = artistID
        self.eventID = eventID
    }

    private var core: ArtistPublicLink? {
        guard (1000...9999).contains(year), artistID > 0 else { return nil }
        return ArtistPublicLink(
            year: Int32(year), artistID: Int64(artistID),
            eventID: eventID.map { KotlinLong(value: Int64($0)) })
    }

    var url: URL? {
        guard let value = core?.url() else { return nil }
        return URL(string: value)
    }

    func selectedEventID(in events: [Event]) -> Int? {
        core?.selectedEventID(events: events)?.intValue
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
            + (components.percentEncodedQuery.map { "?" + $0 } ?? "")
        let value = KotlinCore.bridge.parseArtistLink(value: canonical)
        guard let value else { return nil }
        let year = Int(value.year)
        let artistID = Int(value.artistID)
        self.init(year: year, artistID: artistID, eventID: value.eventID?.intValue)
    }
}
