//
// Created by Leon on 22.03.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import Foundation

class ScheduleGenerator2 {

    init(allEvents: [Event], storedEventIds: [Int], allArtists: [Artist], artistRatings: Dictionary<String, Int>) {
        self.allEvents = allEvents
        self.storedEventIds = Set(storedEventIds)
        self.allArtists = allArtists
        var dict: [Int: Int] = [:]
        for (idAsString, rating) in artistRatings {
            dict[Int(idAsString)!] = rating
        }
        self.artistRatings = dict
    }

    let allEvents: [Event]
    let storedEventIds: Set<Int>
    let allArtists: [Artist]
    let artistRatings: [Int: Int]

    var artistEventCache: Dictionary<Int, [Event]> = Dictionary()


    func generate() -> [Event] {
        let storedEvents = allEvents.filter { event in
            storedEventIds.contains(event.id)
        }
        let storedArtistIds: Set<Int> = Set(storedEvents.map { event in
            event.artist.id
        })
        let interestingEvents = allEvents.filter { event in
            (artistRatings[event.artist.id] ?? 0) > 0 && !intersects(events: storedEvents, current: event)
        }
        let interestingArtists = allArtists.filter { artist in
            (artistRatings[artist.id] ?? 0) > 0
        }
        let interestingArtistIds = interestingArtists.map {
            $0.id
        }

        // Generate start solution
        var solution: [Event] = storedEvents
        for event in interestingEvents.shuffled() {
            if !solution.contains(where: { (solutionEvent: Event) in
                solutionEvent.artist.id == event.artist.id || solutionEvent.intersects(with: event)
            }) {
                solution.append(event)
            }
        }
        var t = 0

        // Calculate solution score
        var score = 0
        for event in solution {
            score += calculateScore(for: event)
        }
        let iterations = max(200, min(interestingEvents.count * 10, 1000))
        print("Iterations: \(iterations)")
        print("Initial score \(score)")
        while t < iterations {
            // Step 2: Choose next element
            // 2.1: Calculate artists not included
            let solutionArtistIds = Set(solution.map {
                $0.artist.id
            })
            let artistIds = Set(interestingArtistIds.filter { artistId in
                !solutionArtistIds.contains(artistId)
            })

            // 2.2: Calculate event to replace
            let events = interestingEvents.filter { event in
                artistIds.contains(event.artist.id)
            }
            guard let newEvent: Event = events.randomElement() else {
                print("Optimal solution found")
                break
            }

            // 2.3: Calculate replaced events
            let replacedEvents: Array<Event> = solution.filter {
                $0.intersects(with: newEvent)
            }

            // Step 3: Do or don't
            var replace: Bool = false
            var scoreDiff = calculateScore(for: newEvent)
            for event in replacedEvents {
                scoreDiff -= calculateScore(for: event)
            }
            let oldScore = score
            let newScore = oldScore + scoreDiff

            if newScore >= oldScore {
                // New solution is definitely not worse
                replace = true
            } else {
                // Select with decreasing probability
                let probability = Float(iterations - t) / Float(iterations * 10) * Float(17 + scoreDiff) / 17.0
                if Float.random(in: 0.0..<1.0) < probability {
                    print("\(oldScore) -> \(newScore)")
                    replace = true
                }
            }

            if replace {
                for event in replacedEvents {
                    if let index = solution.firstIndex(where: { $0.id == event.id }) {
                        solution.remove(at: index)
                    }
                }
                solution.append(newEvent)
                score = newScore
            }

            t += 1

        }
        score = 0
        for event in solution {
            score += calculateScore(for: event)
        }
        print("Final score \(score)")
        solution.sort { event, event2 in
            event.festivalDay < event2.festivalDay || event.startTimeInMinutes < event2.startTimeInMinutes
        }
        return solution


        /*for event in finalEvents {
            print((event.shortWeekDay, event.timeAsString, event.artist.name))
        }*/
        /*return finalEvents.sorted { event, event2 in
            event.startTimeInMinutes < event2.startTimeInMinutes
        }*/
    }

    func calculateScore(for event: Event) -> Int {
        let rating = (artistRatings[event.artist.id] ?? 0)
        return rating * rating
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
        events.contains { event in
            let collides = event.intersects(with: current)
            /*if collides {
                print("collides with \(event.shortWeekDay) \(event.timeAsString) \(event.artist.name)")
            }*/
            return collides
        }
    }
}