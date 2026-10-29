import RudolstadtCore

// Native call-site spelling; the conversion itself is shared with Android.
enum OKHSLColorConverter {
    typealias RGB = SRGBColor
    typealias OKHSL = OKHSLColor
    static func okhslToSRGB(_ value: OKHSL) -> RGB { ColorMath.shared.okhslToSRGB(okhsl: value) }
    static func srgbToOKHSL(_ value: RGB) -> OKHSL { ColorMath.shared.srgbToOKHSL(rgb: value) }
}
