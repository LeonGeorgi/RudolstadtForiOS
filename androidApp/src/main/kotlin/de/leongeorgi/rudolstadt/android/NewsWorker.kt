package de.leongeorgi.rudolstadt.android

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.*
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.presentation.NewsHistoryViewModel
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.first

internal fun configureNewsNotifications(context: Context, enabled: Boolean) {
    val work = WorkManager.getInstance(context)
    if (!enabled) {
        work.cancelUniqueWork("festival-news")
        return
    }
    work.enqueueUniquePeriodicWork(
        "festival-news",
        ExistingPeriodicWorkPolicy.KEEP,
        PeriodicWorkRequestBuilder<NewsWorker>(15, TimeUnit.MINUTES)
            .setConstraints(
                Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
            )
            .build(),
    )
}

class NewsWorker(context: Context, parameters: WorkerParameters) :
    CoroutineWorker(context, parameters) {
    override suspend fun doWork(): Result {
        val repository = FestivalRepository(applicationContext)
        return try {
            val settings = applicationContext.localSettings.data.first()
            if (!settings.newsNotifications || !Edition.find(settings.edition).live)
                return Result.success()
            val history =
                NewsHistoryViewModel().apply {
                    restore(
                        settings.readNews.toList(),
                        settings.knownNews.toList(),
                        settings.newsBaseline,
                    )
                }
            val snapshot = repository.refreshNews().first
            val items = de.leongeorgi.rudolstadt.news.NewsSnapshots.messages(snapshot)
            val baseline = history.initialize(items)
            val language =
                if (applicationContext.resources.configuration.locales[0].language == "de") "de"
                else "en"
            val process = android.app.ActivityManager.RunningAppProcessInfo()
            android.app.ActivityManager.getMyMemoryState(process)
            val foreground =
                process.importance <=
                    android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
            val eligible =
                if (baseline) emptyList()
                else items.filter { history.notificationEligible(it, language, foreground) }
            val manager = applicationContext.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    "news",
                    applicationContext.getString(R.string.news_title),
                    NotificationManager.IMPORTANCE_DEFAULT,
                )
            )
            val permitted =
                Build.VERSION.SDK_INT < 33 ||
                    applicationContext.checkSelfPermission(
                        Manifest.permission.POST_NOTIFICATIONS
                    ) == PackageManager.PERMISSION_GRANTED
            if (permitted)
                eligible.forEach { item ->
                    val intent =
                        Intent(applicationContext, MainActivity::class.java)
                            .putExtra("newsID", item.newsID)
                            .addFlags(
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            )
                    val pending =
                        PendingIntent.getActivity(
                            applicationContext,
                            item.newsID.hashCode(),
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                        )
                    manager.notify(
                        item.newsID.hashCode(),
                        NotificationCompat.Builder(applicationContext, "news")
                            .setSmallIcon(R.drawable.ic_notification)
                            .setContentTitle(item.shortDescription)
                            .setContentText(item.longDescription)
                            .setStyle(
                                NotificationCompat.BigTextStyle().bigText(item.longDescription)
                            )
                            .setContentIntent(pending)
                            .setAutoCancel(true)
                            .build(),
                    )
                }
            applicationContext.localSettings.updateData { current ->
                current.copy(
                    knownNews = current.knownNews + items.map { it.newsID },
                    newsBaseline = true,
                )
            }
            Result.success()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            android.util.Log.w("FestivalNews", "Background refresh failed", failure)
            Result.retry()
        } finally {
            repository.close()
        }
    }
}
