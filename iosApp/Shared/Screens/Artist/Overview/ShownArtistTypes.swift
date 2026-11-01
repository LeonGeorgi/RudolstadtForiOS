enum ShownArtistTypes: CaseIterable, Hashable {
    case stage, street, dance, other

    init(artistType: ArtistType) {
        switch artistType {
        case .stage:
            self = .stage
        case .street:
            self = .street
        case .dance:
            self = .dance
        case .other:
            self = .other
        }
    }

    var localizedName: String {
        switch self {
        case .stage:
            return ArtistType.stage.localizedName
        case .street:
            return ArtistType.street.localizedName
        case .dance:
            return ArtistType.dance.localizedName
        case .other:
            return ArtistType.other.localizedName
        }
    }
}
