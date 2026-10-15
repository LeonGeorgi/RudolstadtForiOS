import SwiftUI

struct AboutView: View {

    var officialAppUrl: URL? {
        URL(string: "itms-apps://apple.com/app/id534902145")
    }

    let officialWebsiteUrlString = "https://www.rudolstadt-festival.de"

    var officialWebsiteUrl: URL? {
        URL(string: officialWebsiteUrlString)
    }

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
                if let officialWebsiteUrl {
                    Link("about.official_website.title", destination: officialWebsiteUrl)
                        .contextMenu {
                            ContextCopyButton(
                                textToCopy: officialWebsiteUrlString,
                                label: "copy.link.title"
                            )
                        }
                }

                if let officialAppUrl {
                    Link("about.official_app.title", destination: officialAppUrl)
                        .contextMenu {
                            ContextCopyButton(
                                textToCopy:
                                    "https://apps.apple.com/de/app/rudolstadt-festival/id534902145",
                                label: "copy.link.title"
                            )
                        }
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
