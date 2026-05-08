import Nuke
import NukeUI
import SwiftUI

struct ArtistImageView: View {
    let artist: Artist
    let fullImage: Bool

    private var selectedImageURL: URL? {
        if fullImage, let fullImageUrl = artist.fullImageUrl {
            return fullImageUrl
        }
        return artist.thumbImageUrl
    }

    private var placeholderImage: some View {
        Image(fullImage ? "placeholder" : "placeholder_thumb")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
    }

    var body: some View {
        if let selectedImageURL {
            LazyImage(url: selectedImageURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } else {
                    placeholderImage
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .priority(.high)
            .transaction { transaction in
                transaction.animation = nil
            }
        } else {
            placeholderImage
        }
    }
}

struct ArtistImageView_Previews: PreviewProvider {
    static var previews: some View {
        ArtistImageView(artist: .example, fullImage: false)
    }
}
