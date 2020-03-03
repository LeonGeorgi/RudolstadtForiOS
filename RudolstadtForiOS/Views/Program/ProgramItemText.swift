//
// Created by Leon on 02.03.20.
// Copyright (c) 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ProgramItemText: View {
    let title: String

    var body: some View {
        Text(title)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .padding(.vertical, 4)
    }
}

struct ProgramItemText_Previews: PreviewProvider {
    static var previews: some View {
        ProgramItemText(title: "Example")
    }
}
