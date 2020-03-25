//
// Created by Leon on 22.03.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation

class ScheduleGenerator {

    init(allEvents: [Event], storedEventIds: [Int], allArtists: [Artist], artistRatings: Dictionary<String, Int>) {
        self.allEvents = allEvents
        self.storedEventIds = storedEventIds
        self.allArtists = allArtists
        self.artistRatings = artistRatings
    }

    let allEvents: [Event]
    let storedEventIds: [Int]
    let allArtists: [Artist]
    let artistRatings: Dictionary<String, Int>

    var artistEventCache: Dictionary<Int, [Event]> = Dictionary()

    var artistsWithRatings: [(Artist, Int)] {
        artistRatings.map { item in
            (allArtists.first { artist in
                artist.id == Int(item.key)
            }!, item.value)
        }
    }

    func generate() -> [Event] {
        let storedEvents = allEvents.filter { event in
            storedEventIds.contains(event.id)
        }
        let storedArtistIds: Set<Int> = Set(storedEvents.map { event in
            event.artist.id
        })
        let artistsByRating: Dictionary<Int, [(Artist, Int)]> = Dictionary(grouping: artistsWithRatings) { element in
            element.1
        }
        let sortedRatings = artistsByRating.keys.sorted(by: >)
        var finalEvents: [Event] = []
        for rating in sortedRatings {
            if rating == 0 {
                continue
            }
            let artistsToAdd = artistsByRating[rating]!.map { item in
                item.0
            }.filter { artist in
                !storedArtistIds.contains(artist.id)
            }
            if artistsToAdd.isEmpty {
                continue
            }
            print(rating)
            finalEvents.append(contentsOf: generateArrangement(
                    finalEvents: storedEvents + finalEvents,
                    remainingArtists: artistsToAdd,
                    currentPlannedEvents: [],
                    currentRating: 0,
                    bestPossibleRating: artistsToAdd.count).events)


        }
        for event in finalEvents {
            print((event.shortWeekDay, event.timeAsString, event.artist.name))
        }
        return finalEvents.sorted { event, event2 in
            event.startTimeInMinutes < event2.startTimeInMinutes
        }
    }

    func generateArrangement(
            finalEvents: [Event],
            remainingArtists: [Artist],
            currentPlannedEvents: [Event],
            currentRating: Int,
            bestPossibleRating: Int
    ) -> (events: [Event], rating: Int, bestRatingReached: Bool) {
        var remArtists = remainingArtists
        let currentArtist = remArtists.remove(at: 0)
        print(currentArtist)
        let currentArtistEvents = eventsFor(artist: currentArtist).sorted { event1, event2 in
            (!intersects(events: finalEvents, current: event1) &&
                    !intersects(events: currentPlannedEvents, current: event2)) ||
                    (intersects(events: finalEvents, current: event2) ||
                            intersects(events: currentPlannedEvents, current: event2))
        }
        var plans: [([Event], Int)] = []
        for event in currentArtistEvents {
            let collides = intersects(events: finalEvents, current: event) || intersects(events: currentPlannedEvents, current: event)
            if !remArtists.isEmpty {
                let (plan, rating, reached) = generateArrangement(
                        finalEvents: finalEvents,
                        remainingArtists: remArtists,
                        currentPlannedEvents: collides ? currentPlannedEvents : currentPlannedEvents + [event],
                        currentRating: currentRating + (collides ? 0 : 1),
                        bestPossibleRating: bestPossibleRating)
                if reached {
                    return (plan, rating, reached)
                } else {
                    plans.append((plan, rating))
                }
            } else {
                let newCurrentPlannedEvents = collides ? currentPlannedEvents : currentPlannedEvents + [event]
                let newCurrentRating = currentRating + (collides ? 0 : 1)
                if newCurrentRating >= bestPossibleRating {
                    return (newCurrentPlannedEvents, newCurrentRating, true)
                } else {
                    plans.append((newCurrentPlannedEvents, newCurrentRating))
                }
            }
        }
        let bestPlan = plans.max { tuple, tuple2 in
            tuple.1 < tuple2.1
        }!
        return (bestPlan.0, bestPlan.1, false)
    }

    func eventsFor(artist: Artist) -> [Event] {
        if let cachedEvents = artistEventCache[artist.id] {
            return cachedEvents
        } else {
            let events = allEvents.filter { event in
                event.artist.id == artist.id
            }
            artistEventCache[artist.id] = events
            return events
        }
    }

    func intersects(events: [Event], current: Event) -> Bool {
        return events.contains { event in
            let collides = intersect(first: event, second: current)
            /*if collides {
                print("collides with \(event.shortWeekDay) \(event.timeAsString) \(event.artist.name)")
            }*/
            return collides
        }
    }

    func intersect(first: Event, second: Event) -> Bool {
        first.festivalDay == second.festivalDay &&
                !(first.startTimeInMinutes >= second.endTimeInMinutes || first.endTimeInMinutes <= second.startTimeInMinutes)
    }
}