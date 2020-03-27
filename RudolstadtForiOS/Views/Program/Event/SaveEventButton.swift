//
//  SaveEventButton.swift
//  RudolstadtForiOS
//
//  Created by Leon on 27.03.20.
//  Copyright © 2020 Leon Georgi. All rights reserved.
//

import Foundation
import SwiftUI

struct SaveEventButton: View {
    let event: Event
    
    @EnvironmentObject var settings: UserSettings
    
    var body: some View {
        Button(action: {
            if !self.settings.savedEvents.contains(self.event.id) {
                self.settings.savedEvents.append(self.event.id)
            } else {
                self.settings.savedEvents.remove(at: self.settings.savedEvents.firstIndex(of: self.event.id)!)
            }
        }) {
            if self.settings.savedEvents.contains(self.event.id) {
                Text("event.remove")
                //Image(systemName: "bookmark.fill")
            } else {
                Text("event.save")
                //Image(systemName: "bookmark")
            }
        }
    }
}
