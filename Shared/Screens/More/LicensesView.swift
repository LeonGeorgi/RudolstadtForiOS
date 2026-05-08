import SwiftUI

struct LicensesView: View {
    private let entries = LicenseEntry.all

    var body: some View {
        List {
            Section("licenses.library_sources.title") {
                ForEach(entries.filter(\.requiresFullLicenseText)) { entry in
                    NavigationLink(destination: LicenseDetailView(entry: entry)) {
                        LicenseRow(entry: entry)
                    }
                }
            }

            Section("licenses.data_sources.title") {
                ForEach(entries.filter { !$0.requiresFullLicenseText }) { entry in
                    NavigationLink(destination: LicenseDetailView(entry: entry)) {
                        LicenseRow(entry: entry)
                    }
                }
            }
        }
        .navigationTitle("licenses.navigation_title")
        .listStyle(.insetGrouped)
    }
}

private struct LicenseRow: View {
    let entry: LicenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.name)
                .foregroundStyle(.primary)
            Text(entry.licenseName)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct LicenseDetailView: View {
    let entry: LicenseEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.name)
                        .font(.title3.weight(.semibold))

                    Text(entry.licenseName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let copyright = entry.copyright {
                        Text(copyright)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let repositoryURL = entry.repositoryURL {
                    Link(destination: repositoryURL) {
                        Label("licenses.repository.title", systemImage: "link")
                    }
                }

                if let note = entry.note {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.titleKey)
                            .font(.headline)
                        Text(note.body)
                            .font(.body)
                    }
                }

                if let licenseText = entry.licenseText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("licenses.license_text.title")
                            .font(.headline)
                        Text(verbatim: licenseText)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LicenseEntry: Identifiable {
    struct Note {
        let titleKey: LocalizedStringKey
        let body: String
    }

    let id: String
    let name: String
    let licenseName: String
    let copyright: String?
    let repositoryURL: URL?
    let note: Note?
    let licenseText: String?

    var requiresFullLicenseText: Bool {
        licenseText != nil
    }

    static let all: [LicenseEntry] = [
        LicenseEntry(
            id: "nuke",
            name: "Nuke",
            licenseName: "MIT License",
            copyright: "Copyright (c) 2015-2026 Alexander Grebenyuk",
            repositoryURL: URL(string: "https://github.com/kean/Nuke"),
            note: nil,
            licenseText: mitLicense(
                copyright: "Copyright (c) 2015-2026 Alexander Grebenyuk"
            )
        ),
        LicenseEntry(
            id: "okhsl-color-converter",
            name: "OKHSL/OKLab conversion math",
            licenseName: "MIT License",
            copyright: "Copyright (c) 2021 Björn Ottosson",
            repositoryURL: URL(string: "https://bottosson.github.io/posts/colorpicker/"),
            note: Note(
                titleKey: "licenses.notice.title",
                body: "Ported into this app from Björn Ottosson's published OKHSL/OKLab conversion source."
            ),
            licenseText: mitLicense(copyright: "Copyright (c) 2021 Björn Ottosson")
        ),
        LicenseEntry(
            id: "natural-earth",
            name: "Natural Earth Admin 0 Countries",
            licenseName: NSLocalizedString("licenses.public_domain.title", comment: ""),
            copyright: nil,
            repositoryURL: URL(string: "https://www.naturalearthdata.com/"),
            note: Note(
                titleKey: "licenses.notice.title",
                body: "The included country geometry data comes from Natural Earth. Natural Earth states that its raster and vector map data is in the public domain and that attribution is not required."
            ),
            licenseText: nil
        ),
    ]

    private static func mitLicense(copyright: String) -> String {
        """
        MIT License

        \(copyright)

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
        """
    }
}
