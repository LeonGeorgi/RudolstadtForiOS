import SwiftUI

struct ArtistNoteBlock: View {
    let note: String?
    let onEdit: () -> Void

    var body: some View {
        if let note, !note.isEmpty {
            ArtistDetailContentBlock {
                ArtistDetailSectionHeader("artist.notes.headline")

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(note)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Button(action: onEdit) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}

#if DEBUG
struct ArtistNoteBlock_Previews: PreviewProvider {
    static var previews: some View {
        ArtistNoteBlock(
            note: "Try the early set first, then leave enough time to cross to the next stage.",
            onEdit: {}
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
