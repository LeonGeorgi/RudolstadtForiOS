import SwiftUI

struct AboutView: View {

    @EnvironmentObject private var dataStore: DataStore

    let githubUrlString = "https://github.com/LeonGeorgi"

    var githubUrl: URL? {
        URL(string: githubUrlString)
    }

    let email = "rudolstadt@leongeorgi.de"

    var emailUrl: URL? {
        URL(string: "mailto:\(email)?subject=Feedback%20Festival-App")
    }

    var body: some View {
        List {
            Section {
                Text("about.app.content")
                ForEach(dataStore.metadata.officialLinks) { link in
                    Link(link.title.resolved(), destination: link.destination)
                        .contextMenu { ContextCopyButton(textToCopy: link.destination.absoluteString, label: "copy.link.title") }
                }
            }
            Section(header: Text("about.developer.header")) {
                Text("about.developer.content")
                NavigationLink("about.donate.title", value: AppNavigationRoute.donation)
                    .foregroundColor(.accentColor)

                if let githubUrl {
                    Link("about.github.title", destination: githubUrl)
                        .contextMenu {
                            ContextCopyButton(
                                textToCopy: "https://github.com/LeonGeorgi",
                                label: "copy.link.title"
                            )
                        }
                }
                if let emailUrl {
                    Link("email.send.title", destination: emailUrl)
                        .contextMenu {
                            ContextCopyButton(
                                textToCopy: email,
                                label: "copy.email.title"
                            )
                        }
                }
            }
            Section(header: Text("about.licenses.header")) {
                Text("about.licenses.content")

                NavigationLink("about.licenses.title", destination: LicensesView())
            }
        }.listStyle(.insetGrouped)
            .font(.body)
            .navigationTitle("about.title")
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
