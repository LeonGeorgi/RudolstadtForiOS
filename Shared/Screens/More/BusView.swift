//
//  BusView.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct BusView: View {
    var body: some View {
        WebView(
            url: URL(
                string:
                    "https://auskunft.kombus-online.eu/widget/tff/?tpl=165D206D86C"
            )!
        )
        .navigationTitle("bus.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BusView_Previews: PreviewProvider {
    static var previews: some View {
        BusView()
    }
}
