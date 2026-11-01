@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import android.text.format.Formatter
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
internal fun OfflineCityMapSheet(onDismiss: () -> Unit) {
    val store = LocalApp.current.model.offlineMaps
    val state by store.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(
            Modifier.fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Icon(Icons.Default.DownloadForOffline, null)
            Text(
                stringResource(R.string.offline_map),
                style = MaterialTheme.typography.headlineSmall,
            )
            Text(stringResource(R.string.offline_map_area))
            Text(
                stringResource(R.string.offline_map_hint),
                style = MaterialTheme.typography.bodySmall,
            )
            Text(
                stringResource(
                    when {
                        state.loading -> R.string.loading
                        state.complete -> R.string.offline_map_ready
                        state.downloading -> R.string.offline_map_downloading
                        state.exists -> R.string.offline_map_paused
                        else -> R.string.offline_map_missing
                    }
                )
            )
            if (state.downloading || state.loading || state.busy) {
                val progress = state.progress
                if (progress != null && state.downloading)
                    LinearProgressIndicator(
                        progress = { progress },
                        modifier = Modifier.fillMaxWidth(),
                    )
                else LinearProgressIndicator(Modifier.fillMaxWidth())
            }
            if (state.bytes > 0)
                Text(
                    stringResource(
                        R.string.offline_map_size,
                        Formatter.formatShortFileSize(context, state.bytes),
                    ),
                    style = MaterialTheme.typography.bodySmall,
                )
            if (state.failed || state.limitReached)
                Text(
                    stringResource(
                        if (state.limitReached) R.string.offline_map_limit
                        else R.string.offline_map_error
                    ),
                    color = MaterialTheme.colorScheme.error,
                )
            if (!state.complete && !state.limitReached) {
                Button(
                    onClick = {
                        if (state.downloading) store.pause()
                        else if (state.failed && !state.exists) store.load() else store.download()
                    },
                    enabled = !state.loading && !state.busy,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        stringResource(
                            when {
                                state.downloading -> R.string.pause
                                state.failed -> R.string.retry
                                state.exists -> R.string.offline_map_resume
                                else -> R.string.offline_map_download
                            }
                        )
                    )
                }
            }
            if (state.exists)
                TextButton(
                    onClick = store::delete,
                    enabled = !state.busy,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(stringResource(R.string.offline_map_delete))
                }
        }
    }
}
