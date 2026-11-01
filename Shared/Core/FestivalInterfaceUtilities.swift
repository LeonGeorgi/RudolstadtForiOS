import Foundation

extension FeatureAvailability {
    var value: Value? {
        if case .available(let value) = self { return value }
        return nil
    }

    var isSupported: Bool {
        if case .unsupported = self { return false }
        return true
    }
}

extension LocalizedText {
    func resolved(locale: Locale = .current, defaultLanguage: LanguageTag? = nil) -> String {
        let requested = LanguageTag(locale.identifier.replacingOccurrences(of: "_", with: "-"))
        let base = requested.identifier.split(separator: "-").first.map(String.init)
        let matchingBase = values.keys.sorted { $0.identifier < $1.identifier }.first {
            $0.identifier.split(separator: "-").first.map(String.init) == base
        }
        for language in [requested, matchingBase, defaultLanguage].compactMap({ $0 }) {
            if let text = values[language], !text.isEmpty { return text }
        }
        return values.sorted { $0.key.identifier < $1.key.identifier }
            .first { !$0.value.isEmpty }?.value ?? ""
    }
}

extension FestivalCalendarDate {
    init(_ date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 0
        month = components.month ?? 0
        day = components.day ?? 0
    }

    var stableID: String { String(format: "%04d-%02d-%02d", year, month, day) }

    func date(in calendar: Calendar) -> Date? {
        let components = DateComponents(year: year, month: month, day: day)
        guard let value = calendar.date(from: components),
              Self(value, calendar: calendar) == self else { return nil }
        return value
    }
}

extension FestivalMetadata {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

extension FestivalData {
    func validateCore() throws {
        func unique<T: Hashable>(_ values: [T]) -> Bool { Set(values).count == values.count }
        let artists = Set(self.artists.map(\.id))
        let places = Set(stages.map(\.id))
        let days = Set(self.days.map(\.id))
        guard unique(self.artists.map(\.id)), unique(stages.map(\.id)),
              unique(events.map(\.id)), unique(self.days.map(\.id)),
              events.allSatisfy({ event in
                  artists.contains(event.artistID)
                      && event.startDate.map { $0.timeIntervalSinceReferenceDate.isFinite } != false
                      && event.placeID.map(places.contains) != false
                      && event.festivalDayID.map(days.contains) != false
                      && event.duration.map { $0.minutes > 0 && $0.minutes <= 1440 } != false
              }), self.days.allSatisfy({ $0.interval.duration > 0 && $0.interval.duration.isFinite
                  && $0.interval.start.timeIntervalSinceReferenceDate.isFinite }) else {
            throw FestivalLoadingError.invalidSnapshot
        }
    }

    func validate() throws {
        try validateCore()
        func unique<T: Hashable>(_ values: [T]) -> Bool { Set(values).count == values.count }
        let places = Set(stages.map(\.id))
        if let map = features.map.value {
            guard !map.maps.isEmpty, unique(map.maps.map(\.id)),
                  map.maps.contains(where: { $0.id == map.defaultMapID }) else {
                throw FestivalLoadingError.invalidSnapshot
            }
            for item in map.maps {
                switch item.content {
                case .geographic(let coordinates):
                    guard Set(coordinates.keys).isSubset(of: places),
                          coordinates.values.allSatisfy({
                              $0.latitude.isFinite && $0.longitude.isFinite
                                  && (-90...90).contains($0.latitude)
                                  && (-180...180).contains($0.longitude)
                          }) else { throw FestivalLoadingError.invalidSnapshot }
                case .illustrated(let artwork, let positions):
                    guard artwork.logicalSize.width.isFinite, artwork.logicalSize.height.isFinite,
                          artwork.logicalSize.width > 0, artwork.logicalSize.height > 0,
                          Set(positions.keys).isSubset(of: places), positions.values.allSatisfy({
                              $0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y)
                          }) else { throw FestivalLoadingError.invalidSnapshot }
                }
            }
        }
    }
}

extension FestivalData {
    func prepared(using metadata: FestivalMetadata) throws -> FestivalData {
        guard identity == nil || identity == metadata.identity else { throw FestivalLoadingError.wrongIdentity }
        try validateCore()
        let days = Dictionary(uniqueKeysWithValues: self.days.map { ($0.id, $0) })
        guard self.days.allSatisfy({ $0.date.date(in: metadata.calendar) != nil }),
              events.allSatisfy({ event in
                  if let start = event.startDate, let id = event.festivalDayID, let day = days[id] {
                      return start >= day.interval.start && start < day.interval.end
                  }
                  return true
              }) else { throw FestivalLoadingError.invalidSnapshot }
        var data = self
        data.identity = metadata.identity
        data.metadata = metadata
        data.festivalYear = self.days.first?.date.year ?? Int(metadata.identity.editionID) ?? festivalYear
        do { try validate() }
        catch { data.features = features.replacingMap(.unavailable(.invalidData)) }
        let daysByID = days
        data.artists = artists.map { original in
            var artist = original
            artist.defaultContentLanguage = metadata.defaultContentLanguage
            if let details = features.artistDetails.value?.details(for: artist.id) {
                artist.details = details
            }
            if let groupings = features.groupings.value {
                artist.groupIDs = Dictionary(uniqueKeysWithValues: groupings.groupings.map {
                    ($0.id, groupings.groupIDs(for: artist.id, in: $0.id))
                })
            }
            if let summaries = features.summaries.value {
                artist.localizedSummaries = Dictionary(uniqueKeysWithValues: summaries.availableLanguages(for: artist.id).compactMap {
                    language in summaries.summary(for: artist.id, language: language).map { (language, $0) }
                })
            }
            return artist
        }
        var coordinates = [FestivalPlaceID: FestivalCoordinate]()
        for map in data.features.map.value?.maps ?? [] {
            if case .geographic(let values) = map.content { coordinates.merge(values) { first, _ in first } }
        }
        data.stages = stages.map { original in
            var place = original
            place.defaultContentLanguage = metadata.defaultContentLanguage
            place.localizedDescriptions = features.placeDetails.value?.details(for: place.id)?.description ?? place.localizedDescriptions
            if let coordinate = coordinates[place.id] {
                place.latitude = coordinate.latitude
                place.longitude = coordinate.longitude
                place.locationIsApproximate = coordinate.isApproximate
            }
            place.mapCategory = data.features.map.value?.category(for: place.id)
            let admission = features.admission.value
            let categories = admission?.admission(for: place.id)?.categoryIDs ?? []
            place.admissionCategory = admission?.categories.first { categories.contains($0.id) }
            let areas = features.areas.value
            let areaIDs = areas?.areaIDs(for: place.id) ?? []
            place.area = areas?.areas.first { areaIDs.contains($0.id) }
            return place
        }
        let artistsByID = Dictionary(uniqueKeysWithValues: data.artists.map { ($0.id, $0) })
        let placesByID = Dictionary(uniqueKeysWithValues: data.stages.map { ($0.id, $0) })
        data.events = events.map { original in
            var event = original
            event.artist = artistsByID[event.artistID] ?? event.artist
            event.stage = placesByID[event.stage.id] ?? event.stage
            event.timeZone = metadata.timeZone
            event.programDay = event.festivalDayID.flatMap { daysByID[$0] }
            if let details = features.eventDetails.value?.details(for: event.id) {
                event.tags = details.tags
            }
            return event
        }
        data.areas = features.areas.value?.areas ?? []
        return data
    }
}

extension FestivalFeatures {
    func replacingMap(_ map: FeatureAvailability<any FestivalMapProviding>) -> FestivalFeatures {
        FestivalFeatures(information: information, artistDetails: artistDetails, placeDetails: placeDetails,
            eventDetails: eventDetails, admission: admission, summaries: summaries, groupings: groupings,
            similarities: similarities, areas: areas, map: map, sitePlan: sitePlan,
            distances: distances, automaticPlanning: automaticPlanning)
    }
}

enum FestivalLoadingError: Error, Equatable {
    case invalidSnapshot
    case unavailable
    case cacheDeletionFailed
    case wrongIdentity
}

extension FestivalDay {
    func label(calendar: Calendar, locale: Locale = .current) -> String {
        if let title { return title.resolved(locale: locale) }
        guard let date = date.date(in: calendar) else { return id }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }
}
