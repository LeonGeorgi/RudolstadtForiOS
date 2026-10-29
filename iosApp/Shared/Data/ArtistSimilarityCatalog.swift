import Foundation
import OSLog
import RudolstadtCore

/// Precomputed description similarities for one festival year.
struct ArtistSimilarityCatalog: Decodable {
    let festivalYear: Int
    /// IDs already filtered by similarity and ranked by the export script.
    let similarArtistIDsByArtistID: [Int: [Int]]

    static let bundled = loadBundled()

    func similarArtists(
        to artist: Artist,
        among availableArtists: [Artist],
        festivalYear: Int,
        limit: Int = 5
    ) -> [Artist] {
        coreCatalog(for: festivalYear)?.similarArtists(
            id: artist.artistID, artists: availableArtists, limit: Int32(limit)) ?? []
    }

    func coreCatalog(for year: Int) -> ProgramSimilarityCatalog? {
        guard festivalYear == year else { return nil }
        return ProgramSimilarityCatalog(values: similarArtistIDsByArtistID.map {
            SimilarArtistIDs(artistID: Int64($0.key), similarIDs: KotlinCore.ids($0.value))
        })
    }

    private static func loadBundled() -> ArtistSimilarityCatalog {
        let empty = ArtistSimilarityCatalog(
            festivalYear: FestivalConfiguration.year,
            similarArtistIDsByArtistID: [:]
        )
        guard let url = Bundle.main.url(
            forResource: "\(FestivalConfiguration.year)_artist_similarities",
            withExtension: "json"
        ) else {
            AppLog.data.error("Missing bundled artist similarities")
            return empty
        }
        do {
            return try JSONDecoder().decode(
                ArtistSimilarityCatalog.self,
                from: Data(contentsOf: url)
            )
        } catch {
            AppLog.data.error(
                "Could not decode bundled artist similarities: \(error.localizedDescription)"
            )
            return empty
        }
    }
}
