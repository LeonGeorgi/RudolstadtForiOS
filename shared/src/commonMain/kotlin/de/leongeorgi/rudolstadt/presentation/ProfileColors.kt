package de.leongeorgi.rudolstadt.presentation

import de.leongeorgi.rudolstadt.profile.ProfileReducer
import kotlin.math.PI
import kotlin.math.atan2

/** Profile hues are degrees; saturation and perceptual lightness are rendering policy only. */
object ProfileColors {
    const val saturation = 0.75
    const val lightness = 0.55

    /** Only a touch on the ring can start selecting a color. */
    fun hueAt(x: Double, y: Double, diameter: Double): Double? =
        resolveHue(x, y, diameter, tracking = false)

    /** Once dragging, project the finger onto the ring even beyond its bounds. */
    fun hueForDrag(x: Double, y: Double, diameter: Double): Double? =
        resolveHue(x, y, diameter, tracking = true)

    private fun resolveHue(x: Double, y: Double, diameter: Double, tracking: Boolean): Double? {
        if (!x.isFinite() || !y.isFinite() || !diameter.isFinite() || diameter <= 0.0) return null
        val dx = x / diameter - 0.5
        val dy = y / diameter - 0.5
        val distanceSquared = dx * dx + dy * dy
        // Near the center, tiny movements have unstable angles; keep the last selected hue there.
        if (tracking) {
            if (distanceSquared < 0.0025) return null
        } else if (distanceSquared < 0.09 || distanceSquared > 0.25) return null
        return ProfileReducer.resolvedHue(atan2(dy, dx) * 180.0 / PI + 90.0)
    }

    fun rgb(hue: Double): SRGBColor =
        ColorMath.okhslToSRGB(
                OKHSLColor(ProfileReducer.resolvedHue(hue) / 360.0, saturation, lightness)
            )
            .let {
                SRGBColor(it.r.coerceIn(0.0, 1.0), it.g.coerceIn(0.0, 1.0), it.b.coerceIn(0.0, 1.0))
            }
}
