//
//  AboutView.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var settings: UserSettings

    var body: some View {
        List {
            Section(header: Text("stagenumber.header"), footer: Text("stagenumber.footer")) {
                Picker(selection: settings.stageNumberTypeBinding, label: Text("stagenumber.header")) {
                    ForEach(StageNumberType.allCases, id: \.self) { stageNumberType in
                        Text(LocalizedStringKey(stringLiteral: "stagenumber.\(stageNumberType.rawValue)")).tag(stageNumberType)
                    }
                }
                        .pickerStyle(SegmentedPickerStyle())
            }
        }
                .listStyle(.grouped)
                .navigationTitle("settings.title")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
                .environmentObject(UserSettings())
    }
}
