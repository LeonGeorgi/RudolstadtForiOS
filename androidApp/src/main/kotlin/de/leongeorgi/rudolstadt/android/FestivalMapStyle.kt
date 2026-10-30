package de.leongeorgi.rudolstadt.android

import org.maplibre.android.maps.Style
import org.maplibre.android.style.expressions.Expression.*
import org.maplibre.android.style.layers.*
import org.maplibre.android.style.layers.PropertyFactory.*

/** Festival-plan colours on the existing Positron geometry, fonts and cached resources. */
internal object FestivalMapStyle {
    const val marker = 0xFFA1302E.toInt()
    const val markerForeground = 0xFFFFF9EB.toInt()

    fun apply(style: Style, dark: Boolean) {
        val paper = if (dark) "#27261F" else "#F6F0DE"
        val ink = if (dark) "#EFE2C9" else "#4D463C"
        val roadEdge = if (dark) "#4B4435" else "#CDBB97"
        val minorRoad = if (dark) "#655C49" else "#DED2BD"
        val roadSurface = if (dark) "#86775D" else "#FFF9EB"
        val ochre = if (dark) "#BD9858" else "#DEBA73"
        val water = if (dark) "#355D64" else "#8AB7BE"
        val green = if (dark) "#485133" else "#D1D994"

        style.layers.forEach { layer ->
            when (layer) {
                is BackgroundLayer -> layer.setProperties(backgroundColor(paper))
                is FillLayer ->
                    when (layer.id) {
                        "water" -> layer.setProperties(fillColor(water))
                        "park" -> layer.setProperties(fillColor(green))
                        "landcover_wood" ->
                            layer.setProperties(fillColor(if (dark) "#39432E" else "#DFE3BE"))
                        "landuse_residential" ->
                            layer.setProperties(fillColor(paper), fillOpacity(0f))
                        "building" ->
                            layer.setProperties(
                                fillColor(if (dark) "#494336" else "#E4D8C5"),
                                fillOutlineColor(if (dark) "#635945" else "#CFBFA3"),
                                fillOpacity(
                                    interpolate(
                                        linear(),
                                        zoom(),
                                        stop(13, 0.2f),
                                        stop(16, 0.7f),
                                        stop(18, 1f),
                                    )
                                ),
                            )
                        "road_area_pier",
                        "aeroway-area" -> layer.setProperties(fillColor(roadSurface))
                    }
                is LineLayer ->
                    when {
                        layer.id == "waterway" -> layer.setProperties(lineColor(water))
                        layer.id.startsWith("railway") ->
                            layer.setProperties(
                                lineColor(
                                    if (layer.id.endsWith("dashline")) paper
                                    else if (dark) "#A69C85" else "#736B5C"
                                )
                            )
                        layer.id.startsWith("boundary") ->
                            layer.setProperties(lineColor(if (dark) "#756750" else "#BCA58B"))
                        layer.id == "highway_minor" ->
                            layer.setProperties(
                                lineColor(
                                    interpolate(
                                        linear(),
                                        zoom(),
                                        stop(14, minorRoad),
                                        stop(17, roadSurface),
                                    )
                                ),
                                lineWidth(
                                    interpolate(
                                        exponential(1.3f),
                                        zoom(),
                                        stop(13, 1.6f),
                                        stop(16, 5f),
                                        stop(20, 20f),
                                    )
                                ),
                            )
                        layer.id == "highway_path" ->
                            layer.setProperties(
                                lineColor(if (dark) "#A49C79" else "#BAAE8E"),
                                lineDasharray(arrayOf(2f, 1.5f)),
                                lineWidth(
                                    interpolate(
                                        exponential(1.25f),
                                        zoom(),
                                        stop(13, 0.6f),
                                        stop(16, 1.6f),
                                        stop(20, 5f),
                                    )
                                ),
                                lineOpacity(
                                    interpolate(
                                        linear(),
                                        zoom(),
                                        stop(13, 0.1f),
                                        stop(15, 0.25f),
                                        stop(17, 0.65f),
                                    )
                                ),
                            )
                        layer.id.contains("casing") -> layer.setProperties(lineColor(roadEdge))
                        layer.id == "highway_major_inner" || layer.id == "highway_major_subtle" ->
                            layer.setProperties(
                                lineColor(
                                    match(
                                        get("class"),
                                        literal(roadSurface),
                                        stop("primary", ochre),
                                        stop("trunk", ochre),
                                        stop("secondary", if (dark) "#A58C5C" else "#E7CB91"),
                                    )
                                )
                            )
                        layer.id.contains("motorway") -> layer.setProperties(lineColor(ochre))
                        layer.id.startsWith("road_") || layer.id.startsWith("aeroway") ->
                            layer.setProperties(lineColor(roadSurface))
                    }
                is SymbolLayer -> {
                    if (layer.sourceId != "openmaptiles") return@forEach
                    val river = layer.id.startsWith("water")
                    val town = layer.id.startsWith("label_")
                    val shield = layer.id.contains("shield")
                    layer.setProperties(
                        textColor(
                            if (shield) "#4D463C"
                            else if (river) {
                                if (dark) "#D1E7E5" else "#1E454D"
                            } else if (town) {
                                if (dark) "#D2B997" else "#80685D"
                            } else ink
                        ),
                        textHaloColor(if (shield) "#FFF9EB" else if (river) water else paper),
                        textHaloWidth(if (river) 1f else 1.3f),
                        textHaloBlur(0.3f),
                    )
                }
            }
        }
        val minor = style.getLayerAs<LineLayer>("highway_minor")
        if (minor != null && style.getLayer("festival-minor-casing") == null) {
            val casing =
                LineLayer("festival-minor-casing", minor.sourceId)
                    .withSourceLayer(minor.sourceLayer)
                    .withProperties(
                        lineColor(roadEdge),
                        lineOpacity(interpolate(linear(), zoom(), stop(14, 0f), stop(16, 0.65f))),
                        lineWidth(
                            interpolate(
                                exponential(1.3f),
                                zoom(),
                                stop(13, 2.4f),
                                stop(16, 6.4f),
                                stop(20, 22f),
                            )
                        ),
                        lineCap(Property.LINE_CAP_ROUND),
                        lineJoin(Property.LINE_JOIN_ROUND),
                    )
            minor.filter?.let { casing.setFilter(it) }
            casing.minZoom = 14f
            style.addLayerBelow(casing, minor.id)
        } else
            style.getLayerAs<LineLayer>("festival-minor-casing")?.setProperties(lineColor(roadEdge))
    }
}
