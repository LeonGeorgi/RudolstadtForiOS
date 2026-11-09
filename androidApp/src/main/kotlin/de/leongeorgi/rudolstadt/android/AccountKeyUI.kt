@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.os.PersistableBundle
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.window.SecureFlagPolicy
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter
import de.leongeorgi.rudolstadt.profile.*

@Composable
internal fun AccountKeyDialog(key: String, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val image =
        remember(key) {
            val matrix = QRCodeWriter().encode(key, BarcodeFormat.QR_CODE, 320, 320)
            Bitmap.createBitmap(320, 320, Bitmap.Config.ARGB_8888)
                .apply {
                    val pixels =
                        IntArray(320 * 320) {
                            if (matrix[it % 320, it / 320]) android.graphics.Color.BLACK
                            else android.graphics.Color.WHITE
                        }
                    setPixels(pixels, 0, 320, 0, 0, 320, 320)
                }
                .asImageBitmap()
        }
    Dialog(
        onDismissRequest = onDismiss,
        properties =
            DialogProperties(
                usePlatformDefaultWidth = false,
                securePolicy = SecureFlagPolicy.SecureOn,
            ),
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(stringResource(R.string.account_key_your_key)) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, stringResource(R.string.back))
                        }
                    },
                )
            }
        ) { padding ->
            Column(
                Modifier.fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(24.dp),
            ) {
                Text(key, fontFamily = FontFamily.Monospace)
                Image(
                    image,
                    contentDescription = stringResource(R.string.account_key_qr_description),
                    modifier = Modifier.size(240.dp).align(Alignment.CenterHorizontally),
                )
                OutlinedButton(
                    onClick = {
                        val clip = ClipData.newPlainText("Account key", key)
                        clip.description.extras =
                            PersistableBundle().apply {
                                putBoolean("android.content.extra.IS_SENSITIVE", true)
                            }
                        (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
                            .setPrimaryClip(clip)
                    },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                ) {
                    Text(stringResource(R.string.account_key_copy))
                }
                Text(
                    stringResource(R.string.account_key_backup_warning),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedButton(
                    onClick = onDismiss,
                    modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                ) {
                    Text(stringResource(R.string.account_key_done))
                }
            }
        }
    }
}

internal val AccountKeyError.androidString: Int
    get() =
        when (this) {
            AccountKeyError.INVALID_KEY -> R.string.account_key_error_invalid
            AccountKeyError.RATE_LIMITED -> R.string.account_key_error_rate
            AccountKeyError.CONFIGURATION -> R.string.account_key_error_configuration
            AccountKeyError.CONFLICT -> R.string.account_key_error_conflict
            AccountKeyError.CONNECTION -> R.string.account_key_error_connection
        }
