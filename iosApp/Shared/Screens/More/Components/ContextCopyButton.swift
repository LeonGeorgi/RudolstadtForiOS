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
        Button {
            UIPasteboard.general.string = textToCopy
        } label: {
            Label(label, systemImage: "doc.on.doc")
        }
    }
}

struct ContextCopyButton_Previews: PreviewProvider {
    static var previews: some View {
        ContextCopyButton(textToCopy: "test_text", label: "Copy")
    }
}
