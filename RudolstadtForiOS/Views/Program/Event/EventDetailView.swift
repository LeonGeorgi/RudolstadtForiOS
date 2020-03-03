//
//  EventDetailView.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.02.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: Event
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        List {

            NavigationLink(destination: ArtistDetailView(artist: event.artist)) {
                HStack(spacing: 10) {
                    Text(event.artist.name)
                            .font(.system(size: 22))
                            .fontWeight(.bold)
                    //.lineLimit(2)
                    Spacer()
                    ArtistImageView(artist: event.artist, fullImage: false)
                            .frame(width: 75, height: 75)
                            .cornerRadius(.infinity)
                }
            }

            NavigationLink(destination: StageDetailView(stage: event.stage)) {
                Text(event.stage.germanName)
            }
            if event.tag != nil {
                Text(event.tag!.germanName)
                        .font(.system(size: 15, design: .rounded))
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(.infinity)
                        .lineLimit(1)
            }

            Section(header: Text("MAP")) {
                Button(action: {
                    StageMapView.openInMaps(stage: self.event.stage)
                }) {
                    StageMapView(stage: event.stage)
                            .frame(minHeight: 300)
                }.listRowInsets(EdgeInsets())
            }


            //.overlay(RoundedRectangle(cornerRadius: 4)
            //    .stroke(Color.gray, lineWidth: 1))
        }.listStyle(GroupedListStyle())
                .navigationBarTitle(Text("\(event.weekDay) \(event.timeAsString)"), displayMode: .large)
                .navigationBarItems(trailing: Button(action: {

                }) {
                    Text("Save")
                })
                .listStyle(PlainListStyle())
    }
}


struct EventDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EventDetailView(event: .example)
        }
    }
}
