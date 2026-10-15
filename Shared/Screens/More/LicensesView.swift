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
            id: "swiftui-lazypager",
            name: "SwiftUI-LazyPager",
            licenseName: "MIT License",
            copyright: "Copyright (c) 2022 Brian Floersch",
            repositoryURL: URL(string: "https://github.com/gh123man/SwiftUI-LazyPager"),
            note: nil,
            licenseText: mitLicense(
                copyright: "Copyright (c) 2022 Brian Floersch"
            )
        ),
        LicenseEntry(
            id: "youtube-player-kit",
            name: "YouTubePlayerKit",
            licenseName: "MIT License",
            copyright: "Copyright (c) 2025 Sven Tiigi",
            repositoryURL: URL(
                string: "https://github.com/SvenTiigi/YouTubePlayerKit"
            ),
            note: nil,
            licenseText: mitLicense(
                copyright: "Copyright (c) 2025 Sven Tiigi"
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
            id: "patrick-hand",
            name: "Patrick Hand",
            licenseName: "SIL Open Font License 1.1",
            copyright: "Copyright (c) 2010-2012 Patrick Wagesreiter (mail@patrickwagesreiter.at)",
            repositoryURL: URL(
                string: "https://github.com/google/fonts/tree/main/ofl/patrickhand"
            ),
            note: nil,
            licenseText: silOpenFontLicense
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

    private static let silOpenFontLicense = """
    This Font Software is licensed under the SIL Open Font License, Version 1.1.

    SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007

    PREAMBLE
    The goals of the Open Font License (OFL) are to stimulate worldwide
    development of collaborative font projects, to support the font creation
    efforts of academic and linguistic communities, and to provide a free and
    open framework in which fonts may be shared and improved in partnership
    with others.

    The OFL allows the licensed fonts to be used, studied, modified and
    redistributed freely as long as they are not sold by themselves. The
    fonts, including any derivative works, can be bundled, embedded,
    redistributed and/or sold with any software provided that any reserved
    names are not used by derivative works. The fonts and derivatives,
    however, cannot be released under any other type of license. The
    requirement for fonts to remain under this license does not apply
    to any document created using the fonts or their derivatives.

    DEFINITIONS
    "Font Software" refers to the set of files released by the Copyright
    Holder(s) under this license and clearly marked as such. This may
    include source files, build scripts and documentation.

    "Reserved Font Name" refers to any names specified as such after the
    copyright statement(s).

    "Original Version" refers to the collection of Font Software components as
    distributed by the Copyright Holder(s).

    "Modified Version" refers to any derivative made by adding to, deleting,
    or substituting -- in part or in whole -- any of the components of the
    Original Version, by changing formats or by porting the Font Software to a
    new environment.

    "Author" refers to any designer, engineer, programmer, technical
    writer or other person who contributed to the Font Software.

    PERMISSION & CONDITIONS
    Permission is hereby granted, free of charge, to any person obtaining
    a copy of the Font Software, to use, study, copy, merge, embed, modify,
    redistribute, and sell modified and unmodified copies of the Font
    Software, subject to the following conditions:

    1) Neither the Font Software nor any of its individual components,
    in Original or Modified Versions, may be sold by itself.

    2) Original or Modified Versions of the Font Software may be bundled,
    redistributed and/or sold with any software, provided that each copy
    contains the above copyright notice and this license. These can be
    included either as stand-alone text files, human-readable headers or
    in the appropriate machine-readable metadata fields within text or
    binary files as long as those fields can be easily viewed by the user.

    3) No Modified Version of the Font Software may use the Reserved Font
    Name(s) unless explicit written permission is granted by the corresponding
    Copyright Holder. This restriction only applies to the primary font name as
    presented to the users.

    4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
    Software shall not be used to promote, endorse or advertise any
    Modified Version, except to acknowledge the contribution(s) of the
    Copyright Holder(s) and the Author(s) or with their explicit written
    permission.

    5) The Font Software, modified or unmodified, in part or in whole,
    must be distributed entirely under this license, and must not be
    distributed under any other license. The requirement for fonts to
    remain under this license does not apply to any document created
    using the Font Software.

    TERMINATION
    This license becomes null and void if any of the above conditions are
    not met.

    DISCLAIMER
    THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
    OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
    DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
    OTHER DEALINGS IN THE FONT SOFTWARE.
    """
}
