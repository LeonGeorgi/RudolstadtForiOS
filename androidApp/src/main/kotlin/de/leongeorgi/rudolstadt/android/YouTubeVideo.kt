package de.leongeorgi.rudolstadt.android

import android.annotation.SuppressLint
import android.view.View
import android.webkit.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import de.leongeorgi.rudolstadt.discovery.MediaLinks

/** The embedded player is created only after the visitor requests the video. */
@Composable
internal fun YouTubeVideo(videoID: String, destination: String) {
    var loaded by rememberSaveable(videoID) { mutableStateOf(false) }
    val context = LocalContext.current
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (!loaded)
            Box(
                Modifier.fillMaxWidth()
                    .aspectRatio(16f / 9f)
                    .clip(MaterialTheme.shapes.large)
                    .clickable(onClickLabel = stringResource(R.string.load_video)) { loaded = true }
            ) {
                FestivalPhoto(
                    MediaLinks.youtubeThumbnail(videoID),
                    null,
                    Modifier.fillMaxSize(),
                )
                Row(
                    Modifier.align(Alignment.Center)
                        .clip(MaterialTheme.shapes.extraLarge)
                        .background(Color.Black.copy(alpha = .72f))
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(Icons.Default.PlayCircle, null, tint = Color.White)
                    Text(stringResource(R.string.load_video), color = Color.White)
                }
            }
        else EmbeddedYouTubePlayer(videoID)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = { openURL(context, destination) }) {
                Text(stringResource(R.string.open_youtube))
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun EmbeddedYouTubePlayer(videoID: String) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var failed by remember(videoID) { mutableStateOf(false) }
    var fullScreenView by remember { mutableStateOf<View?>(null) }
    var fullScreenCallback by remember { mutableStateOf<WebChromeClient.CustomViewCallback?>(null) }
    fun closeFullScreen() {
        val callback = fullScreenCallback
        fullScreenCallback = null
        fullScreenView = null
        callback?.onCustomViewHidden()
    }
    val view =
        remember(videoID) {
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.mediaPlaybackRequiresUserGesture = true
                settings.allowFileAccess = false
                settings.allowContentAccess = false
                webChromeClient =
                    object : WebChromeClient() {
                        override fun onShowCustomView(view: View, callback: CustomViewCallback) {
                            fullScreenView = view
                            fullScreenCallback = callback
                        }

                        override fun onHideCustomView() = closeFullScreen()
                    }
                webViewClient =
                    object : WebViewClient() {
                        override fun onReceivedError(
                            view: WebView,
                            request: WebResourceRequest,
                            error: WebResourceError,
                        ) {
                            if (request.isForMainFrame) failed = true
                        }

                        override fun shouldOverrideUrlLoading(
                            view: WebView,
                            request: WebResourceRequest,
                        ): Boolean {
                            if (!request.isForMainFrame) return false
                            openURL(context, request.url.toString())
                            return true
                        }
                    }
                // loadDataWithBaseURL supplies the HTTPS origin/referrer required by YouTube
                // embeds.
                val origin = "https://rudolstadt.leongeorgi.de"
                val safeID = videoID.takeIf { it.matches(Regex("[A-Za-z0-9_-]+")) }.orEmpty()
                loadDataWithBaseURL(
                    origin,
                    """
                <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
                <body style="margin:0;background:#000"><div id="player"></div>
                <script src="https://www.youtube.com/iframe_api"></script><script>
                var player;
                function onYouTubeIframeAPIReady() {
                  player = new YT.Player('player', {width:'100%',height:'100%',videoId:'$safeID',
                    playerVars:{origin:'$origin',playsinline:1}, events:{onReady:function(){}}});
                }
                </script><style>html,body,#player{width:100%;height:100%;overflow:hidden}</style></body></html>
            """
                        .trimIndent(),
                    "text/html",
                    "utf-8",
                    null,
                )
            }
        }
    DisposableEffect(view, lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_PAUSE -> {
                    view.evaluateJavascript(
                        "if(window.player && player.pauseVideo) player.pauseVideo();",
                        null,
                    )
                    view.onPause()
                }
                Lifecycle.Event.ON_RESUME -> view.onResume()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            closeFullScreen()
            view.stopLoading()
            view.loadUrl("about:blank")
            view.destroy()
        }
    }
    if (failed) Text(stringResource(R.string.video_error), color = MaterialTheme.colorScheme.error)
    else
        BoxWithConstraints(Modifier.fillMaxWidth().clip(MaterialTheme.shapes.large)) {
            AndroidView(
                factory = { view },
                modifier =
                    Modifier.fillMaxWidth().height((maxWidth * 9 / 16).coerceAtLeast(200.dp)),
            )
        }
    fullScreenView?.let { customView ->
        Dialog(
            onDismissRequest = ::closeFullScreen,
            properties =
                DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
        ) {
            AndroidView(factory = { customView }, modifier = Modifier.fillMaxSize())
        }
    }
}
