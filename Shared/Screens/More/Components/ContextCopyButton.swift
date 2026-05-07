//
//  ContextCopyButton.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 12.06.22.
//

import SwiftUI

struct ContextCopyButton: View {
    let textToCopy: String
    let label: LocalizedStringKey

    var body: some View {
        HStack {
            Button(action: {
                UIPasteboard.general.string = textToCopy
            }) {
                Text(label)
                Image(systemName: "doc.on.doc")
            }
        }
    }
}

struct ContextCopyButton_Previews: PreviewProvider {
    static var previews: some View {
        ContextCopyButton(textToCopy: "test_text", label: "Copy")
    }
}
