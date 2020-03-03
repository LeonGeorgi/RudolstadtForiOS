//
// Created by Leon on 03.03.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")

                TextField("Search", text: $text)
                        .foregroundColor(.primary)

                if !text.isEmpty {
                    Button(action: {
                        self.text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                } else {
                    EmptyView()
                }
            }.padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .foregroundColor(.secondary)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10.0)

        }.padding(.horizontal)
    }
}

extension UIApplication {
    func endEditing(_ force: Bool) {
        self.windows.filter {
                    $0.isKeyWindow
                }
                .first?
                .endEditing(force)
    }
}