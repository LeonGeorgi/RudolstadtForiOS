import SDWebImageSwiftUI
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
            WebImage(
                url: selectedImageURL,
                options: [.scaleDownLargeImages, .highPriority],
                context: [.imageThumbnailPixelSize: fullImage ? CGSize(width: 1200, height: 1000) : CGSize(width: 320, height: 280)]
            )
            .placeholder {
                placeholderImage
                    .overlay {
                        ProgressView()
                    }
            }
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipped()
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
