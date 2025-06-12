//
//  GeneralView.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct GeneralView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    /*Text("general.headline")
                        .font(.headline)*/
                    Text("general.content")
                        .font(.body)
                }
            }
            /*Section(header: Text("general.opnv.title")) {
                Text("general.opnv.content")
                    .font(.body)
            }*/
            Section(header: Text("general.extra.title")) {
                Text("general.extra.content")
                    .font(.body)
            }
        }.listStyle(GroupedListStyle())
            .navigationTitle("general.title")
    }
}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView()
    }
}
