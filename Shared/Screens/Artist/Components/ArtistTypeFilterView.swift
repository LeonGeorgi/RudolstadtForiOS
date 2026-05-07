import SwiftUI

struct ArtistTypeFilterView: View {
    @Binding var selectedArtistTypes: Set<ArtistType>

    var body: some View {
        List {
            Section {
                ForEach(ArtistType.allCases) { (artistType: ArtistType) in
                    Button(action: {
                        if selectedArtistTypes.contains(artistType) {
                            self.selectedArtistTypes.remove(artistType)
                        } else {
                            self.selectedArtistTypes.insert(artistType)
                        }
                    }) {
                        HStack {
                            Text(String(artistType.localizedName))
                                .foregroundColor(.primary)
                            Spacer()
                            VStack(alignment: .leading) {
                                if selectedArtistTypes.contains(artistType) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle(Text("filter.artists.title"), displayMode: .inline)
    }
}
