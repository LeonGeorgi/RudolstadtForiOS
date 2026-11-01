import Foundation

#if os(iOS) || os(macOS)
struct FestivalEdition: Hashable, Identifiable {
    let identity: FestivalIdentity
    private var suppliedMetadata: FestivalMetadata? = nil
    var id: String { identity.storageKey }
    var legacySelectionID: String { "\(identity.festivalID)-\(identity.editionID)" }
    static var availableEditions: [Self] {
        FestivalRegistry.catalog.festivals.map { Self(identity: $0.identity) }
    }
    var metadata: FestivalMetadata {
        if let suppliedMetadata { return suppliedMetadata }
        guard let adapter = FestivalRegistry.catalog.adapter(for: identity) else {
            preconditionFailure("Unregistered festival selection")
        }
        return adapter.metadata
    }
    var year: Int { Int(identity.editionID) ?? metadata.dateRange.map { metadata.calendar.component(.year, from: $0.start) } ?? 0 }
    var isArchive: Bool { metadata.editionKind == .archive }
    var isExperimental: Bool { metadata.editionKind == .experimental }
    var displayName: String { metadata.name.resolved() + " " + metadata.editionLabel.resolved() }
    init(identity: FestivalIdentity) { self.identity = identity }
    init(metadata: FestivalMetadata) { self.identity = metadata.identity; self.suppliedMetadata = metadata }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    func hash(into hasher: inout Hasher) { hasher.combine(identity) }
    init?(id: String) {
        let matches = Self.availableEditions.filter { $0.id == id || $0.legacySelectionID == id }
        guard matches.count == 1, let value = matches.first else { return nil }
        self = value
    }
    init?(year: Int) {
        // Legacy selection stored only a year; it always referred to Rudolstadt.
        guard let value = Self.availableEditions.first(where: { $0.identity.festivalID == Self.current.identity.festivalID && $0.year == year }) else { return nil }
        self = value
    }
}

#endif

enum FestivalConfiguration {
    static let year = 2026
    static let timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
}
