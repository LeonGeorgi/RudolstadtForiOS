//
//  AboutView.swift
//  RudolstadtForiOS
//
//  Created by Leon Georgi on 11.06.22.
//

import SwiftUI

struct AboutView: View {
    
    var officialAppUrl: URL? {
        URL(string: "itms-apps://apple.com/app/id534902145")
    }
    
    let githubUrlString = "https://github.com/LeonGeorgi"
    
    var githubUrl: URL? {
        URL(string: githubUrlString)
    }
    
    let email = "rudolstadt@leongeorgi.de"
    
    var emailUrl: URL? {
        URL(string: "mailto:\(email)?subject=Feedback%20Festival-App")!
    }
    
    var body: some View {
        List{
            Section {
                Text("about.app.content")
                Button(action: {
                    if let url = officialAppUrl {
                        UIApplication.shared.open(url)
                    }
                    
                }) {
                    Text("about.official_app.title")
                }.disabled(officialAppUrl == nil)
                    .contextMenu {
                        ContextCopyButton(textToCopy: "https://apps.apple.com/de/app/rudolstadt-festival/id534902145", label: "copy.link.title")
                    }
            }
            Section(header: Text("about.developer.header")) {
                Text("about.developer.content")
                Button(action: {
                    if let url = githubUrl {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("about.github.title")
                }.disabled(githubUrl == nil)
                    .contextMenu {
                        ContextCopyButton(textToCopy: "https://github.com/LeonGeorgi", label: "copy.link.title")
                    }
                Button {
                    if let url = emailUrl {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("email.send.title")
                }.disabled(emailUrl == nil)
                    .contextMenu {
                        ContextCopyButton(textToCopy: email, label: "copy.email.title")
                    }
            }
        }.listStyle(GroupedListStyle())
            .navigationTitle("about.title")
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
