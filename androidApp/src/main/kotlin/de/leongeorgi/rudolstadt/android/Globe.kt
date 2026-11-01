package de.leongeorgi.rudolstadt.android

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.opengl.GLES20.*
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import android.opengl.Matrix
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Public
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.*
import androidx.lifecycle.compose.LocalLifecycleOwner
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.maplibre.geojson.*

// A small native OpenGL sphere, using the same offline country geometry as iOS.
// Country picking uses the inverse projection and a separate indexed texture.
internal class GlobeTexture(val image: Bitmap, val index: Bitmap, val countries: List<String>) {
    companion object {
        fun create(
            data: FeatureCollection,
            ocean: Int,
            land: Int,
            selected: Int,
            border: Int,
        ): GlobeTexture {
            val width = 2048
            val height = 1024
            val image = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val index = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(image)
            val picker = Canvas(index)
            canvas.drawColor(ocean)
            picker.drawColor(Color.BLACK)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val pickPaint = Paint()
            val countries = mutableListOf("")
            data.features().orEmpty().forEach { feature ->
                val code = feature.getStringProperty("country").orEmpty()
                val active = feature.getNumberProperty("count")?.toInt()?.let { it > 0 } == true
                val id = countries.size
                countries.add(if (active) code else "")
                val polygons =
                    when (val geometry = feature.geometry()) {
                        is Polygon -> listOf(geometry.coordinates())
                        is MultiPolygon -> geometry.coordinates()
                        else -> emptyList()
                    }
                polygons.forEach { rings ->
                    val path = Path().apply { fillType = Path.FillType.EVEN_ODD }
                    rings.forEach { ring ->
                        var previous = Double.NaN
                        ring.forEachIndexed { n, point ->
                            var x = (point.longitude() + 180) / 360 * width
                            if (!previous.isNaN()) {
                                while (x - previous > width / 2) x -= width
                                while (x - previous < -width / 2) x += width
                            }
                            val y = (90 - point.latitude()) / 180 * height
                            if (n == 0) path.moveTo(x.toFloat(), y.toFloat())
                            else path.lineTo(x.toFloat(), y.toFloat())
                            previous = x
                        }
                        path.close()
                    }
                    for (shift in listOf(-width, 0, width)) {
                        canvas.save()
                        picker.save()
                        canvas.translate(shift.toFloat(), 0f)
                        picker.translate(shift.toFloat(), 0f)
                        paint.style = Paint.Style.FILL
                        paint.color = if (active) selected else land
                        canvas.drawPath(path, paint)
                        pickPaint.color =
                            Color.rgb((id shr 16) and 255, (id shr 8) and 255, id and 255)
                        picker.drawPath(path, pickPaint)
                        paint.style = Paint.Style.STROKE
                        paint.strokeWidth = 1f
                        paint.color = border
                        canvas.drawPath(path, paint)
                        canvas.restore()
                        picker.restore()
                    }
                }
            }
            return GlobeTexture(image, index, countries)
        }
    }
}

@Composable
internal fun CountryGlobe(data: FeatureCollection, modifier: Modifier, select: (String) -> Unit) {
    var yaw by rememberSaveable { mutableFloatStateOf(-10f) }
    var pitch by rememberSaveable { mutableFloatStateOf(25f) }
    var zoom by rememberSaveable { mutableFloatStateOf(1f) }
    val colors = MaterialTheme.colorScheme
    val ocean = colors.surfaceContainerHigh.toArgb()
    val land = colors.outlineVariant.toArgb()
    val selected = colors.primary.toArgb()
    val border = colors.surface.toArgb()
    val texture by
        produceState<GlobeTexture?>(null, data, ocean, land, selected, border) {
            value =
                withContext(Dispatchers.Default) {
                    GlobeTexture.create(data, ocean, land, selected, border)
                }
        }
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val callback by rememberUpdatedState(select)
    val description = stringResource(R.string.globe_description)
    Box(modifier) {
        texture?.let { atlas ->
            key(atlas) {
                val view = remember {
                    GlobeView(
                        context,
                        atlas,
                        yaw,
                        pitch,
                        zoom,
                        { a, b, c ->
                            yaw = a
                            pitch = b
                            zoom = c
                        },
                    ) {
                        callback(it)
                    }
                }
                DisposableEffect(view, lifecycle) {
                    val observer = LifecycleEventObserver { _, event ->
                        when (event) {
                            Lifecycle.Event.ON_RESUME -> view.onResume()
                            Lifecycle.Event.ON_PAUSE -> view.onPause()
                            else -> Unit
                        }
                    }
                    lifecycle.addObserver(observer)
                    onDispose {
                        lifecycle.removeObserver(observer)
                        view.onPause()
                    }
                }
                AndroidView(
                    factory = { view },
                    update = {
                        it.contentDescription = description
                        it.isFocusable = true
                    },
                    modifier =
                        Modifier.fillMaxSize().semantics { contentDescription = description },
                )
                FilledTonalIconButton(
                    onClick = { view.reset() },
                    Modifier.align(Alignment.TopEnd).padding(12.dp),
                ) {
                    Icon(Icons.Default.Public, stringResource(R.string.reset_view))
                }
            }
        } ?: CircularProgressIndicator(Modifier.align(Alignment.Center))
    }
}

@android.annotation.SuppressLint("ViewConstructor")
private class GlobeView(
    context: Context,
    texture: GlobeTexture,
    yaw: Float,
    pitch: Float,
    zoom: Float,
    val savePose: (Float, Float, Float) -> Unit,
    val select: (String) -> Unit,
) : GLSurfaceView(context) {
    private val globe =
        SphereRenderer(texture).also {
            it.yaw = yaw
            it.pitch = pitch
            it.zoom = zoom
        }
    private var x = 0f
    private var y = 0f
    private var travelled = 0f
    private var pinched = false
    private val scale =
        ScaleGestureDetector(
            context,
            object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                override fun onScale(detector: ScaleGestureDetector): Boolean {
                    globe.zoom = (globe.zoom * detector.scaleFactor).coerceIn(.75f, 1.7f)
                    pinched = true
                    requestRender()
                    return true
                }
            },
        )

    init {
        setEGLContextClientVersion(2)
        preserveEGLContextOnPause = true
        setRenderer(globe)
        renderMode = RENDERMODE_WHEN_DIRTY
        isClickable = true
    }

    fun reset() {
        globe.yaw = -10f
        globe.pitch = 25f
        globe.zoom = 1f
        savePose(globe.yaw, globe.pitch, globe.zoom)
        requestRender()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        scale.onTouchEvent(event)
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                x = event.x
                y = event.y
                travelled = 0f
                pinched = false
                parent.requestDisallowInterceptTouchEvent(true)
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.x - x
                val dy = event.y - y
                travelled += abs(dx) + abs(dy)
                if (!scale.isInProgress && event.pointerCount == 1) {
                    globe.yaw += dx / width * 180f
                    globe.pitch = (globe.pitch + dy / height * 180f).coerceIn(-80f, 80f)
                    requestRender()
                }
                x = event.x
                y = event.y
            }
            MotionEvent.ACTION_UP -> {
                savePose(globe.yaw, globe.pitch, globe.zoom)
                parent.requestDisallowInterceptTouchEvent(false)
                if (travelled < 12 * resources.displayMetrics.density && !pinched) {
                    performClick()
                    val tx = event.x
                    val ty = event.y
                    queueEvent { globe.countryAt(tx, ty)?.let { code -> post { select(code) } } }
                }
            }
            MotionEvent.ACTION_CANCEL -> {
                savePose(globe.yaw, globe.pitch, globe.zoom)
                parent.requestDisallowInterceptTouchEvent(false)
            }
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }
}

private class SphereRenderer(private val atlas: GlobeTexture) : GLSurfaceView.Renderer {
    @Volatile var yaw = -10f
    @Volatile var pitch = 25f
    @Volatile var zoom = 1f
    private var width = 1
    private var height = 1
    private var program = 0
    private val mvp = FloatArray(16)
    private val model = FloatArray(16)
    private val projection = FloatArray(16)
    private val view = FloatArray(16)
    private val vertexCount: Int
    private val vertices: java.nio.FloatBuffer
    private val uv: java.nio.FloatBuffer

    init {
        val positions = mutableListOf<Float>()
        val texCoords = mutableListOf<Float>()
        val latSteps = 48
        val lonSteps = 96
        fun vertex(i: Int, j: Int) {
            val latitude = PI / 2 - i.toDouble() / latSteps * PI
            val longitude = j.toDouble() / lonSteps * 2 * PI - PI
            positions.addAll(
                listOf(
                    (cos(latitude) * sin(longitude)).toFloat(),
                    sin(latitude).toFloat(),
                    (cos(latitude) * cos(longitude)).toFloat(),
                )
            )
            texCoords.addAll(listOf(j.toFloat() / lonSteps, i.toFloat() / latSteps))
        }
        for (i in 0 until latSteps) for (j in 0 until lonSteps) {
            vertex(i, j)
            vertex(i + 1, j)
            vertex(i, j + 1)
            vertex(i, j + 1)
            vertex(i + 1, j)
            vertex(i + 1, j + 1)
        }
        vertexCount = positions.size / 3
        fun buffer(values: List<Float>) =
            ByteBuffer.allocateDirect(values.size * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()
                .apply {
                    put(values.toFloatArray())
                    position(0)
                }
        vertices = buffer(positions)
        uv = buffer(texCoords)
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        fun shader(type: Int, source: String) =
            glCreateShader(type).also {
                glShaderSource(it, source)
                glCompileShader(it)
            }
        program =
            glCreateProgram().also {
                glAttachShader(
                    it,
                    shader(
                        GL_VERTEX_SHADER,
                        """
                        uniform mat4 mvp; uniform mat4 model;
                        attribute vec3 position; attribute vec2 texCoord;
                        varying vec2 uv; varying float lighting;
                        void main() { vec3 normal = normalize(mat3(model) * position);
                            lighting = 0.72 + 0.28 * max(dot(normal, normalize(vec3(-0.4, 0.6, 1.0))), 0.0);
                            uv = texCoord; gl_Position = mvp * vec4(position, 1.0); }
                        """
                            .trimIndent(),
                    ),
                )
                glAttachShader(
                    it,
                    shader(
                        GL_FRAGMENT_SHADER,
                        """
                        precision mediump float; uniform sampler2D texture;
                        varying vec2 uv; varying float lighting;
                        void main() { vec4 color = texture2D(texture, uv); gl_FragColor = vec4(color.rgb * lighting, 1.0); }
                        """
                            .trimIndent(),
                    ),
                )
                glLinkProgram(it)
            }
        val textures = IntArray(1)
        glGenTextures(1, textures, 0)
        glBindTexture(GL_TEXTURE_2D, textures[0])
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        GLUtils.texImage2D(GL_TEXTURE_2D, 0, atlas.image, 0)
        val background = atlas.image.getPixel(0, 0)
        glClearColor(
            Color.red(background) / 255f,
            Color.green(background) / 255f,
            Color.blue(background) / 255f,
            1f,
        )
        glEnable(GL_DEPTH_TEST)
    }

    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        width = w
        height = h
        glViewport(0, 0, w, h)
    }

    override fun onDrawFrame(gl: GL10?) {
        glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
        Matrix.setRotateM(model, 0, pitch, 1f, 0f, 0f)
        Matrix.rotateM(model, 0, yaw, 0f, 1f, 0f)
        // Orthographic projection preserves the full globe on both portrait and landscape displays.
        val aspect = width.toFloat() / height
        val extent = 1.15f / zoom
        Matrix.orthoM(
            projection,
            0,
            -extent * max(1f, aspect),
            extent * max(1f, aspect),
            -extent * max(1f, 1 / aspect),
            extent * max(1f, 1 / aspect),
            1f,
            10f,
        )
        Matrix.setLookAtM(view, 0, 0f, 0f, 4f, 0f, 0f, 0f, 0f, 1f, 0f)
        val mv = FloatArray(16)
        Matrix.multiplyMM(mv, 0, view, 0, model, 0)
        Matrix.multiplyMM(mvp, 0, projection, 0, mv, 0)
        glUseProgram(program)
        glUniformMatrix4fv(glGetUniformLocation(program, "mvp"), 1, false, mvp, 0)
        glUniformMatrix4fv(glGetUniformLocation(program, "model"), 1, false, model, 0)
        val position = glGetAttribLocation(program, "position")
        val texCoord = glGetAttribLocation(program, "texCoord")
        glEnableVertexAttribArray(position)
        glVertexAttribPointer(position, 3, GL_FLOAT, false, 0, vertices)
        glEnableVertexAttribArray(texCoord)
        glVertexAttribPointer(texCoord, 2, GL_FLOAT, false, 0, uv)
        glDrawArrays(GL_TRIANGLES, 0, vertexCount)
    }

    fun countryAt(x: Float, y: Float): String? {
        val inverse = FloatArray(16)
        if (!Matrix.invertM(inverse, 0, mvp, 0)) return null
        fun unproject(z: Float): FloatArray {
            val result = FloatArray(4)
            Matrix.multiplyMV(
                result,
                0,
                inverse,
                0,
                floatArrayOf(2 * x / width - 1, 1 - 2 * y / height, z, 1f),
                0,
            )
            return FloatArray(3) { result[it] / result[3] }
        }
        val near = unproject(-1f)
        val far = unproject(1f)
        val direction = FloatArray(3) { far[it] - near[it] }
        val a = direction.sumOf { (it * it).toDouble() }
        val b = 2 * near.indices.sumOf { (near[it] * direction[it]).toDouble() }
        val c = near.sumOf { (it * it).toDouble() } - 1
        val discriminant = b * b - 4 * a * c
        if (discriminant < 0) return null
        val t = (-b - sqrt(discriminant)) / (2 * a)
        val point = DoubleArray(3) { near[it] + t * direction[it] }
        val longitude = atan2(point[0], point[2]) * 180 / PI
        val latitude = asin(point[1].coerceIn(-1.0, 1.0)) * 180 / PI
        val px =
            ((longitude + 180) / 360 * atlas.index.width).toInt().coerceIn(0, atlas.index.width - 1)
        val py =
            ((90 - latitude) / 180 * atlas.index.height).toInt().coerceIn(0, atlas.index.height - 1)
        return atlas.countries.getOrNull(atlas.index.getPixel(px, py) and 0xffffff)?.takeIf {
            it.isNotEmpty()
        }
    }
}
