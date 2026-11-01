package de.leongeorgi.rudolstadt

import de.leongeorgi.rudolstadt.presentation.*
import kotlin.math.abs
import kotlin.test.*

class ColorMathTests {
    @Test
    fun preservesTheSwiftColorPalette() {
        // Golden values computed with the original Swift implementation, including gamut edges.
        val samples =
            listOf(
                listOf(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
                listOf(
                    0.0,
                    0.0,
                    1.0,
                    1.0,
                    1.0,
                    1.0,
                    0.2496543419330623,
                    0.5582831888483673,
                    0.9999999923961898,
                ),
                listOf(
                    0.0,
                    0.0,
                    0.5,
                    0.4661807907795908,
                    0.4661807907795907,
                    0.4661807907795907,
                    0.24965433960556277,
                    1.1163344480274734e-07,
                    0.49999999573333476,
                ),
                listOf(
                    0.0,
                    1.0,
                    0.5,
                    0.8419488785811163,
                    -9.413303470040545e-15,
                    0.44493802577470515,
                    1.3530380094106675e-08,
                    1.0000000023577547,
                    0.4999999941542532,
                ),
                listOf(
                    0.17,
                    0.8,
                    0.48,
                    0.6317462696668829,
                    0.3768452265908287,
                    0.11491318411403217,
                    0.17000001666735887,
                    0.800000224718175,
                    0.4799999956557969,
                ),
                listOf(
                    0.33,
                    1.0,
                    0.6,
                    0.5325688804314437,
                    0.6147748012336641,
                    1.2323187480567378e-07,
                    0.32999998696018473,
                    1.0000004126419066,
                    0.5999999957846263,
                ),
                listOf(
                    0.5,
                    0.7,
                    0.48,
                    0.1933316542918162,
                    0.5072754116150926,
                    0.4536557931980936,
                    0.499999958323597,
                    0.6999999089870841,
                    0.479999996419372,
                ),
                listOf(
                    0.67,
                    0.8,
                    0.9,
                    0.7973297997059277,
                    0.9053828850908243,
                    0.9888244082796188,
                    0.6699999398792573,
                    0.7999989554802405,
                    0.8999999931349691,
                ),
                listOf(
                    0.83,
                    1.0,
                    0.2,
                    0.23703353639947844,
                    0.0006879006876817689,
                    0.4449384891093982,
                    0.8300000045716069,
                    0.9999999610090557,
                    0.19999999719901213,
                ),
                listOf(
                    1.0,
                    1.0,
                    0.5,
                    0.8419488785811163,
                    -9.771905506994471e-15,
                    0.44493802577470526,
                    1.3530379983084373e-08,
                    1.0000000023577538,
                    0.4999999941542532,
                ),
            )
        for (v in samples) {
            val rgb = ColorMath.okhslToSRGB(OKHSLColor(v[0], v[1], v[2]))
            assertEquals(v[3], rgb.r, 1e-10)
            assertEquals(v[4], rgb.g, 1e-10)
            assertEquals(v[5], rgb.b, 1e-10)
            val converted = ColorMath.srgbToOKHSL(rgb)
            assertEquals(v[8], converted.l, 1e-10)
            if (v[1] > 0 && v[2] > 0 && v[2] < 1) {
                assertEquals(v[6], converted.h, 1e-7)
                assertEquals(v[7], converted.s, 1e-6)
            }
        }
    }

    @Test
    fun rgbConversionRetainsPrimaryColors() {
        for (rgb in
            listOf(SRGBColor(1.0, 0.0, 0.0), SRGBColor(0.0, 1.0, 0.0), SRGBColor(0.0, 0.0, 1.0))) {
            val result = ColorMath.okhslToSRGB(ColorMath.srgbToOKHSL(rgb))
            assertTrue(abs(result.r - rgb.r) < 1e-5)
            assertTrue(abs(result.g - rgb.g) < 1e-5)
            assertTrue(abs(result.b - rgb.b) < 1e-5)
        }
    }
}
