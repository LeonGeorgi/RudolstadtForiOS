//
//  ProgramView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI

struct ProgramView: View {
    let data: FestivalData

    var body: some View {

        NavigationView {
            List {
                NavigationLink(destination: ArtistListView(data: data)) {
                    Text("Arists")
                }
                NavigationLink(destination: TimeProgramView(data: data)) {
                    Text("Program by time")
                }
                NavigationLink(destination: StageProgramView(data: data)) {
                    Text("Program by stage")
                }

            }.navigationBarTitle("Program")
        }
    }
}

struct ProgramView_Previews: PreviewProvider {
    static var previews: some View {
        ProgramView(data: .example)
    }
}
