package de.leongeorgi.rudolstadt.news

import de.leongeorgi.rudolstadt.discovery.TextFormatting
import de.leongeorgi.rudolstadt.festival.FestivalTime
import kotlinx.datetime.*
import kotlinx.serialization.*
import kotlinx.serialization.json.Json

@Serializable
data class NewsTime(
    val date: String,
    @SerialName("timezone_type") val timezoneType: Int,
    val timezone: String,
) {
    val timestamp
        get() = FestivalTime.apiTime(date, timezone)

    val dateText: String?
        get() = timestamp?.let { local ->
            FestivalTime.local(local, timezone).date.let {
                "${it.day.toString().padStart(2,'0')}.${it.month.number.toString().padStart(2,'0')}.${it.year.toString().padStart(4,'0')}"
            }
        }

    val timeText: String?
        get() = timestamp?.let {
            FestivalTime.local(it, timezone).let {
                "${it.hour.toString().padStart(2,'0')}:${it.minute.toString().padStart(2,'0')}"
            }
        }
}

@Serializable
data class NewsRecord(
    @SerialName("id") val recordID: Long,
    val title: String,
    val language: String,
    val teaser: String,
    val text: String,
    val time: NewsTime,
) {
    fun message() =
        NewsMessage(
            recordID,
            language,
            time.dateText.orEmpty(),
            time.timeText.orEmpty(),
            TextFormatting.decodeCharacterReferences(title),
            TextFormatting.decodeCharacterReferences(teaser),
            TextFormatting.decodeCharacterReferences(text),
        )
}

object NewsWire {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    @Throws(Exception::class)
    fun decode(sourceJSON: String): List<NewsRecord> = json.decodeFromString(sourceJSON)

    @Throws(Exception::class)
    fun decodeMessages(sourceJSON: String): List<NewsMessage> =
        decode(sourceJSON).map { it.message() }

    fun encode(records: List<NewsRecord>): String = json.encodeToString(records)
}

object NewsSnapshots {
    fun fromMessages(
        items: List<NewsMessage>,
        festivalID: String,
        editionID: String,
        source: String?,
        notice: String?,
    ): NewsSnapshot {
        val articles =
            items
                .groupBy { it.newsID }
                .entries
                .sortedByDescending { it.key }
                .map { (id, values) ->
                    val first = values.first()
                    val translations = values.distinctBy { it.languageCode }
                    NewsArticle(
                        id.toString(),
                        translations.associate { it.languageCode to it.shortDescription },
                        translations.associate { it.languageCode to it.longDescription },
                        de.leongeorgi.rudolstadt.festival.ProgramContent(
                            translations.associate { it.languageCode to it.content },
                            true,
                        ),
                        FestivalTime.parse(
                            first.dateAsString + " " + first.timeAsString,
                            "dd.MM.yyyy HH:mm",
                            "Europe/Berlin",
                        ),
                    )
                }
        return NewsSnapshot(festivalID, editionID, articles, 0, source, noticeKey = notice)
    }

    fun messages(snapshot: NewsSnapshot): List<NewsMessage> =
        snapshot.articles.flatMap { article ->
            val id = article.articleID.toLongOrNull() ?: return@flatMap emptyList()
            article.titles.keys.sorted().map { language ->
                val time = article.publishedAt?.let { FestivalTime.local(it, "Europe/Berlin") }
                NewsMessage(
                    id,
                    language,
                    time
                        ?.let {
                            "${it.day.toString().padStart(2,'0')}.${it.month.number.toString().padStart(2,'0')}.${it.year.toString().padStart(4,'0')}"
                        }
                        .orEmpty(),
                    time
                        ?.let {
                            "${it.hour.toString().padStart(2,'0')}:${it.minute.toString().padStart(2,'0')}"
                        }
                        .orEmpty(),
                    de.leongeorgi.rudolstadt.discovery.LocalizedContent.resolve(
                        article.titles,
                        language,
                        null,
                    ),
                    de.leongeorgi.rudolstadt.discovery.LocalizedContent.resolve(
                        article.summaries.orEmpty(),
                        language,
                        null,
                    ),
                    de.leongeorgi.rudolstadt.discovery.LocalizedContent.resolve(
                        article.body.texts,
                        language,
                        null,
                    ),
                )
            }
        }
}

data class NewsDelivery(val items: List<NewsMessage>, val notifications: List<NewsMessage>)
