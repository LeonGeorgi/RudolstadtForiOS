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
                        Label(
                            "artist.edit-note.button",
                            systemImage: "square.and.pencil"
                        )
                        .labelStyle(.iconOnly)
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
