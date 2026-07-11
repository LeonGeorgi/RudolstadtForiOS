import Foundation

private let parserLocales = [
    Locale(identifier: "en_US"),
    Locale(identifier: "de_DE"),
]

private let manualCountryAliases: [String: String] = [
    "antigua": "AG",
    "antigua and barbuda": "AG",
    "bosnia": "BA",
    "bosnia and herzegovina": "BA",
    "britain": "GB",
    "burma": "MM",
    "cape verde": "CV",
    "congo brazzaville": "CG",
    "congo kinshasa": "CD",
    "cote divoire": "CI",
    "cote d ivoire": "CI",
    "cote d'ivoire": "CI",
    "czech republic": "CZ",
    "czechia": "CZ",
    "democratic republic of congo": "CD",
    "democratic republic of the congo": "CD",
    "dr congo": "CD",
    "east timor": "TL",
    "england": "GB",
    "eswatini": "SZ",
    "french guiana": "FR",
    "great britain": "GB",
    "guadeloupe": "FR",
    "holland": "NL",
    "holy see": "VA",
    "iran": "IR",
    "ivory coast": "CI",
    "korea south": "KR",
    "kosovo": "XK",
    "laos": "LA",
    "martinique": "FR",
    "moldova": "MD",
    "myanmar": "MM",
    "netherlands": "NL",
    "north macedonia": "MK",
    "northern ireland": "GB",
    "palestine": "PS",
    "republic of congo": "CG",
    "republic of korea": "KR",
    "republic of moldova": "MD",
    "reunion": "FR",
    "russia": "RU",
    "saint martin": "FR",
    "scotland": "GB",
    "south korea": "KR",
    "state of palestine": "PS",
    "swaziland": "SZ",
    "syria": "SY",
    "tanzania": "TZ",
    "trinidad": "TT",
    "trinidad and tobago": "TT",
    "u k": "GB",
    "u s a": "US",
    "uk": "GB",
    "united kingdom": "GB",
    "united states": "US",
    "united states of america": "US",
    "usa": "US",
    "venezuela": "VE",
    "viet nam": "VN",
    "vatican": "VA",
    "wales": "GB",
]

private let manualCountryDisplayNamesEN: [String: String] = [
    "XKX": "Kosovo"
]

private let manualCountryDisplayNamesDE: [String: String] = [
    "XKX": "Kosovo"
]

private let countryCodeLookup: [String: String] = buildCountryCodeLookup()
private let alpha3CodeAliases: [String: String] = [
    "ENG": "GBR",
    "SCO": "GBR",
    "WAL": "GBR",
    "NIR": "GBR",
    "SUI": "CHE",
    "POR": "PRT",
    "NDL": "NLD",
    "SAF": "ZAF",
    "JAP": "JPN",
    "XKX": "XKX",
]
private let isoA2ToA3: [String: String] = [
    "AF": "AFG",
    "AX": "ALA",
    "AL": "ALB",
    "DZ": "DZA",
    "AS": "ASM",
    "AD": "AND",
    "AO": "AGO",
    "AI": "AIA",
    "AQ": "ATA",
    "AG": "ATG",
    "AR": "ARG",
    "AM": "ARM",
    "AW": "ABW",
    "AU": "AUS",
    "AT": "AUT",
    "AZ": "AZE",
    "BS": "BHS",
    "BH": "BHR",
    "BD": "BGD",
    "BB": "BRB",
    "BY": "BLR",
    "BE": "BEL",
    "BZ": "BLZ",
    "BJ": "BEN",
    "BM": "BMU",
    "BT": "BTN",
    "BO": "BOL",
    "BQ": "BES",
    "BA": "BIH",
    "BW": "BWA",
    "BV": "BVT",
    "BR": "BRA",
    "IO": "IOT",
    "BN": "BRN",
    "BG": "BGR",
    "BF": "BFA",
    "BI": "BDI",
    "CV": "CPV",
    "KH": "KHM",
    "CM": "CMR",
    "CA": "CAN",
    "KY": "CYM",
    "CF": "CAF",
    "TD": "TCD",
    "CL": "CHL",
    "CN": "CHN",
    "CX": "CXR",
    "CC": "CCK",
    "CO": "COL",
    "KM": "COM",
    "CG": "COG",
    "CD": "COD",
    "CK": "COK",
    "CR": "CRI",
    "CI": "CIV",
    "HR": "HRV",
    "CU": "CUB",
    "CW": "CUW",
    "CY": "CYP",
    "CZ": "CZE",
    "DK": "DNK",
    "DJ": "DJI",
    "DM": "DMA",
    "DO": "DOM",
    "EC": "ECU",
    "EG": "EGY",
    "SV": "SLV",
    "GQ": "GNQ",
    "ER": "ERI",
    "EE": "EST",
    "SZ": "SWZ",
    "ET": "ETH",
    "FK": "FLK",
    "FO": "FRO",
    "FJ": "FJI",
    "FI": "FIN",
    "FR": "FRA",
    "GF": "GUF",
    "PF": "PYF",
    "TF": "ATF",
    "GA": "GAB",
    "GM": "GMB",
    "GE": "GEO",
    "DE": "DEU",
    "GH": "GHA",
    "GI": "GIB",
    "GR": "GRC",
    "GL": "GRL",
    "GD": "GRD",
    "GP": "GLP",
    "GU": "GUM",
    "GT": "GTM",
    "GG": "GGY",
    "GN": "GIN",
    "GW": "GNB",
    "GY": "GUY",
    "HT": "HTI",
    "HM": "HMD",
    "VA": "VAT",
    "HN": "HND",
    "HK": "HKG",
    "HU": "HUN",
    "IS": "ISL",
    "IN": "IND",
    "ID": "IDN",
    "IR": "IRN",
    "IQ": "IRQ",
    "IE": "IRL",
    "IM": "IMN",
    "IL": "ISR",
    "IT": "ITA",
    "JM": "JAM",
    "JP": "JPN",
    "JE": "JEY",
    "JO": "JOR",
    "KZ": "KAZ",
    "KE": "KEN",
    "KI": "KIR",
    "KP": "PRK",
    "KR": "KOR",
    "KW": "KWT",
    "KG": "KGZ",
    "LA": "LAO",
    "LV": "LVA",
    "LB": "LBN",
    "LS": "LSO",
    "LR": "LBR",
    "LY": "LBY",
    "LI": "LIE",
    "LT": "LTU",
    "LU": "LUX",
    "MO": "MAC",
    "MG": "MDG",
    "MW": "MWI",
    "MY": "MYS",
    "MV": "MDV",
    "ML": "MLI",
    "MT": "MLT",
    "MH": "MHL",
    "MQ": "MTQ",
    "MR": "MRT",
    "MU": "MUS",
    "YT": "MYT",
    "MX": "MEX",
    "FM": "FSM",
    "MD": "MDA",
    "MC": "MCO",
    "MN": "MNG",
    "ME": "MNE",
    "MS": "MSR",
    "MA": "MAR",
    "MZ": "MOZ",
    "MM": "MMR",
    "NA": "NAM",
    "NR": "NRU",
    "NP": "NPL",
    "NL": "NLD",
    "NC": "NCL",
    "NZ": "NZL",
    "NI": "NIC",
    "NE": "NER",
    "NG": "NGA",
    "NU": "NIU",
    "NF": "NFK",
    "MK": "MKD",
    "MP": "MNP",
    "NO": "NOR",
    "OM": "OMN",
    "PK": "PAK",
    "PW": "PLW",
    "PS": "PSE",
    "PA": "PAN",
    "PG": "PNG",
    "PY": "PRY",
    "PE": "PER",
    "PH": "PHL",
    "PN": "PCN",
    "PL": "POL",
    "PT": "PRT",
    "PR": "PRI",
    "QA": "QAT",
    "RE": "REU",
    "RO": "ROU",
    "RU": "RUS",
    "RW": "RWA",
    "BL": "BLM",
    "SH": "SHN",
    "KN": "KNA",
    "LC": "LCA",
    "MF": "MAF",
    "PM": "SPM",
    "VC": "VCT",
    "WS": "WSM",
    "SM": "SMR",
    "ST": "STP",
    "SA": "SAU",
    "SN": "SEN",
    "RS": "SRB",
    "SC": "SYC",
    "SL": "SLE",
    "SG": "SGP",
    "SX": "SXM",
    "SK": "SVK",
    "SI": "SVN",
    "SB": "SLB",
    "SO": "SOM",
    "ZA": "ZAF",
    "GS": "SGS",
    "SS": "SSD",
    "ES": "ESP",
    "LK": "LKA",
    "SD": "SDN",
    "SR": "SUR",
    "SJ": "SJM",
    "SE": "SWE",
    "CH": "CHE",
    "SY": "SYR",
    "TW": "TWN",
    "TJ": "TJK",
    "TZ": "TZA",
    "TH": "THA",
    "TL": "TLS",
    "TG": "TGO",
    "TK": "TKL",
    "TO": "TON",
    "TT": "TTO",
    "TN": "TUN",
    "TR": "TUR",
    "TM": "TKM",
    "TC": "TCA",
    "TV": "TUV",
    "UG": "UGA",
    "UA": "UKR",
    "AE": "ARE",
    "GB": "GBR",
    "US": "USA",
    "UM": "UMI",
    "UY": "URY",
    "UZ": "UZB",
    "VU": "VUT",
    "VE": "VEN",
    "VN": "VNM",
    "VG": "VGB",
    "VI": "VIR",
    "WF": "WLF",
    "EH": "ESH",
    "YE": "YEM",
    "ZM": "ZMB",
    "ZW": "ZWE",
    "XK": "XKX",
]
private let isoA3ToA2: [String: String] = [
    "AFG": "AF",
    "ALA": "AX",
    "ALB": "AL",
    "DZA": "DZ",
    "ASM": "AS",
    "AND": "AD",
    "AGO": "AO",
    "AIA": "AI",
    "ATA": "AQ",
    "ATG": "AG",
    "ARG": "AR",
    "ARM": "AM",
    "ABW": "AW",
    "AUS": "AU",
    "AUT": "AT",
    "AZE": "AZ",
    "BHS": "BS",
    "BHR": "BH",
    "BGD": "BD",
    "BRB": "BB",
    "BLR": "BY",
    "BEL": "BE",
    "BLZ": "BZ",
    "BEN": "BJ",
    "BMU": "BM",
    "BTN": "BT",
    "BOL": "BO",
    "BES": "BQ",
    "BIH": "BA",
    "BWA": "BW",
    "BVT": "BV",
    "BRA": "BR",
    "IOT": "IO",
    "BRN": "BN",
    "BGR": "BG",
    "BFA": "BF",
    "BDI": "BI",
    "CPV": "CV",
    "KHM": "KH",
    "CMR": "CM",
    "CAN": "CA",
    "CYM": "KY",
    "CAF": "CF",
    "TCD": "TD",
    "CHL": "CL",
    "CHN": "CN",
    "CXR": "CX",
    "CCK": "CC",
    "COL": "CO",
    "COM": "KM",
    "COG": "CG",
    "COD": "CD",
    "COK": "CK",
    "CRI": "CR",
    "CIV": "CI",
    "HRV": "HR",
    "CUB": "CU",
    "CUW": "CW",
    "CYP": "CY",
    "CZE": "CZ",
    "DNK": "DK",
    "DJI": "DJ",
    "DMA": "DM",
    "DOM": "DO",
    "ECU": "EC",
    "EGY": "EG",
    "SLV": "SV",
    "GNQ": "GQ",
    "ERI": "ER",
    "EST": "EE",
    "SWZ": "SZ",
    "ETH": "ET",
    "FLK": "FK",
    "FRO": "FO",
    "FJI": "FJ",
    "FIN": "FI",
    "FRA": "FR",
    "GUF": "GF",
    "PYF": "PF",
    "ATF": "TF",
    "GAB": "GA",
    "GMB": "GM",
    "GEO": "GE",
    "DEU": "DE",
    "GHA": "GH",
    "GIB": "GI",
    "GRC": "GR",
    "GRL": "GL",
    "GRD": "GD",
    "GLP": "GP",
    "GUM": "GU",
    "GTM": "GT",
    "GGY": "GG",
    "GIN": "GN",
    "GNB": "GW",
    "GUY": "GY",
    "HTI": "HT",
    "HMD": "HM",
    "VAT": "VA",
    "HND": "HN",
    "HKG": "HK",
    "HUN": "HU",
    "ISL": "IS",
    "IND": "IN",
    "IDN": "ID",
    "IRN": "IR",
    "IRQ": "IQ",
    "IRL": "IE",
    "IMN": "IM",
    "ISR": "IL",
    "ITA": "IT",
    "JAM": "JM",
    "JPN": "JP",
    "JEY": "JE",
    "JOR": "JO",
    "KAZ": "KZ",
    "KEN": "KE",
    "KIR": "KI",
    "PRK": "KP",
    "KOR": "KR",
    "KWT": "KW",
    "KGZ": "KG",
    "LAO": "LA",
    "LVA": "LV",
    "LBN": "LB",
    "LSO": "LS",
    "LBR": "LR",
    "LBY": "LY",
    "LIE": "LI",
    "LTU": "LT",
    "LUX": "LU",
    "MAC": "MO",
    "MDG": "MG",
    "MWI": "MW",
    "MYS": "MY",
    "MDV": "MV",
    "MLI": "ML",
    "MLT": "MT",
    "MHL": "MH",
    "MTQ": "MQ",
    "MRT": "MR",
    "MUS": "MU",
    "MYT": "YT",
    "MEX": "MX",
    "FSM": "FM",
    "MDA": "MD",
    "MCO": "MC",
    "MNG": "MN",
    "MNE": "ME",
    "MSR": "MS",
    "MAR": "MA",
    "MOZ": "MZ",
    "MMR": "MM",
    "NAM": "NA",
    "NRU": "NR",
    "NPL": "NP",
    "NLD": "NL",
    "NCL": "NC",
    "NZL": "NZ",
    "NIC": "NI",
    "NER": "NE",
    "NGA": "NG",
    "NIU": "NU",
    "NFK": "NF",
    "MKD": "MK",
    "MNP": "MP",
    "NOR": "NO",
    "OMN": "OM",
    "PAK": "PK",
    "PLW": "PW",
    "PSE": "PS",
    "PAN": "PA",
    "PNG": "PG",
    "PRY": "PY",
    "PER": "PE",
    "PHL": "PH",
    "PCN": "PN",
    "POL": "PL",
    "PRT": "PT",
    "PRI": "PR",
    "QAT": "QA",
    "REU": "RE",
    "ROU": "RO",
    "RUS": "RU",
    "RWA": "RW",
    "BLM": "BL",
    "SHN": "SH",
    "KNA": "KN",
    "LCA": "LC",
    "MAF": "MF",
    "SPM": "PM",
    "VCT": "VC",
    "WSM": "WS",
    "SMR": "SM",
    "STP": "ST",
    "SAU": "SA",
    "SEN": "SN",
    "SRB": "RS",
    "SYC": "SC",
    "SLE": "SL",
    "SGP": "SG",
    "SXM": "SX",
    "SVK": "SK",
    "SVN": "SI",
    "SLB": "SB",
    "SOM": "SO",
    "ZAF": "ZA",
    "SGS": "GS",
    "SSD": "SS",
    "ESP": "ES",
    "LKA": "LK",
    "SDN": "SD",
    "SUR": "SR",
    "SJM": "SJ",
    "SWE": "SE",
    "CHE": "CH",
    "SYR": "SY",
    "TWN": "TW",
    "TJK": "TJ",
    "TZA": "TZ",
    "THA": "TH",
    "TLS": "TL",
    "TGO": "TG",
    "TKL": "TK",
    "TON": "TO",
    "TTO": "TT",
    "TUN": "TN",
    "TUR": "TR",
    "TKM": "TM",
    "TCA": "TC",
    "TUV": "TV",
    "UGA": "UG",
    "UKR": "UA",
    "ARE": "AE",
    "GBR": "GB",
    "USA": "US",
    "UMI": "UM",
    "URY": "UY",
    "UZB": "UZ",
    "VUT": "VU",
    "VEN": "VE",
    "VNM": "VN",
    "VGB": "VG",
    "VIR": "VI",
    "WLF": "WF",
    "ESH": "EH",
    "YEM": "YE",
    "ZMB": "ZM",
    "ZWE": "ZW",
    "XKX": "XK",
]

func parseArtistCountryCodes(_ rawValue: String) -> [String] {
    let cleaned = preprocessCountryString(rawValue)
    guard !cleaned.isEmpty else {
        return []
    }

    var seen = Set<String>()
    return parseCountryCodesRecursively(from: cleaned).filter { code in
        if seen.contains(code) {
            return false
        }
        seen.insert(code)
        return true
    }
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

func englishCountryName(forRegionCode code: String) -> String {
    let uppercasedCode = code.uppercased()
    if let alpha2Code = isoA3ToA2[uppercasedCode],
        let localized = Locale(identifier: "en_US").localizedString(
            forRegionCode: alpha2Code
        )
    {
        return localized
    }
    return manualCountryDisplayNamesEN[uppercasedCode] ?? uppercasedCode
}

func alpha2CountryCode(forRegionCode code: String) -> String? {
    let uppercasedCode = code.uppercased()
    if let alpha2Code = isoA3ToA2[uppercasedCode] {
        return alpha2Code
    }
    return isoA2ToA3[uppercasedCode] != nil ? uppercasedCode : nil
}

private func buildCountryCodeLookup() -> [String: String] {
    var lookup: [String: String] = [:]

    func add(_ name: String, code: String) {
        let normalizedName = normalizeCountryToken(name)
        guard !normalizedName.isEmpty else {
            return
        }
        lookup[normalizedName] = code
    }

    for region in Locale.Region.isoRegions {
        let code = region.identifier
        add(code, code: code)
        for locale in parserLocales {
            if let localizedName = locale.localizedString(forRegionCode: code) {
                add(localizedName, code: code)
            }
        }
    }

    for (name, code) in manualCountryAliases {
        add(name, code: code)
    }

    return lookup
}

private func parseCountryCodesRecursively(from rawValue: String) -> [String] {
    let trimmedValue = preprocessCountryString(rawValue)
    guard !trimmedValue.isEmpty else {
        return []
    }

    if let matchedCode = countryCode(for: trimmedValue) {
        return [matchedCode]
    }

    for separator in ["/", ";", "|", "•", "·", "&", "+"] {
        let parts = splitCountryString(trimmedValue, by: separator)
        if parts.count > 1 {
            return parts.flatMap(parseCountryCodesRecursively(from:))
        }
    }

    for separator in [",", " und ", " and ", " et "] {
        let parts = splitCountryString(trimmedValue, by: separator)
        guard parts.count > 1 else {
            continue
        }

        let parsedParts = parts.flatMap(parseCountryCodesRecursively(from:))
        if !parsedParts.isEmpty {
            return parsedParts
        }
    }

    return []
}

private func countryCode(for rawValue: String) -> String? {
    if let code = normalizedCodeToken(from: rawValue) {
        return code
    }

    let normalizedValue = normalizeCountryToken(rawValue)
    if let code = countryCodeLookup[normalizedValue] {
        return isoA2ToA3[code] ?? code
    }

    let strippedValue = stripCountryDecorations(from: rawValue)
    let normalizedStrippedValue = normalizeCountryToken(strippedValue)
    if let code = countryCodeLookup[normalizedStrippedValue] {
        return isoA2ToA3[code] ?? code
    }

    return nil
}

private func normalizedCodeToken(from rawValue: String) -> String? {
    let uppercaseCode = preprocessCountryString(rawValue)
        .uppercased()
        .replacingOccurrences(
            of: #"[^A-Z]"#,
            with: "",
            options: .regularExpression
        )

    guard uppercaseCode.count == 3 else {
        return nil
    }

    if isoA3ToA2[uppercaseCode] != nil {
        return uppercaseCode
    }

    return alpha3CodeAliases[uppercaseCode]
}

private func splitCountryString(_ rawValue: String, by separator: String)
    -> [String]
{
    rawValue.components(separatedBy: separator).map {
        preprocessCountryString($0)
    }.filter { !$0.isEmpty }
}

private func preprocessCountryString(_ rawValue: String) -> String {
    let punctuationNormalized = rawValue
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "–", with: "-")
        .replacingOccurrences(of: "—", with: "-")
        .replacingOccurrences(of: "／", with: "/")
        .replacingOccurrences(of: "＆", with: "&")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    return punctuationNormalized.replacingOccurrences(
        of: #"\s+"#,
        with: " ",
        options: .regularExpression
    )
}

private func stripCountryDecorations(from rawValue: String) -> String {
    let withoutParentheses = rawValue.replacingOccurrences(
        of: #"\(.*?\)|\[.*?\]|\{.*?\}"#,
        with: " ",
        options: .regularExpression
    )
    let withoutPrefixes = withoutParentheses.replacingOccurrences(
        of: #"^(aus|from|originating from)\s+"#,
        with: "",
        options: [.regularExpression, .caseInsensitive]
    )

    return preprocessCountryString(withoutPrefixes)
}

private func normalizeCountryToken(_ rawValue: String) -> String {
    let strippedValue = stripCountryDecorations(from: rawValue)
    let normalized = strippedValue.folding(
        options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
    .lowercased()
    .replacingOccurrences(of: "&", with: " and ")
    .replacingOccurrences(of: #"[.'’]"#, with: "", options: .regularExpression)
    .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    .trimmingCharacters(in: .whitespacesAndNewlines)

    return normalized
}
