import CryptoKit
import Foundation
import Nuke
import Testing
import UIKit
@testable import Rudolstadt

@MainActor
struct FantasyFestivalTests {
    @Test
    func registrationIsRestrictedToDebug() {
        let identity = FestivalIdentity(festivalID: "fantasy", editionID: "2027")
        #if DEBUG
        #expect(FestivalRegistry.catalog.adapter(for: identity) != nil)
        #expect(FestivalEdition.availableEditions.contains { $0.identity == identity })
        #else
        #expect(FestivalRegistry.catalog.adapter(for: identity) == nil)
        #expect(!FestivalEdition.availableEditions.contains { $0.identity == identity })
        #expect(Bundle.main.url(forResource: "program", withExtension: "json", subdirectory: "FantasyFestival") == nil)
        #endif
    }

    #if DEBUG
    @Test(arguments: [30, 150])
    func manyFavoriteArtistsProduceSeveralRecommendationsPerDay(favoriteCount: Int) async throws {
        let program = try #require(try await FantasyFestivalDataProvider.makeAdapter().loadBundledProgram())
        let favorites = program.artists.prefix(favoriteCount)
        let ratings = Dictionary(uniqueKeysWithValues: favorites.map { (String($0.id), 2) })
        let firstStart = try #require(program.events.compactMap(\.startDate).min())
        let snapshot = RecommendationService().buildSnapshot(
            data: program, savedEventIds: [], ratings: ratings,
            now: firstStart.addingTimeInterval(-3600))
        let ids = Set(snapshot.recommendedEventIds)
        let selected = program.events.filter { ids.contains($0.id) }
        #expect(Set(selected.map(\.artistID)).count == selected.count)
        let planning = try #require(program.features.automaticPlanning.value)
        for day in program.days {
            let concerts = selected.filter { $0.festivalDayID == day.id }.sorted(by: Event.precedes)
            #expect(concerts.count >= 2, "Expected several concerts on \(day.id), with \(favoriteCount) favorite artists")
            for (first, second) in zip(concerts, concerts.dropFirst()) {
                let transfer = try #require(planning.transfer(from: first.stage.id, to: second.stage.id))
                #expect(transfer.coordinatesAreApproximate)
                let start = try #require(first.startDate)
                let nextStart = try #require(second.startDate)
                let duration = try #require(first.durationMinutes)
                let arrival = start.addingTimeInterval(Double(duration + transfer.estimatedMinutes + 2) * 60)
                #expect(arrival <= nextStart)
            }
        }
        print("Fantasy favorites: \(favoriteCount), recommended: \(selected.count), per day: \(program.days.map { day in selected.filter { $0.festivalDayID == day.id }.count })")
    }

    @Test
    func completeProgramCoversFourDaysAndRetainsMidnightConcerts() async throws {
        let adapter = FantasyFestivalDataProvider.makeAdapter()
        let program = try #require(try await adapter.loadBundledProgram())
        #expect(program.identity == FantasyFestivalDataProvider.identity)
        #expect(program.provenance?.source == .bundledExperiment)
        #expect(adapter.loadingStrategy == .bundledOnly)
        #expect(adapter.metadata.notices.isEmpty)
        #expect(program.artists.count == 150)
        #expect(program.stages.count == 12)
        #expect(program.events.count == 500)
        #expect(program.days.map(\.id) == ["2027-07-15", "2027-07-16", "2027-07-17", "2027-07-18"])
        #expect(Set(program.events.map(\.artistID)).count == 150)
        #expect(Set(program.events.map(\.placeID)).count == 12)
        #expect(program.events.allSatisfy { $0.hasCompleteMetadata && $0.duration?.isEstimated == false })
        #expect(program.events.contains { $0.festivalHour >= 24 })
        #expect(Dictionary(grouping: program.events, by: \.festivalDayID).values.allSatisfy { $0.count == 125 })
        #expect(program.features.eventDetails.isSupported)
        #expect(program.features.automaticPlanning.isSupported)
        #expect(program.features.map.value?.maps.count == 1)
        #expect(program.features.groupings.value?.groupings.contains { $0.id == "genre" } == true)
        let credits = try #require(program.features.information.value?.page(for: "fantasy-photo-credits"))
        #expect(credits.links.filter { $0.id.hasPrefix("photo-") }.count == 150)
        #expect(credits.links.contains { $0.id.hasPrefix("license-") })
        let textCredits = try #require(program.features.information.value?.page(for: "fantasy-text-credits"))
        #expect(textCredits.links.filter { $0.id != "text-license" }.count == 300)
        #expect(program.artists.allSatisfy {
            ($0.descriptionGerman?.count ?? 0) >= 400 && ($0.descriptionEnglish?.count ?? 0) >= 400
        })
        #expect(program.artists.contains { ($0.descriptionGerman?.count ?? 0) > 3000 })
        #expect(program.artists.contains { ($0.descriptionEnglish?.count ?? 0) > 3000 })
        #expect(program.artists.contains { $0.name == "Michael Jackson" })
        #expect(!adapter.services.news.isSupported)
        #expect(!adapter.services.publicLinks.isSupported)
    }

    @Test
    func eachActHasAnOfflinePhotoWithUniqueContentsAndAttribution() async throws {
        let program = try #require(try await FantasyFestivalDataProvider.makeAdapter().loadBundledProgram())
        var imageHashes = Set<String>()
        var thumbnailHashes = Set<String>()
        for artist in program.artists {
            let imageURL = try #require(artist.fullImageUrl)
            let thumbnailURL = try #require(artist.thumbImageUrl)
            #expect(imageURL.isFileURL)
            #expect(thumbnailURL.isFileURL)
            let imageData = try Data(contentsOf: imageURL)
            let thumbnailData = try Data(contentsOf: thumbnailURL)
            imageHashes.insert(SHA256.hash(data: imageData).description)
            thumbnailHashes.insert(SHA256.hash(data: thumbnailData).description)
            #expect(UIImage(data: imageData) != nil)
            #expect(UIImage(data: thumbnailData) != nil)
            #expect(artist.additionalLinks.contains { $0.id == "photo" && $0.destination.host == "commons.wikimedia.org" })
        }
        #expect(imageHashes.count == 150)
        #expect(thumbnailHashes.count == 150)
        // Exercise the same image pipeline as the actual artist views, using a
        // bundled file URL rather than relying only on direct UIImage decoding.
        let first = try #require(program.artists.first?.thumbImageUrl)
        let image = try await ImagePipeline.shared.image(for: first)
        #expect(image.size.width > 0)
    }

    @Test
    func personalStateIsIsolatedAndRestoresAfterSwitchingFestivals() async throws {
        let defaults = TestFixtures.isolatedUserDefaults()
        let adapter = FantasyFestivalDataProvider.makeAdapter()
        let program = try #require(try await adapter.loadBundledProgram())
        let artist = try #require(program.artists.first)
        let event = try #require(program.events.first)
        let fantasy = FestivalRegistry.makeProfileStore(metadata: adapter.metadata, defaults: defaults)
        fantasy.setArtistRating(for: artist, rating: 2)
        fantasy.setArtistNote(for: artist, note: "Fantasy test note")
        fantasy.toggleSavedEvent(event)
        await fantasy.flushPendingPersistence()
        let restored = FestivalRegistry.makeProfileStore(metadata: adapter.metadata, defaults: defaults)
        #expect(!restored.usesFirebaseSync)
        #expect(restored.rating(for: artist.id) == 2)
        #expect(restored.artistNotes[String(artist.id)] == "Fantasy test note")
        #expect(restored.isEventSaved(event.id))
        let regular = FestivalRegistry.makeProfileStore(metadata: FestivalEdition.current.metadata, defaults: defaults)
        #expect(regular.artistNotes[String(artist.id)] == nil)
        #expect(!regular.isEventSaved(event.id))
    }
    #endif
}
