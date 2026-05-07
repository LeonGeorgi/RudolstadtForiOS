import Foundation

// Port of Björn Ottosson's OKHSL/OKLab sRGB conversion math.
// Source: https://bottosson.github.io/posts/colorpicker/ (MIT licensed by Björn Ottosson)

enum OKHSLColorConverter {
    struct RGB {
        let r: Double
        let g: Double
        let b: Double
    }

    struct OKHSL {
        let h: Double
        let s: Double
        let l: Double
    }

    private struct Lab {
        let l: Double
        let a: Double
        let b: Double
    }

    private struct LC {
        let l: Double
        let c: Double
    }

    private struct ST {
        let s: Double
        let t: Double
    }

    private struct Cs {
        let c0: Double
        let cMid: Double
        let cMax: Double
    }

    private static let pi = Double.pi

    static func okhslToSRGB(_ okhsl: OKHSL) -> RGB {
        let h = okhsl.h
        let s = okhsl.s
        let l = okhsl.l

        if l == 1.0 {
            return RGB(r: 1.0, g: 1.0, b: 1.0)
        }

        if l == 0.0 {
            return RGB(r: 0.0, g: 0.0, b: 0.0)
        }

        let a_ = cos(2.0 * pi * h)
        let b_ = sin(2.0 * pi * h)
        let lLinear = toeInv(l)

        let cs = getCs(lLinear, a_, b_)

        let mid = 0.8
        let midInv = 1.25

        let c: Double
        if s < mid {
            let t = midInv * s
            let k1 = mid * cs.c0
            let k2 = 1.0 - k1 / cs.cMid
            c = t * k1 / (1.0 - k2 * t)
        } else {
            let t = (s - mid) / (1.0 - mid)
            let k0 = cs.cMid
            let k1 = (1.0 - mid) * cs.cMid * cs.cMid * midInv * midInv / cs.c0
            let k2 = 1.0 - k1 / (cs.cMax - cs.cMid)
            c = k0 + t * k1 / (1.0 - k2 * t)
        }

        let rgbLinear = oklabToLinearSRGB(Lab(l: lLinear, a: c * a_, b: c * b_))

        return RGB(
            r: srgbTransferFunction(rgbLinear.r),
            g: srgbTransferFunction(rgbLinear.g),
            b: srgbTransferFunction(rgbLinear.b)
        )
    }

    static func srgbToOKHSL(_ rgb: RGB) -> OKHSL {
        let lab = linearSRGBToOklab(
            RGB(
                r: srgbTransferFunctionInv(rgb.r),
                g: srgbTransferFunctionInv(rgb.g),
                b: srgbTransferFunctionInv(rgb.b)
            )
        )

        let c = sqrt(lab.a * lab.a + lab.b * lab.b)
        if c <= 0.0 {
            return OKHSL(h: 0.0, s: 0.0, l: toe(lab.l))
        }

        let a_ = lab.a / c
        let b_ = lab.b / c

        let h = 0.5 + 0.5 * atan2(-lab.b, -lab.a) / pi

        let cs = getCs(lab.l, a_, b_)

        let mid = 0.8
        let midInv = 1.25

        let s: Double
        if c < cs.cMid {
            let k1 = mid * cs.c0
            let k2 = 1.0 - k1 / cs.cMid
            let t = c / (k1 + k2 * c)
            s = t * mid
        } else {
            let k0 = cs.cMid
            let k1 = (1.0 - mid) * cs.cMid * cs.cMid * midInv * midInv / cs.c0
            let k2 = 1.0 - k1 / (cs.cMax - cs.cMid)
            let t = (c - k0) / (k1 + k2 * (c - k0))
            s = mid + (1.0 - mid) * t
        }

        let l = toe(lab.l)

        return OKHSL(h: h, s: s, l: l)
    }

    private static func srgbTransferFunction(_ a: Double) -> Double {
        if a <= 0.0031308 {
            return 12.92 * a
        }
        return 1.055 * pow(a, 1.0 / 2.4) - 0.055
    }

    private static func srgbTransferFunctionInv(_ a: Double) -> Double {
        if a > 0.04045 {
            return pow((a + 0.055) / 1.055, 2.4)
        }
        return a / 12.92
    }

    private static func linearSRGBToOklab(_ c: RGB) -> Lab {
        let l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b
        let m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b
        let s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b

        let l_ = cbrt(l)
        let m_ = cbrt(m)
        let s_ = cbrt(s)

        return Lab(
            l: 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            a: 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            b: 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        )
    }

    private static func oklabToLinearSRGB(_ c: Lab) -> RGB {
        let l_ = c.l + 0.3963377774 * c.a + 0.2158037573 * c.b
        let m_ = c.l - 0.1055613458 * c.a - 0.0638541728 * c.b
        let s_ = c.l - 0.0894841775 * c.a - 1.2914855480 * c.b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        return RGB(
            r: +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            g: -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            b: -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    private static func computeMaxSaturation(_ a: Double, _ b: Double) -> Double {
        let k0: Double
        let k1: Double
        let k2: Double
        let k3: Double
        let k4: Double
        let wl: Double
        let wm: Double
        let ws: Double

        if -1.88170328 * a - 0.80936493 * b > 1.0 {
            k0 = +1.19086277
            k1 = +1.76576728
            k2 = +0.59662641
            k3 = +0.75515197
            k4 = +0.56771245
            wl = +4.0767416621
            wm = -3.3077115913
            ws = +0.2309699292
        } else if 1.81444104 * a - 1.19445276 * b > 1.0 {
            k0 = +0.73956515
            k1 = -0.45954404
            k2 = +0.08285427
            k3 = +0.12541070
            k4 = +0.14503204
            wl = -1.2684380046
            wm = +2.6097574011
            ws = -0.3413193965
        } else {
            k0 = +1.35733652
            k1 = -0.00915799
            k2 = -1.15130210
            k3 = -0.50559606
            k4 = +0.00692167
            wl = -0.0041960863
            wm = -0.7034186147
            ws = +1.7076147010
        }

        var saturation = k0 + k1 * a + k2 * b + k3 * a * a + k4 * a * b

        let kL = +0.3963377774 * a + 0.2158037573 * b
        let kM = -0.1055613458 * a - 0.0638541728 * b
        let kS = -0.0894841775 * a - 1.2914855480 * b

        do {
            let l_ = 1.0 + saturation * kL
            let m_ = 1.0 + saturation * kM
            let s_ = 1.0 + saturation * kS

            let l = l_ * l_ * l_
            let m = m_ * m_ * m_
            let s = s_ * s_ * s_

            let lDS = 3.0 * kL * l_ * l_
            let mDS = 3.0 * kM * m_ * m_
            let sDS = 3.0 * kS * s_ * s_

            let lDS2 = 6.0 * kL * kL * l_
            let mDS2 = 6.0 * kM * kM * m_
            let sDS2 = 6.0 * kS * kS * s_

            let f = wl * l + wm * m + ws * s
            let f1 = wl * lDS + wm * mDS + ws * sDS
            let f2 = wl * lDS2 + wm * mDS2 + ws * sDS2

            saturation = saturation - f * f1 / (f1 * f1 - 0.5 * f * f2)
        }

        return saturation
    }

    private static func findCusp(_ a: Double, _ b: Double) -> LC {
        let sCusp = computeMaxSaturation(a, b)
        let rgbAtMax = oklabToLinearSRGB(Lab(l: 1.0, a: sCusp * a, b: sCusp * b))
        let lCusp = cbrt(1.0 / max(max(rgbAtMax.r, rgbAtMax.g), rgbAtMax.b))
        let cCusp = lCusp * sCusp
        return LC(l: lCusp, c: cCusp)
    }

    private static func findGamutIntersection(
        _ a: Double,
        _ b: Double,
        _ l1: Double,
        _ c1: Double,
        _ l0: Double,
        _ cusp: LC
    ) -> Double {
        var t: Double

        if ((l1 - l0) * cusp.c - (cusp.l - l0) * c1) <= 0.0 {
            t = cusp.c * l0 / (c1 * cusp.l + cusp.c * (l0 - l1))
        } else {
            t = cusp.c * (l0 - 1.0) / (c1 * (cusp.l - 1.0) + cusp.c * (l0 - l1))

            let dL = l1 - l0
            let dC = c1

            let kL = +0.3963377774 * a + 0.2158037573 * b
            let kM = -0.1055613458 * a - 0.0638541728 * b
            let kS = -0.0894841775 * a - 1.2914855480 * b

            let lDT = dL + dC * kL
            let mDT = dL + dC * kM
            let sDT = dL + dC * kS

            let l = l0 * (1.0 - t) + t * l1
            let c = t * c1

            let l_ = l + c * kL
            let m_ = l + c * kM
            let s_ = l + c * kS

            let l3 = l_ * l_ * l_
            let m3 = m_ * m_ * m_
            let s3 = s_ * s_ * s_

            let ldt = 3.0 * lDT * l_ * l_
            let mdt = 3.0 * mDT * m_ * m_
            let sdt = 3.0 * sDT * s_ * s_

            let ldt2 = 6.0 * lDT * lDT * l_
            let mdt2 = 6.0 * mDT * mDT * m_
            let sdt2 = 6.0 * sDT * sDT * s_

            let r = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3 - 1.0
            let r1 = +4.0767416621 * ldt - 3.3077115913 * mdt + 0.2309699292 * sdt
            let r2 = +4.0767416621 * ldt2 - 3.3077115913 * mdt2 + 0.2309699292 * sdt2
            let uR = r1 / (r1 * r1 - 0.5 * r * r2)
            var tR = -r * uR

            let g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3 - 1.0
            let g1 = -1.2684380046 * ldt + 2.6097574011 * mdt - 0.3413193965 * sdt
            let g2 = -1.2684380046 * ldt2 + 2.6097574011 * mdt2 - 0.3413193965 * sdt2
            let uG = g1 / (g1 * g1 - 0.5 * g * g2)
            var tG = -g * uG

            let blue = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3 - 1.0
            let blue1 = -0.0041960863 * ldt - 0.7034186147 * mdt + 1.7076147010 * sdt
            let blue2 = -0.0041960863 * ldt2 - 0.7034186147 * mdt2 + 1.7076147010 * sdt2
            let uB = blue1 / (blue1 * blue1 - 0.5 * blue * blue2)
            var tB = -blue * uB

            tR = uR >= 0.0 ? tR : Double.greatestFiniteMagnitude
            tG = uG >= 0.0 ? tG : Double.greatestFiniteMagnitude
            tB = uB >= 0.0 ? tB : Double.greatestFiniteMagnitude

            t += min(tR, min(tG, tB))
        }

        return t
    }

    private static func toe(_ x: Double) -> Double {
        let k1 = 0.206
        let k2 = 0.03
        let k3 = (1.0 + k1) / (1.0 + k2)
        return 0.5 * (k3 * x - k1 + sqrt((k3 * x - k1) * (k3 * x - k1) + 4.0 * k2 * k3 * x))
    }

    private static func toeInv(_ x: Double) -> Double {
        let k1 = 0.206
        let k2 = 0.03
        let k3 = (1.0 + k1) / (1.0 + k2)
        return (x * x + k1 * x) / (k3 * (x + k2))
    }

    private static func toST(_ cusp: LC) -> ST {
        ST(s: cusp.c / cusp.l, t: cusp.c / (1.0 - cusp.l))
    }

    private static func getSTMid(_ a: Double, _ b: Double) -> ST {
        let s = 0.11516993 + 1.0 / (
            +7.44778970 + 4.15901240 * b
            + a * (-2.19557347 + 1.75198401 * b
                + a * (-2.13704948 - 10.02301043 * b
                    + a * (-4.24894561 + 5.38770819 * b + 4.69891013 * a
                    )))
        )

        let t = 0.11239642 + 1.0 / (
            +1.61320320 - 0.68124379 * b
            + a * (+0.40370612 + 0.90148123 * b
                + a * (-0.27087943 + 0.61223990 * b
                    + a * (+0.00299215 - 0.45399568 * b - 0.14661872 * a
                    )))
        )

        return ST(s: s, t: t)
    }

    private static func getCs(_ l: Double, _ a: Double, _ b: Double) -> Cs {
        let cusp = findCusp(a, b)
        let cMax = findGamutIntersection(a, b, l, 1.0, l, cusp)
        let stMax = toST(cusp)

        let k = cMax / min(l * stMax.s, (1.0 - l) * stMax.t)

        let cMid: Double
        do {
            let stMid = getSTMid(a, b)
            let cA = l * stMid.s
            let cB = (1.0 - l) * stMid.t
            cMid = 0.9 * k * sqrt(sqrt(1.0 / (1.0 / pow(cA, 4.0) + 1.0 / pow(cB, 4.0))))
        }

        let c0: Double
        do {
            let cA = l * 0.4
            let cB = (1.0 - l) * 0.8
            c0 = sqrt(1.0 / (1.0 / (cA * cA) + 1.0 / (cB * cB)))
        }

        return Cs(c0: c0, cMid: cMid, cMax: cMax)
    }
}
