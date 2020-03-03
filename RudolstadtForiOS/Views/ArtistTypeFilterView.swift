//
// Created by Leon on 03.03.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ArtistTypeFilterView: View {
    @Binding var selectedArtistTypes: Set<ArtistType>

    var body: some View {
        List {
            Section {
                ForEach(ArtistType.allCases) { (artistType: ArtistType) in
                    Button(action: {
                        if self.selectedArtistTypes.contains(artistType) {
                            self.selectedArtistTypes.remove(artistType)
                        } else {
                            self.selectedArtistTypes.insert(artistType)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                if self.selectedArtistTypes.contains(artistType) {
                                    Image(systemName: "checkmark.circle")
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 4)
                                } else {
                                    Image(systemName: "circle")
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 4)
                                }
                            }
                            Text(String(artistType.germanName))
                                    .foregroundColor(.primary)
                        }
                    }
                }
            }
        }.listStyle(GroupedListStyle())
                .navigationBarTitle(Text("Filter artists"), displayMode: .inline)
    }
}
