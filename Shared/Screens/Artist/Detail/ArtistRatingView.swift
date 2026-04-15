import SwiftUI

struct ArtistRatingView: View {
    let artist: Artist
    @EnvironmentObject var settings: UserSettings

    var rating: Int {
        settings.ratings["\(artist.id)"] ?? 0
    }

    var body: some View {
        VStack {
            ZStack {
                HStack(spacing: 0) {
                    ForEach(1...3) { rating in
                        Image(systemName: settings.likeIcon)
                            .font(.system(size: 35))
                            .frame(width: 40, height: 40)
                            .foregroundStyle(
                                self.rating >= rating
                                    ? Color.red
                                    : Color.secondary
                            )
                            .onTapGesture {
                                if self.rating != rating {
                                    settings.setArtistRating(
                                        for: artist,
                                        rating: rating
                                    )
                                } else {
                                    settings.setArtistRating(
                                        for: artist,
                                        rating: 0
                                    )
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Button(action: {
                        settings.setArtistRating(for: artist, rating: 0)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .opacity(rating == 0 ? 0 : 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(rating == 0)
                    .accessibilityHidden(rating == 0)
                    Spacer()
                    ArtistIconPicker(artist: artist)
                }
            }
        }
    }
}

struct ArtistIconPicker: View {

    let artist: Artist
    @EnvironmentObject var settings: UserSettings

    var artistIcon: String? {
        let rating = settings.ratings["\(artist.id)"]
        guard let rating = rating else { return nil }
        if rating < 0 {
            let storedIcon = settings.getArtistIcon(for: artist)
            return storedIcon ?? "hand.thumbsdown.fill"
        }
        return nil
    }

    let icons = [
        "hand.thumbsdown.fill",
        "questionmark.circle.fill",
        "exclamationmark.triangle.fill",
        "clock.arrow.trianglehead.counterclockwise.rotate.90",
        "zzz",
        "moon.zzz.fill",
        //"heart.fill",
        //"star.fill",
        // "pin.fill",
        // "flag.fill",
        //"hand.thumbsup.fill",
        // "quote.bubble.fill",
        //"checkmark.circle.fill",
        // "xmark.circle.fill",
        // "eye.fill",
        //"flame.fill",
        //"bolt.fill",
        // "paintpalette.fill",
        // "party.popper.fill",
        // "sun.max.fill",
        // "moon.stars.fill",
        // "moon.zzz.fill",
        // "face.smiling.inverse",
        // "hare.fill",
        // "tortoise.fill",
        // "figure.and.child.holdinghands",
        // "leaf.fill",
        // "camera.fill",
        // "music.mic",
        // "guitars.fill",
        // "ear.fill",
        // "balloon.2.fill",
        // "hand.raised.fill",
        // "cup.and.heat.waves.fill",
        // "airplane",
        // "opticaldisc.fill",
        // "film.fill",
    ]

    var body: some View {
        Menu {
            ForEach(icons, id: \.self) { icon in
                Button(action: {
                    settings.setArtistIcon(for: artist, icon: icon)
                }) {
                    Label(
                        NSLocalizedString(
                            "artist.icon.\(icon)",
                            comment: "Icon for artist"
                        ),
                        systemImage: icon
                    )
                }
            }
        } label: {
            VStack(alignment: .center) {
                if let artistIcon = artistIcon {
                    Image(systemName: artistIcon)
                        .font(.system(size: 30))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ArtistRatingView(artist: .example)
        .environmentObject(UserSettings())
}
