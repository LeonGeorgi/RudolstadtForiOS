//
//  MapView.swift
//  RudolstadtForiOS (iOS)
//
//  Created by Leon Georgi on 13.06.22.
//

import SwiftUI
import MapKit

struct ScrollableProgramWrapper: View {
    
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        switch dataStore.data {
        case .loading:
            Text("map.loading")
        case .failure(let reason):
            Text("Failed to load: " + reason.rawValue)
        case .success(let entities):
            ScrollableProgramView(events: entities.events)
        }
    }
}
struct ScrollableProgramWrapper_Previews: PreviewProvider {
    static var previews: some View {
        ScrollableProgramWrapper()
    }
}
