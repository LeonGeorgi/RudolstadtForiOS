import Foundation

// ISO data and parsing are shared; native Locale supplies display names and Unicode folding.
private let manualCountryDisplayNamesEN = KotlinCore.bridge.countryTable(name: "manualNamesEN")
private let manualCountryDisplayNamesDE = KotlinCore.bridge.countryTable(name: "manualNamesDE")
private let ukNationDisplayNamesEN = KotlinCore.bridge.countryTable(name: "ukNamesEN")
private let ukNationDisplayNamesDE = KotlinCore.bridge.countryTable(name: "ukNamesDE")
private let alpha3CodeAliases = KotlinCore.bridge.countryTable(name: "alpha3Aliases")
private let isoA3ToA2 = KotlinCore.bridge.countryTable(name: "isoA3ToA2")

func parseArtistCountryCodes(_ rawValue: String) -> [String] {
    var seen = Set<String>()
    return parseCountryCodesRecursively(from: rawValue).filter { seen.insert($0).inserted }
    }

struct LocalizedArtistCountry: Equatable {
    let countryCode: String?
    let name: String
}

func localizedArtistCountries(
    rawValue: String,
    countryCodes: [String],
    locale: Locale = .current
) -> [LocalizedArtistCountry] {
    let displayCodes = parseCountryCodesRecursively(
        from: rawValue,
        preservingUKNations: true
    )
    let codes = displayCodes.isEmpty ? countryCodes : displayCodes
    var seen = Set<String>()
    let countries = codes.compactMap { code -> LocalizedArtistCountry? in
        guard seen.insert(code).inserted else {
            return nil
        }
        let uppercasedCode = code.uppercased()
        return LocalizedArtistCountry(
            countryCode: alpha3CodeAliases[uppercasedCode] ?? uppercasedCode,
            name: localizedArtistCountryName(for: code, locale: locale)
        )
    }

    if !countries.isEmpty {
        return countries
    }

    let fallback = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return fallback.isEmpty
        ? []
        : [LocalizedArtistCountry(countryCode: nil, name: fallback)]
}

func localizedArtistCountryNames(
    rawValue: String,
    countryCodes: [String],
    locale: Locale = .current
) -> [String] {
    localizedArtistCountries(
        rawValue: rawValue,
        countryCodes: countryCodes,
        locale: locale
    )
    .map(\.name)
}

func localizedArtistCountryDescription(
    rawValue: String,
    countryCodes: [String],
    locale: Locale = .current
) -> String? {
    let names = localizedArtistCountryNames(
        rawValue: rawValue,
        countryCodes: countryCodes,
        locale: locale
    )
    guard !names.isEmpty else {
        return nil
    }

    let formatter = ListFormatter()
    formatter.locale = locale
    return formatter.string(from: names)
}

func localizedCountryName(
    forRegionCode code: String,
    locale: Locale = .current
) -> String {
    let uppercasedCode = code.uppercased()
    if let alpha2Code = isoA3ToA2[uppercasedCode],
        let localized = locale.localizedString(
            forRegionCode: alpha2Code
        )
    {
        return localized
    }
    if locale.appLanguageCodeIdentifier == "de" {
        return manualCountryDisplayNamesDE[uppercasedCode]
            ?? manualCountryDisplayNamesEN[uppercasedCode]
            ?? uppercasedCode
    }
    return manualCountryDisplayNamesEN[uppercasedCode] ?? uppercasedCode
}

func alpha2CountryCode(forRegionCode code: String) -> String? {
    KotlinCore.bridge.alpha2CountryCode(value: code)
    }

func emojiFlag(forRegionCode code: String) -> String? {
    KotlinCore.bridge.countryFlag(value: code)
    }

private func parseCountryCodesRecursively(from rawValue: String, preservingUKNations: Bool = false) -> [String] {
    KotlinCore.bridge.countryCodes(value: rawValue, preservingUKNations: preservingUKNations, fold: { value in
        value.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    })
}

private func localizedArtistCountryName(for code: String, locale: Locale) -> String {
    let uppercasedCode = code.uppercased()
    if locale.appLanguageCodeIdentifier == "de" {
        return ukNationDisplayNamesDE[uppercasedCode] ?? localizedCountryName(forRegionCode: uppercasedCode, locale: locale)
    }
    return ukNationDisplayNamesEN[uppercasedCode] ?? localizedCountryName(forRegionCode: uppercasedCode, locale: locale)
}
