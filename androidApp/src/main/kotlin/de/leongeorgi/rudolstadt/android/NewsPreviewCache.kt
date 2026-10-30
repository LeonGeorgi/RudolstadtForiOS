package de.leongeorgi.rudolstadt.android

import android.content.Context
import android.util.AtomicFile
import de.leongeorgi.rudolstadt.discovery.NewsLinkPreview
import de.leongeorgi.rudolstadt.discovery.NewsLinkPreviews
import de.leongeorgi.rudolstadt.loading.RemoteAPI
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

internal class NewsPreviewCache(context: Context) {
    private val directory = File(context.cacheDir, "news-link-previews")
    private val remote = RemoteAPI()

    suspend fun load(url: String): NewsLinkPreview? =
        withContext(Dispatchers.IO) {
            val file = AtomicFile(File(directory, NewsLinkPreviews.cacheKey(url) + ".json"))
            val cached =
                try {
                    NewsLinkPreviews.decode(String(file.readFully(), Charsets.UTF_8))
                } catch (_: java.io.IOException) {
                    null
                }
            val preview = remote.linkPreview(url, cached) ?: return@withContext null
            var stream: java.io.FileOutputStream? = null
            try {
                directory.mkdirs()
                stream = file.startWrite()
                stream.write(NewsLinkPreviews.encode(preview).toByteArray(Charsets.UTF_8))
                file.finishWrite(stream)
            } catch (_: java.io.IOException) {
                file.failWrite(stream)
            }
            preview
        }

    fun close() = remote.close()
}
