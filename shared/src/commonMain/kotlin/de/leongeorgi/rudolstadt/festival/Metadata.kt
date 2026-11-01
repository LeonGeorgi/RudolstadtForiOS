package de.leongeorgi.rudolstadt.festival

enum class EditionKind {
    REGULAR,
    ARCHIVE,
    EXPERIMENTAL,
}

enum class UserDataAccess {
    UNSUPPORTED,
    READ_ONLY,
    EDITABLE,
}

enum class NoticeSeverity {
    INFORMATION,
    WARNING,
}

data class UserDataPolicy(
    val savedEvents: UserDataAccess,
    val artistRatings: UserDataAccess,
    val artistNotes: UserDataAccess,
)

data class ProgramPresentation(val logo: String?, val accentColorHex: String?)

data class ProgramNotice(
    val noticeID: String,
    val severity: NoticeSeverity,
    val titles: Map<String, String>,
    val messages: Map<String, String>?,
    val noticeLinks: List<ProgramLink>,
)

data class ProgramMetadata(
    val festival: FestivalIdentity,
    val names: Map<String, String>,
    val editionTitles: Map<String, String>,
    val editionKind: EditionKind,
    val rangeStart: Double?,
    val rangeEnd: Double?,
    val timeZoneID: String,
    val defaultLanguage: String,
    val links: List<ProgramLink>,
    val presentation: ProgramPresentation,
    val notices: List<ProgramNotice>,
    val userDataPolicy: UserDataPolicy,
)

data class CalendarDate(val year: Int, val month: Int, val day: Int)

fun FestivalDefinition.programMetadata(): ProgramMetadata {
    val access = if (userAccess == "readOnly") UserDataAccess.READ_ONLY else UserDataAccess.EDITABLE
    return ProgramMetadata(
        identity,
        name,
        mapOf("de" to identity.editionID, "en" to identity.editionID),
        when (editionKind) {
            "archive" -> EditionKind.ARCHIVE
            "experimental" -> EditionKind.EXPERIMENTAL
            else -> EditionKind.REGULAR
        },
        null,
        null,
        timeZoneID,
        defaultLanguage,
        links.map { ProgramLink(it.id, it.title, it.url) },
        ProgramPresentation(null, null),
        if (notice != null && noticeID != null)
            listOf(ProgramNotice(noticeID, NoticeSeverity.WARNING, notice, null, emptyList()))
        else emptyList(),
        UserDataPolicy(access, access, access),
    )
}

/** Content references are independent of native navigation. */
data class ContentDestination(val kind: String, val id: String?)
