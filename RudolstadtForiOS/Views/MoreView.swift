//
//  MoreView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 22.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationView {
            Text("more.title")
                .navigationBarTitle("more.title")
        }
    }
}

struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
    }
}
