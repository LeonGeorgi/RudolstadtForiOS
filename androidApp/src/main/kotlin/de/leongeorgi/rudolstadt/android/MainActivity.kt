package de.leongeorgi.rudolstadt.android

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import de.leongeorgi.rudolstadt.festival.FestivalDefinitions
import de.leongeorgi.rudolstadt.festival.ProgramArtist
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val colors =
                if (isSystemInDarkTheme()) darkColorScheme(primary = Color(0xFFFFB1C2))
                else lightColorScheme(primary = Color(0xFF94354F))
            MaterialTheme(colorScheme = colors) { ArtistListScreen() }
        }
    }
}

private sealed interface ArtistListState {
    data object Loading : ArtistListState

    data object Failed : ArtistListState

    data class Ready(val artists: List<ProgramArtist>) : ArtistListState
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ArtistListScreen() {
    val language = LocalConfiguration.current.locales[0].language
    var attempt by remember { mutableIntStateOf(0) }
    val state by
        produceState<ArtistListState>(ArtistListState.Loading, attempt) {
            value = ArtistListState.Loading
            value =
                try {
                    ArtistListState.Ready(withContext(Dispatchers.IO) { BundledArtists.load() })
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    Log.e("ArtistList", "Could not load bundled artists", failure)
                    ArtistListState.Failed
                }
        }

    Scaffold(topBar = { TopAppBar(title = { Text(stringResource(R.string.artists_title)) }) }) {
        padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            Text(
                stringResource(R.string.program_source, FestivalDefinitions.currentYear),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            when (val current = state) {
                ArtistListState.Loading ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            CircularProgressIndicator()
                            Text(stringResource(R.string.artists_loading))
                        }
                    }
                ArtistListState.Failed ->
                    Box(
                        Modifier.fillMaxSize().padding(24.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            Text(stringResource(R.string.artists_error))
                            Button(onClick = { attempt++ }) { Text(stringResource(R.string.retry)) }
                        }
                    }
                is ArtistListState.Ready -> {
                    val artists = current.artists
                    Text(
                        pluralStringResource(R.plurals.artist_count, artists.size, artists.size),
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                        style = MaterialTheme.typography.labelLarge,
                    )
                    HorizontalDivider()
                    if (artists.isEmpty()) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Text(stringResource(R.string.artists_empty))
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier.fillMaxWidth(),
                            contentPadding = PaddingValues(bottom = 16.dp),
                        ) {
                            items(artists, key = { it.artistID }) { artist ->
                                val country =
                                    artist.content.countryDescription
                                        ?.let {
                                            it[language] ?: it["en"] ?: it["de"]
                                        }
                                        .orEmpty()
                                ListItem(
                                    headlineContent = { Text(artist.name) },
                                    supportingContent =
                                        if (country.isEmpty()) null else ({ Text(country) }),
                                )
                                HorizontalDivider(Modifier.padding(horizontal = 16.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}
