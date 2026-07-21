import Foundation
import Testing
@testable import Rudolstadt

struct AppleMusicPreviewServiceTests {
    @Test
    func catalogReferenceParsesSupportedAppleMusicURLs() throws {
        let artist = try #require(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/de/artist/adaya/480787867"
            )
        )
        let album = try #require(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/us/album/example/1723456789"
            )
        )
        let song = try #require(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/gb/song/example/987654321"
            )
        )
        let sharedAlbumTrack = try #require(
            AppleMusicCatalogReference(
                urlString:
                    "https://music.apple.com/de/album/timeout/1684345758"
                    + "?i=1684347458"
            )
        )

        #expect(artist.kind == .artist)
        #expect(artist.catalogID == 480_787_867)
        #expect(artist.storefront == "de")
        #expect(album.kind == .album)
        #expect(album.catalogID == 1_723_456_789)
        #expect(album.storefront == "us")
        #expect(song.kind == .song)
        #expect(song.catalogID == 987_654_321)
        #expect(song.storefront == "gb")
        #expect(sharedAlbumTrack.kind == .song)
        #expect(sharedAlbumTrack.catalogID == 1_684_347_458)
    }

    @Test
    func catalogReferenceRejectsInvalidHostAndCatalogID() {
        #expect(
            AppleMusicCatalogReference(
                urlString: "https://example.com/de/artist/adaya/480787867"
            ) == nil
        )
        #expect(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/de/artist/adaya/not-an-id"
            ) == nil
        )
        #expect(
            AppleMusicCatalogReference(
                urlString: "http://music.apple.com/de/artist/adaya/480787867"
            ) == nil
        )
    }

    @Test
    @MainActor
    func previewPlayerDefersLookupUntilPlaybackIsRequested() async throws {
        let recorder = AppleMusicPreviewRequestRecorder()
        let service = AppleMusicPreviewService { url in
            await recorder.record(url)
            throw AppleMusicPreviewServiceError.previewUnavailable
        }
        let player = AppleMusicPreviewPlayer(previewService: service)
        let reference = try #require(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/de/song/example/987654321"
            )
        )

        let requestBeforePlayback = await recorder.requestedURL
        #expect(requestBeforePlayback == nil)
        #expect(player.state == .idle)

        player.togglePlayback(for: reference)

        while await recorder.requestedURL == nil {
            await Task.yield()
        }
        while player.state == .loading {
            await Task.yield()
        }

        #expect(player.state == .unavailable)
    }

    @Test
    func artistLookupUsesFirstMatchingSongWithExactArtistID() async throws {
        let recorder = AppleMusicPreviewRequestRecorder()
        let responseData = Data(
            """
            {
              "resultCount": 3,
              "results": [
                {
                  "wrapperType": "artist",
                  "artistId": 480787867,
                  "artistName": "Adaya"
                },
                {
                  "wrapperType": "track",
                  "kind": "song",
                  "artistId": 111,
                  "collectionId": 222,
                  "trackId": 333,
                  "artistName": "Featured Collaborator",
                  "trackName": "Featured Song",
                  "previewUrl": "https://audio.example/featured.m4a"
                },
                {
                  "wrapperType": "track",
                  "kind": "song",
                  "artistId": 480787867,
                  "collectionId": 444,
                  "trackId": 555,
                  "artistName": "Adaya",
                  "trackName": "Dandelion",
                  "previewUrl": "https://audio.example/dandelion.m4a"
                }
              ]
            }
            """.utf8
        )
        let service = AppleMusicPreviewService { url in
            await recorder.record(url)
            return AppleMusicPreviewHTTPResponse(
                data: responseData,
                statusCode: 200
            )
        }
        let reference = try #require(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/de/artist/adaya/480787867"
            )
        )

        let preview = try await service.fetchPreview(for: reference)
        let recordedURL = await recorder.requestedURL
        let requestedURL = try #require(recordedURL)
        let query = try queryItems(in: requestedURL)

        #expect(preview.trackName == "Dandelion")
        #expect(preview.artistName == "Adaya")
        #expect(
            preview.previewURL.absoluteString
                == "https://audio.example/dandelion.m4a"
        )
        #expect(query["limit"] == "50")
        #expect(query["sort"] == nil)
    }

    @Test
    func artistLookupRejectsSongsWithoutExactArtistID() async throws {
        let responseData = Data(
            """
            {
              "resultCount": 1,
              "results": [
                {
                  "wrapperType": "track",
                  "kind": "song",
                  "artistId": 111,
                  "collectionId": 222,
                  "trackId": 333,
                  "artistName": "Featured Collaborator",
                  "trackName": "Featured Song",
                  "previewUrl": "https://audio.example/featured.m4a"
                }
              ]
            }
            """.utf8
        )
        let service = AppleMusicPreviewService { _ in
            AppleMusicPreviewHTTPResponse(
                data: responseData,
                statusCode: 200
            )
        }
        let reference = try #require(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/de/artist/adaya/480787867"
            )
        )

        await #expect(throws: AppleMusicPreviewServiceError.self) {
            try await service.fetchPreview(for: reference)
        }
    }

    @Test
    func albumLookupSelectsMatchingCollectionAndBuildsExpectedQuery()
        async throws
    {
        let recorder = AppleMusicPreviewRequestRecorder()
        let responseData = Data(
            """
            {
              "resultCount": 2,
              "results": [
                {
                  "wrapperType": "track",
                  "kind": "song",
                  "artistId": 1,
                  "collectionId": 99,
                  "trackId": 2,
                  "artistName": "Other Artist",
                  "trackName": "Other Song",
                  "previewUrl": "https://audio.example/other.m4a"
                },
                {
                  "wrapperType": "track",
                  "kind": "song",
                  "artistId": 3,
                  "collectionId": 1723456789,
                  "trackId": 4,
                  "artistName": "Expected Artist",
                  "trackName": "Expected Song",
                  "previewUrl": "https://audio.example/expected.m4a"
                }
              ]
            }
            """.utf8
        )
        let service = AppleMusicPreviewService { url in
            await recorder.record(url)
            return AppleMusicPreviewHTTPResponse(
                data: responseData,
                statusCode: 200
            )
        }
        let reference = try #require(
            AppleMusicCatalogReference(
                urlString: "https://music.apple.com/us/album/example/1723456789"
            )
        )

        let preview = try await service.fetchPreview(for: reference)
        let recordedURL = await recorder.requestedURL
        let requestedURL = try #require(recordedURL)
        let components = try #require(
            URLComponents(url: requestedURL, resolvingAgainstBaseURL: false)
        )
        let query = try queryItems(in: requestedURL)

        #expect(preview.trackName == "Expected Song")
        #expect(components.scheme == "https")
        #expect(components.host == "itunes.apple.com")
        #expect(components.path == "/lookup")
        #expect(query["id"] == "1723456789")
        #expect(query["entity"] == "song")
        #expect(query["limit"] == "10")
        #expect(query["country"] == "US")
        #expect(query["sort"] == nil)
    }

    @Test
    func songLookupSelectsExactTrackAndDoesNotRequestRecentSorting()
        async throws
    {
        let recorder = AppleMusicPreviewRequestRecorder()
        let responseData = Data(
            """
            {
              "resultCount": 2,
              "results": [
                {
                  "wrapperType": "track",
                  "kind": "song",
                  "artistId": 1,
                  "collectionId": 99,
                  "trackId": 2,
                  "artistName": "Other Artist",
                  "trackName": "Other Song",
                  "previewUrl": "https://audio.example/other.m4a"
                },
                {
                  "wrapperType": "track",
                  "kind": "song",
                  "artistId": 1439919935,
                  "collectionId": 1439919925,
                  "trackId": 1439920240,
                  "artistName": "Alex Boldin",
                  "trackName": "Fingerstyle Blues",
                  "previewUrl": "https://audio.example/fingerstyle.m4a"
                }
              ]
            }
            """.utf8
        )
        let service = AppleMusicPreviewService { url in
            await recorder.record(url)
            return AppleMusicPreviewHTTPResponse(
                data: responseData,
                statusCode: 200
            )
        }
        let reference = try #require(
            AppleMusicCatalogReference(
                urlString:
                    "https://music.apple.com/de/song/fingerstyle-blues/1439920240"
            )
        )

        let preview = try await service.fetchPreview(for: reference)
        let recordedURL = await recorder.requestedURL
        let requestedURL = try #require(recordedURL)
        let query = try queryItems(in: requestedURL)

        #expect(preview.trackName == "Fingerstyle Blues")
        #expect(query["id"] == "1439920240")
        #expect(query["limit"] == "10")
        #expect(query["sort"] == nil)
    }

    @Test
    func artistLinksUseCuratedPreviewWithoutReplacingProfileLink() throws {
        let profileURL =
            "https://music.apple.com/de/artist/alex-boldin/1439919935"
        let previewURL =
            "https://music.apple.com/de/song/conversation/1439919937"
        let links = parseArtistLinks(
            contents: "Artist Name~Spotify URL~Apple Music URL\n"
                + "Alex Boldin~~\(profileURL)\n"
                + "No Preview~~https://music.apple.com/de/artist/example/1\n"
                + "Invalid Override~~https://music.apple.com/de/artist/example/2\n",
            previewContents: "Artist Name~Apple Music Preview URL\n"
                + "ÁLEX BOLDIN~\(previewURL)\n"
                + "No Preview~disabled\n"
                + "Invalid Override~https://music.apple.com/de/artist/example/2\n"
        )

        let exactLinks = try #require(links["Alex Boldin"])
        let normalizedLinks = try #require(
            links[normalizeArtistLinkKey("Alex Boldin")]
        )

        #expect(exactLinks.appleMusicURL == profileURL)
        #expect(
            exactLinks.appleMusicPreviewSelection == .songURL(previewURL)
        )
        #expect(
            normalizedLinks.appleMusicPreviewSelection == .songURL(previewURL)
        )
        #expect(exactLinks.appleMusicPreviewReference?.kind == .song)
        #expect(
            exactLinks.appleMusicPreviewReference?.catalogID == 1_439_919_937
        )
        #expect(
            links["No Preview"]?.appleMusicPreviewSelection == .disabled
        )
        #expect(links["No Preview"]?.appleMusicPreviewReference == nil)
        #expect(links["Invalid Override"]?.appleMusicPreviewReference == nil)
    }

    private func queryItems(in url: URL) throws -> [String: String] {
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )
        return Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).compactMap {
                item in
                item.value.map { (item.name, $0) }
            }
        )
    }
}

private actor AppleMusicPreviewRequestRecorder {
    private(set) var requestedURL: URL?

    func record(_ url: URL) {
        requestedURL = url
    }
}
