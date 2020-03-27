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
                    ProgramItemText(title: "artists.title")
                }
                NavigationLink(destination: SavedArtistListView()) {
                    ProgramItemText(title: "rated_artists.title")
                }
                NavigationLink(destination: TimeProgramView()) {
                    ProgramItemText(title: "program_by_time.title")
                }
                NavigationLink(destination: StageProgramView()) {
                    ProgramItemText(title: "program_by_stage.title")
                }

                NavigationLink(destination: LocationListView()) {
                    ProgramItemText(title: "locations.title")
                }

            }.navigationBarTitle("program.title")
        }
    }
}

struct ProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView()
    }
}
