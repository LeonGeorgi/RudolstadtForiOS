//
//  ProgramView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ProgramView: View {
    var body: some View {

        NavigationView {
            List {
                NavigationLink(destination: ArtistListView()) {
                    ProgramItemText(title: "Arists")
                }
                NavigationLink(destination: MarkedArtistListView()) {
                    ProgramItemText(title: "Marked artists")
                }
                NavigationLink(destination: TimeProgramView()) {
                    ProgramItemText(title: "Program by time")
                }
                NavigationLink(destination: StageProgramView()) {
                    ProgramItemText(title: "Program by stage")
                }

                NavigationLink(destination: StageListView()) {
                    ProgramItemText(title: "Stages")
                }

            }.navigationBarTitle("Program")
        }
    }
}

struct ProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}
