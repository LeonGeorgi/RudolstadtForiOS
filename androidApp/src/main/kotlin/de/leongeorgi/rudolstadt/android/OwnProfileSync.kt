package de.leongeorgi.rudolstadt.android

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import de.leongeorgi.rudolstadt.profile.*

@Composable
internal fun OwnProfileSyncPanel() {
    val controller = LocalApp.current.model.ownProfile.controller
    val state by controller.state.collectAsStateWithLifecycle()
    if (state.uid == null) return
    Column {
        Text(
            stringResource(R.string.profile_sync_title),
            style = MaterialTheme.typography.titleMedium,
        )
        Text(stringResource(state.phase.androidString))
        Text(
            stringResource(R.string.profile_sync_footer),
            style = MaterialTheme.typography.bodySmall,
        )
        state.problem?.let {
            Text(stringResource(it.androidString), color = MaterialTheme.colorScheme.error)
        }
        if (state.problem != null || state.uid != null)
            TextButton(onClick = controller::retry) {
                Text(stringResource(R.string.profile_sync_retry))
            }
    }
}

internal val OwnProfilePhase.androidString: Int
    get() =
        when (this) {
            OwnProfilePhase.LOADING -> R.string.profile_sync_loading
            OwnProfilePhase.LOCAL -> R.string.profile_sync_local
            OwnProfilePhase.CONNECTING -> R.string.profile_sync_connecting
            OwnProfilePhase.MIGRATING -> R.string.profile_sync_migrating
            OwnProfilePhase.SYNCING -> R.string.profile_sync_syncing
            OwnProfilePhase.READY -> R.string.profile_sync_ready
            OwnProfilePhase.ERROR -> R.string.profile_sync_error
        }
internal val OwnProfileProblem.androidString: Int
    get() =
        when (this) {
            OwnProfileProblem.LOCAL_STORAGE -> R.string.profile_sync_error_local
            OwnProfileProblem.CONNECTION -> R.string.profile_sync_error_connection
        }
