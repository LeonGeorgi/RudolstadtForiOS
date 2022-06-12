//
//  ProgramEntry.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 12.06.22.
//

import SwiftUI

struct ProgramEntry: View {
    let iconName: String
    let label: LocalizedStringKey
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .frame(width: 35, alignment: .center)
                .foregroundColor(.accentColor)
            Text(label)
                .lineLimit(1)
        }.font(.system(size: 20))
            .padding(.vertical, 6)
    }
}

struct ProgramEntry_Previews: PreviewProvider {
    static var previews: some View {
        ProgramEntry(iconName: "person.crop.rectangle.stack", label: "artists.title")
    }
}
