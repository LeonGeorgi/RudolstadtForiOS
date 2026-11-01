package de.leongeorgi.rudolstadt.presentation

import kotlin.math.*

// Port of Björn Ottosson's OKHSLColor/OKLab sRGB conversion math.
// Source: https://bottosson.github.io/posts/colorpicker/ (MIT licensed by Björn Ottosson)

data class SRGBColor(val r: Double, val g: Double, val b: Double)

data class OKHSLColor(val h: Double, val s: Double, val l: Double)

object ColorMath {

    private data class Lab(val l: Double, val a: Double, val b: Double)

    private data class LC(val l: Double, val c: Double)

    private data class ST(val s: Double, val t: Double)

    private data class Cs(val c0: Double, val cMid: Double, val cMax: Double)

    private val pi = PI

    fun okhslToSRGB(okhsl: OKHSLColor): SRGBColor {
        val h = okhsl.h
        val s = okhsl.s
        val l = okhsl.l

        if (l == 1.0) {
            return SRGBColor(r = 1.0, g = 1.0, b = 1.0)
        }

        if (l == 0.0) {
            return SRGBColor(r = 0.0, g = 0.0, b = 0.0)
        }

        val a_ = cos(2.0 * pi * h)
        val b_ = sin(2.0 * pi * h)
        val lLinear = toeInv(l)

        val cs = getCs(lLinear, a_, b_)

        val mid = 0.8
        val midInv = 1.25

        val c: Double
        if (s < mid) {
            val t = midInv * s
            val k1 = mid * cs.c0
            val k2 = 1.0 - k1 / cs.cMid
            c = t * k1 / (1.0 - k2 * t)
        } else {
            val t = (s - mid) / (1.0 - mid)
            val k0 = cs.cMid
            val k1 = (1.0 - mid) * cs.cMid * cs.cMid * midInv * midInv / cs.c0
            val k2 = 1.0 - k1 / (cs.cMax - cs.cMid)
            c = k0 + t * k1 / (1.0 - k2 * t)
        }

        val rgbLinear = oklabToLinearSRGB(Lab(l = lLinear, a = c * a_, b = c * b_))

        return SRGBColor(
            r = srgbTransferFunction(rgbLinear.r),
            g = srgbTransferFunction(rgbLinear.g),
            b = srgbTransferFunction(rgbLinear.b),
        )
    }

    fun srgbToOKHSL(rgb: SRGBColor): OKHSLColor {
        val lab =
            linearSRGBToOklab(
                SRGBColor(
                    r = srgbTransferFunctionInv(rgb.r),
                    g = srgbTransferFunctionInv(rgb.g),
                    b = srgbTransferFunctionInv(rgb.b),
                )
            )

        val c = sqrt(lab.a * lab.a + lab.b * lab.b)
        if (c <= 0.0) {
            return OKHSLColor(h = 0.0, s = 0.0, l = toe(lab.l))
        }

        val a_ = lab.a / c
        val b_ = lab.b / c

        val h = 0.5 + 0.5 * atan2(-lab.b, -lab.a) / pi

        val cs = getCs(lab.l, a_, b_)

        val mid = 0.8
        val midInv = 1.25

        val s: Double
        if (c < cs.cMid) {
            val k1 = mid * cs.c0
            val k2 = 1.0 - k1 / cs.cMid
            val t = c / (k1 + k2 * c)
            s = t * mid
        } else {
            val k0 = cs.cMid
            val k1 = (1.0 - mid) * cs.cMid * cs.cMid * midInv * midInv / cs.c0
            val k2 = 1.0 - k1 / (cs.cMax - cs.cMid)
            val t = (c - k0) / (k1 + k2 * (c - k0))
            s = mid + (1.0 - mid) * t
        }

        val l = toe(lab.l)

        return OKHSLColor(h = h, s = s, l = l)
    }

    private fun srgbTransferFunction(a: Double): Double {
        if (a <= 0.0031308) {
            return 12.92 * a
        }
        return 1.055 * a.pow(1.0 / 2.4) - 0.055
    }

    private fun srgbTransferFunctionInv(a: Double): Double {
        if (a > 0.04045) {
            return ((a + 0.055) / 1.055).pow(2.4)
        }
        return a / 12.92
    }

    private fun linearSRGBToOklab(c: SRGBColor): Lab {
        val l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b
        val m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b
        val s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b

        val l_ = cbrt(l)
        val m_ = cbrt(m)
        val s_ = cbrt(s)

        return Lab(
            l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
        )
    }

    private fun oklabToLinearSRGB(c: Lab): SRGBColor {
        val l_ = c.l + 0.3963377774 * c.a + 0.2158037573 * c.b
        val m_ = c.l - 0.1055613458 * c.a - 0.0638541728 * c.b
        val s_ = c.l - 0.0894841775 * c.a - 1.2914855480 * c.b

        val l = l_ * l_ * l_
        val m = m_ * m_ * m_
        val s = s_ * s_ * s_

        return SRGBColor(
            r = +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s,
        )
    }

    private fun computeMaxSaturation(a: Double, b: Double): Double {
        val k0: Double
        val k1: Double
        val k2: Double
        val k3: Double
        val k4: Double
        val wl: Double
        val wm: Double
        val ws: Double

        if (-1.88170328 * a - 0.80936493 * b > 1.0) {
            k0 = +1.19086277
            k1 = +1.76576728
            k2 = +0.59662641
            k3 = +0.75515197
            k4 = +0.56771245
            wl = +4.0767416621
            wm = -3.3077115913
            ws = +0.2309699292
        } else if (1.81444104 * a - 1.19445276 * b > 1.0) {
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

        val kL = +0.3963377774 * a + 0.2158037573 * b
        val kM = -0.1055613458 * a - 0.0638541728 * b
        val kS = -0.0894841775 * a - 1.2914855480 * b

        run {
            val l_ = 1.0 + saturation * kL
            val m_ = 1.0 + saturation * kM
            val s_ = 1.0 + saturation * kS

            val l = l_ * l_ * l_
            val m = m_ * m_ * m_
            val s = s_ * s_ * s_

            val lDS = 3.0 * kL * l_ * l_
            val mDS = 3.0 * kM * m_ * m_
            val sDS = 3.0 * kS * s_ * s_

            val lDS2 = 6.0 * kL * kL * l_
            val mDS2 = 6.0 * kM * kM * m_
            val sDS2 = 6.0 * kS * kS * s_

            val f = wl * l + wm * m + ws * s
            val f1 = wl * lDS + wm * mDS + ws * sDS
            val f2 = wl * lDS2 + wm * mDS2 + ws * sDS2

            saturation = saturation - f * f1 / (f1 * f1 - 0.5 * f * f2)
        }

        return saturation
    }

    private fun findCusp(a: Double, b: Double): LC {
        val sCusp = computeMaxSaturation(a, b)
        val rgbAtMax = oklabToLinearSRGB(Lab(l = 1.0, a = sCusp * a, b = sCusp * b))
        val lCusp = cbrt(1.0 / max(max(rgbAtMax.r, rgbAtMax.g), rgbAtMax.b))
        val cCusp = lCusp * sCusp
        return LC(l = lCusp, c = cCusp)
    }

    private fun findGamutIntersection(
        a: Double,
        b: Double,
        l1: Double,
        c1: Double,
        l0: Double,
        cusp: LC,
    ): Double {
        var t: Double

        if (((l1 - l0) * cusp.c - (cusp.l - l0) * c1) <= 0.0) {
            t = cusp.c * l0 / (c1 * cusp.l + cusp.c * (l0 - l1))
        } else {
            t = cusp.c * (l0 - 1.0) / (c1 * (cusp.l - 1.0) + cusp.c * (l0 - l1))

            val dL = l1 - l0
            val dC = c1

            val kL = +0.3963377774 * a + 0.2158037573 * b
            val kM = -0.1055613458 * a - 0.0638541728 * b
            val kS = -0.0894841775 * a - 1.2914855480 * b

            val lDT = dL + dC * kL
            val mDT = dL + dC * kM
            val sDT = dL + dC * kS

            val l = l0 * (1.0 - t) + t * l1
            val c = t * c1

            val l_ = l + c * kL
            val m_ = l + c * kM
            val s_ = l + c * kS

            val l3 = l_ * l_ * l_
            val m3 = m_ * m_ * m_
            val s3 = s_ * s_ * s_

            val ldt = 3.0 * lDT * l_ * l_
            val mdt = 3.0 * mDT * m_ * m_
            val sdt = 3.0 * sDT * s_ * s_

            val ldt2 = 6.0 * lDT * lDT * l_
            val mdt2 = 6.0 * mDT * mDT * m_
            val sdt2 = 6.0 * sDT * sDT * s_

            val r = +4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3 - 1.0
            val r1 = +4.0767416621 * ldt - 3.3077115913 * mdt + 0.2309699292 * sdt
            val r2 = +4.0767416621 * ldt2 - 3.3077115913 * mdt2 + 0.2309699292 * sdt2
            val uR = r1 / (r1 * r1 - 0.5 * r * r2)
            var tR = -r * uR

            val g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3 - 1.0
            val g1 = -1.2684380046 * ldt + 2.6097574011 * mdt - 0.3413193965 * sdt
            val g2 = -1.2684380046 * ldt2 + 2.6097574011 * mdt2 - 0.3413193965 * sdt2
            val uG = g1 / (g1 * g1 - 0.5 * g * g2)
            var tG = -g * uG

            val blue = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3 - 1.0
            val blue1 = -0.0041960863 * ldt - 0.7034186147 * mdt + 1.7076147010 * sdt
            val blue2 = -0.0041960863 * ldt2 - 0.7034186147 * mdt2 + 1.7076147010 * sdt2
            val uB = blue1 / (blue1 * blue1 - 0.5 * blue * blue2)
            var tB = -blue * uB

            tR = if (uR >= 0.0) tR else Double.MAX_VALUE
            tG = if (uG >= 0.0) tG else Double.MAX_VALUE
            tB = if (uB >= 0.0) tB else Double.MAX_VALUE

            t += min(tR, min(tG, tB))
        }

        return t
    }

    private fun toe(x: Double): Double {
        val k1 = 0.206
        val k2 = 0.03
        val k3 = (1.0 + k1) / (1.0 + k2)
        return 0.5 * (k3 * x - k1 + sqrt((k3 * x - k1) * (k3 * x - k1) + 4.0 * k2 * k3 * x))
    }

    private fun toeInv(x: Double): Double {
        val k1 = 0.206
        val k2 = 0.03
        val k3 = (1.0 + k1) / (1.0 + k2)
        return (x * x + k1 * x) / (k3 * (x + k2))
    }

    private fun toST(cusp: LC): ST {
        return ST(s = cusp.c / cusp.l, t = cusp.c / (1.0 - cusp.l))
    }

    private fun getSTMid(a: Double, b: Double): ST {
        val s =
            0.11516993 +
                1.0 /
                    (+7.44778970 +
                        4.15901240 * b +
                        a *
                            (-2.19557347 +
                                1.75198401 * b +
                                a *
                                    (-2.13704948 - 10.02301043 * b +
                                        a * (-4.24894561 + 5.38770819 * b + 4.69891013 * a))))

        val t =
            0.11239642 +
                1.0 /
                    (+1.61320320 - 0.68124379 * b +
                        a *
                            (+0.40370612 +
                                0.90148123 * b +
                                a *
                                    (-0.27087943 +
                                        0.61223990 * b +
                                        a * (+0.00299215 - 0.45399568 * b - 0.14661872 * a))))

        return ST(s = s, t = t)
    }

    private fun getCs(l: Double, a: Double, b: Double): Cs {
        val cusp = findCusp(a, b)
        val cMax = findGamutIntersection(a, b, l, 1.0, l, cusp)
        val stMax = toST(cusp)

        val k = cMax / min(l * stMax.s, (1.0 - l) * stMax.t)

        var cMid = 0.0
        run {
            val stMid = getSTMid(a, b)
            val cA = l * stMid.s
            val cB = (1.0 - l) * stMid.t
            cMid = 0.9 * k * sqrt(sqrt(1.0 / (1.0 / cA.pow(4.0) + 1.0 / cB.pow(4.0))))
        }

        var c0 = 0.0
        run {
            val cA = l * 0.4
            val cB = (1.0 - l) * 0.8
            c0 = sqrt(1.0 / (1.0 / (cA * cA) + 1.0 / (cB * cB)))
        }

        return Cs(c0 = c0, cMid = cMid, cMax = cMax)
    }
}
