//
//  NextView.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 12.06.22.
//

import SwiftUI

struct NextView: View {
var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
                .shadow(color: .init(hue: 0, saturation: 0, brightness: 0.8), radius: 10)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Next")
                    .padding(.horizontal, 15)
                    .padding(.top, 10)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                HStack(alignment: .top, spacing: 0) {
                    ArtistImageView(artist: .example, fullImage: true)
                        .cornerRadius(5)
                        .frame(width: 80)
                        .padding(.horizontal, 15)
                    VStack(alignment: .leading) {
                        Text("\(Event.example.shortWeekDay) \(Event.example.timeAsString)")
                            .font(.caption)
                            .textCase(.uppercase)
                            .foregroundColor(.accentColor)
                        Spacer(minLength: 0)
                        Text(Artist.example.name)
                            .font(.body)
                            .fontWeight(.medium)
                        Spacer(minLength: 0)
                        Text(Event.example.stage.localizedName)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                    }
                }.padding(.bottom, 15)

            }
        }.padding(.top, 20)
            .listRowSeparator(.hidden, edges: .all)
    }
}

struct NextView_Previews: PreviewProvider {
    static var previews: some View {
        NextView()
    }
}
