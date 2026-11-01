package de.leongeorgi.rudolstadt.news

import de.leongeorgi.rudolstadt.festival.*

data class NewsMessage(
    val newsID: Long,
    val languageCode: String,
    val dateAsString: String,
    val timeAsString: String,
    val shortDescription: String,
    val longDescription: String,
    val content: String,
)

data class NewsArticle(
    val articleID: String,
    val titles: Map<String, String>,
    val summaries: Map<String, String>?,
    val body: ProgramContent,
    val publishedAt: Double?,
    val image: String? = null,
    val updatedTimestamp: Double? = null,
    val sourceURLString: String? = null,
    val articleLinks: List<de.leongeorgi.rudolstadt.festival.ProgramLink> = emptyList(),
    val destinations: List<ContentDestination> = emptyList(),
)

data class NewsSnapshot(
    val festivalID: String,
    val editionID: String,
    val articles: List<NewsArticle>,
    val contextID: Long = 0,
    val snapshotSource: String? = null,
    val dataUpdatedAt: Double? = null,
    val refreshCheckedAt: Double? = null,
    val noticeTexts: Map<String, String>? = null,
    val noticeKey: String? = null,
)
