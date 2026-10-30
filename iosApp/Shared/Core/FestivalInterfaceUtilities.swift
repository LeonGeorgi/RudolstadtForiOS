import Foundation
import RudolstadtCore

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
        KotlinCore.bridge.resolveText(
            values: Dictionary(uniqueKeysWithValues: values.map { ($0.key.identifier, $0.value) }),
            requested: locale.identifier, defaultLanguage: defaultLanguage?.identifier)
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
            Self(value, calendar: calendar) == self
        else { return nil }
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
        guard ProgramPreparation.shared.valid(program: coreProgram, days: days.map(\.core.date))
        else { throw FestivalLoadingError.invalidSnapshot }
    }

    func validate() throws {
        try validateCore()
        try validateMaps()
    }

    private func validateMaps() throws {
        if let map = features.map.value {
            guard
                KotlinCore.bridge.validMaps(
                    maps: map.maps.map { CoreMapGeometry($0).core },
                    defaultID: map.defaultMapID, places: Set(stages.map { $0.id.coreID }))
            else { throw FestivalLoadingError.invalidSnapshot }
        }
    }
}

extension FestivalData {
    func prepared(using metadata: FestivalMetadata) throws -> FestivalData {
        guard identity == nil || identity == metadata.identity else {
            throw FestivalLoadingError.wrongIdentity
        }
        var data = self
        data.identity = metadata.identity
        data.metadata = metadata
        do { try validateMaps() } catch {
            data.features = features.replacingMap(.unavailable(.invalidData))
        }
        var coordinates = [FestivalPlaceID: FestivalCoordinate]()
        for map in data.features.map.value?.maps ?? [] {
            if case .geographic(let values) = map.content { coordinates.merge(values) { first, _ in first } }
        }
        let artists = artists.map { artist in
            let catalog = (features.artistDetails.value as? FestivalArtistCatalog)?.artist(
                id: artist.artistID)
            let groupingCatalog = (features.groupings.value as? FestivalArtistCatalog)?.artist(
                id: artist.artistID)
            let summaryCatalog = (features.summaries.value as? FestivalArtistCatalog)?.artist(
                id: artist.artistID)
            return ArtistMetadata(artistID: artist.artistID,
                content: catalog?.content ?? features.artistDetails.value?.details(for: artist.id)?.core,
                groups: groupingCatalog?.groups ?? features.groupings.value.map { provider in
                    Dictionary(uniqueKeysWithValues: provider.groupings.map {
                                ($0.id, provider.groupIDs(for: artist.id, in: $0.id).sorted())
                            })
                    },
                summaries: summaryCatalog?.summaries ?? features.summaries.value.map { provider in
                    provider.availableLanguages(for: artist.id).sorted { $0.identifier < $1.identifier }
                        .compactMap { provider.summary(for: artist.id, language: $0)?.core }
                    })
        }
        let places = stages.map { place in
            let admission = features.admission.value
            let categories = admission?.admission(for: place.id)?.categoryIDs ?? []
            let areas = features.areas.value
            let areaIDs = areas?.areaIDs(for: place.id) ?? []
            return PlaceMetadata(placeKey: place.placeKey,
                descriptions: features.placeDetails.value?.details(for: place.id)?.content?.core,
                coordinate: coordinates[place.id]?.core,
                area: areas?.areas.first { areaIDs.contains($0.id) },
                admission: admission?.categories.first { categories.contains($0.id) }?.core,
                mapCategory: data.features.map.value?.category(for: place.id)?.core)
        }
        let program = try ProgramPreparation.shared.enrich(input: coreProgram,
            days: days.map(\.core), zone: metadata.timeZone.identifier,
            defaultLanguage: metadata.defaultContentLanguage.identifier,
            artistMetadata: artists, placeMetadata: places,
            eventMetadata: [],
            areas: features.areas.value?.areas ?? [])
        data.artists = program.artists
        data.stages = program.places
        data.events = program.events
        data.preparedTags = preparedTags
        data.areas = program.areas
        data.festivalYear = days.first?.date.year ?? Int(metadata.identity.editionID) ?? festivalYear
        return data
    }
}

extension FestivalFeatures {
    func replacingMap(_ map: FeatureAvailability<any FestivalMapProviding>) -> FestivalFeatures {
        FestivalFeatures(
            information: information, artistDetails: artistDetails, placeDetails: placeDetails,
            eventDetails: eventDetails, admission: admission, summaries: summaries,
            groupings: groupings,
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
    func scheduleLabel(calendar: Calendar, locale: Locale = .current) -> String {
        guard let date = date.date(in: calendar) else { return label(calendar: calendar, locale: locale) }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter.string(from: date)
    }

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
