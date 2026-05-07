//
//  EmbeddedWebView.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI
import WebKit

struct EmbeddedWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: UIViewRepresentableContext<EmbeddedWebView>) -> WKWebView {
        let webview = WKWebView()

        let request = URLRequest(url: self.url)
        webview.load(request)

        return webview
    }

    func updateUIView(
        _ webview: WKWebView,
        context: UIViewRepresentableContext<EmbeddedWebView>
    ) {
        let request = URLRequest(
            url: self.url,
            cachePolicy: .returnCacheDataElseLoad
        )
        webview.load(request)
    }
}

struct EmbeddedWebView_Previews: PreviewProvider {
    static var previews: some View {
        EmbeddedWebView(url: URL(string: "https://www.google.com/")!)
    }
}
