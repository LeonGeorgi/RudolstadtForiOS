import SwiftUI

extension Color {
    static let rudolstadt = Color("App Color")

    static let stageType1 = Color("Stage Type 1")
    static let stageType2 = Color("Stage Type 2")
    static let stageType3 = Color("Stage Type 3")

    static let areaType1 = Color("Area Type 1")
    static let areaType2 = Color("Area Type 2")
    static let areaType3 = Color("Area Type 3")
    static let areaType4 = Color("Area Type 4")
    static let areaType5 = Color("Area Type 5")
    static let areaType6 = Color("Area Type 6")

    static func okhsl(
        h: Double,
        s: Double,
        l: Double,
        opacity: Double = 1
    ) -> Color {
        let rgb = OKHSLColorConverter.okhslToSRGB(
            .init(h: h, s: s, l: l)
        )

        return Color(
            .sRGB,
            red: clamped(rgb.r),
            green: clamped(rgb.g),
            blue: clamped(rgb.b),
            opacity: opacity
        )
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    init?(festivalProfileHex hex: String) {
        let cleanedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleanedHex.count == 6, let hexValue = Int(cleanedHex, radix: 16) else {
            return nil
        }

        self.init(
            .sRGB,
            red: Double((hexValue >> 16) & 0xFF) / 255,
            green: Double((hexValue >> 8) & 0xFF) / 255,
            blue: Double(hexValue & 0xFF) / 255,
            opacity: 1
        )
    }

    var prefersDarkForeground: Bool {
        #if os(iOS)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return false
        }

        let perceivedBrightness = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return perceivedBrightness > 0.68
        #else
        return false
        #endif
    }
}
