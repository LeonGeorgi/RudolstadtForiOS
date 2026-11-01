package de.leongeorgi.rudolstadt.android.data

import android.content.Context
import androidx.datastore.core.CorruptionException
import androidx.datastore.core.Serializer
import androidx.datastore.dataStore
import de.leongeorgi.rudolstadt.profile.PersonalProfile
import java.io.InputStream
import java.io.OutputStream
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json

@Serializable
internal data class LocalSettings(
    val edition: String = Edition.current.key,
    val profiles: Map<String, PersonalProfile> = emptyMap(),
    val readNews: Set<Long> = emptySet(),
    val knownNews: Set<Long> = emptySet(),
    val newsBaseline: Boolean = false,
    val theme: String = "system",
    val dynamicColor: Boolean = true,
    val summaries: Boolean = true,
    val flames: Boolean = false,
    val artistLayout: String = "list",
    val artistGridDensity: String = "comfortable",
    val scheduleLayout: String = "list",
    val alwaysShowEventDetails: Boolean = false,
    val scheduleFilters: Map<String, String> = emptyMap(),
    val newsNotifications: Boolean = false,
) {
    fun profile(key: String = edition) = profiles[key] ?: PersonalProfile()

    fun scheduleFilterFor(key: String, planningAvailable: Boolean): String =
        scheduleFilters[key]
            ?.takeIf { it in setOf("all", "interesting", "saved", "optimal") }
            ?.takeUnless { it == "optimal" && !planningAvailable } ?: "all"
}

/** No replacement corruption handler: unreadable personal data must never be silently reset. */
internal object SettingsSerializer : Serializer<LocalSettings> {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }
    override val defaultValue = LocalSettings()

    override suspend fun readFrom(input: InputStream): LocalSettings =
        try {
            json.decodeFromString(input.readBytes().decodeToString())
        } catch (failure: SerializationException) {
            throw CorruptionException("Could not read personal settings", failure)
        }

    override suspend fun writeTo(t: LocalSettings, output: OutputStream) {
        output.write(json.encodeToString(t).encodeToByteArray())
    }
}

internal val Context.localSettings by dataStore("rudolstadt.json", SettingsSerializer)
