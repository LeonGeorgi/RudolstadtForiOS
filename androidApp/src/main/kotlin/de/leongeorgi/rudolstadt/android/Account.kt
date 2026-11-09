@file:OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)

package de.leongeorgi.rudolstadt.android

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import de.leongeorgi.rudolstadt.presentation.ProfileColors
import de.leongeorgi.rudolstadt.profile.*
import kotlin.math.cos
import kotlin.math.sin

@Composable
internal fun AccountRequired(content: @Composable () -> Unit) {
    val app = LocalApp.current
    val state by app.model.friends.controller.state.collectAsStateWithLifecycle()
    val deletion by app.model.accountDeletion.state.collectAsStateWithLifecycle()
    val keys by app.model.friends.keys.state.collectAsStateWithLifecycle()
    var showingLogin by remember { mutableStateOf(false) }
    if (
        !deletion.pending &&
            (state.uid == null ||
                keys.uid != state.uid ||
                (showingLogin && keys.displayedKey != null))
    ) {
        LaunchedEffect(Unit) { showingLogin = true }
        AccountLoginScreen()
    } else {
        LaunchedEffect(Unit) { showingLogin = false }
        content()
    }
}

@Composable
internal fun FriendProfileEditor(
    initialName: String,
    initialHue: Double,
    busy: Boolean,
    onDismiss: () -> Unit,
    onSave: (String, Double) -> Unit,
) {
    var name by rememberSaveable { mutableStateOf(initialName) }
    var hue by rememberSaveable { mutableDoubleStateOf(initialHue) }
    val cleanName = name.trim()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        TopAppBar(
            title = {
                Text(stringResource(R.string.friends_ui_edit_profile))
            },
            navigationIcon = {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Default.Close, stringResource(R.string.account_cancel))
                }
            },
            actions = {
                IconButton(
                    onClick = { onSave(cleanName, hue) },
                    enabled = !busy && cleanName.isNotEmpty() &&
                        (cleanName != initialName || hue != initialHue),
                ) {
                    Icon(Icons.Default.Check, stringResource(R.string.save))
                }
            },
        )
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            OutlinedTextField(
                name,
                { name = it.take(40) },
                Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.friends_ui_name)) },
                singleLine = true,
            )
            Text(stringResource(R.string.friends_ui_color), style = MaterialTheme.typography.titleSmall)
            ProfileHueWheel(cleanName, hue, { hue = it }, Modifier.align(Alignment.CenterHorizontally))
            Text(
                stringResource(R.string.friends_ui_color_hint),
                style = MaterialTheme.typography.bodyMedium,
            )
        }
    }
}

@Composable
internal fun ProfileHueWheel(
    name: String,
    hue: Double,
    onHueChange: (Double) -> Unit,
    modifier: Modifier = Modifier,
) {
    val updateHue by rememberUpdatedState(onHueChange)
    val label = stringResource(R.string.friends_ui_hue)
    val spectrum = remember {
        Brush.sweepGradient(
            (0..360 step 6).map {
                val rgb = ProfileColors.rgb(it.toDouble())
                Color(rgb.r.toFloat(), rgb.g.toFloat(), rgb.b.toFloat())
            }
        )
    }
    val rgb = ProfileColors.rgb(hue)
    val selectedColor = Color(rgb.r.toFloat(), rgb.g.toFloat(), rgb.b.toFloat())
    Box(
        modifier
            .size(232.dp)
            .testTag("friends-hue-wheel")
            .clearAndSetSemantics {
                contentDescription = label
                stateDescription = "${hue.toInt()}°"
                progressBarRangeInfo = ProgressBarRangeInfo(hue.toFloat(), 0f..360f, 71)
                setProgress { value ->
                    if (!value.isFinite()) false
                    else {
                        updateHue(ProfileReducer.resolvedHue(value.toDouble()))
                        true
                    }
                }
            }
            .pointerInput(Unit) {
                awaitEachGesture {
                    val down = awaitFirstDown()
                    val selected =
                        ProfileColors.hueAt(
                            down.position.x.toDouble(),
                            down.position.y.toDouble(),
                            size.width.toDouble(),
                        )
                    if (selected != null) {
                        down.consume()
                        updateHue(selected)
                        drag(down.id) { change ->
                            ProfileColors.hueForDrag(
                                    change.position.x.toDouble(),
                                    change.position.y.toDouble(),
                                    size.width.toDouble(),
                                )
                                ?.let(updateHue)
                            change.consume()
                        }
                    }
                }
            },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.matchParentSize()) {
            val radius = size.minDimension / 2 - 18.dp.toPx()
            rotate(-90f) { drawCircle(spectrum, radius = radius, style = Stroke(20.dp.toPx())) }
            val angle = (hue - 90) * kotlin.math.PI / 180
            val point =
                center + Offset(cos(angle).toFloat() * radius, sin(angle).toFloat() * radius)
            drawCircle(selectedColor, radius = 14.dp.toPx(), center = point)
            drawCircle(
                Color.White,
                radius = 12.5.dp.toPx(),
                center = point,
                style = Stroke(3.dp.toPx()),
            )
        }
        ProfileBadgeAvatar(name, hue, 112.dp)
    }
}

@Composable
internal fun AccountKeysScreen() {
    AccountRequired { AccountKeysScreenContent() }
}

@Composable
private fun AccountKeysScreenContent() {
    val adapter = LocalApp.current.model.friends
    val keys = adapter.keys
    val state by keys.state.collectAsStateWithLifecycle()
    val friends by adapter.controller.state.collectAsStateWithLifecycle()
    val deletion by LocalApp.current.model.accountDeletion.state.collectAsStateWithLifecycle()
    val busy = state.busy || friends.busy || deletion.busy || deletion.pending
    var replacing by remember { mutableStateOf(false) }
    AccountKeyLifetime(keys)
    LaunchedEffect(state.uid) { keys.refresh() }
    Page(stringResource(R.string.account_key_title)) { modifier ->
        Column(
            modifier.verticalScroll(rememberScrollState()).padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (!state.isKeyAccount) {
                Text(stringResource(R.string.account_key_standalone_only))
                return@Column
            }
            Text(stringResource(R.string.account_key_management_footer))
            OutlinedButton(
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
                onClick = { replacing = true },
                enabled = state.uid != null && !busy && !state.loading,
            ) {
                Text(
                    stringResource(
                        if (state.hasKey) R.string.account_key_replace else R.string.account_key_add
                    )
                )
            }
            Text(
                stringResource(R.string.account_key_recovery_hint),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            state.error?.let {
                Text(stringResource(it.androidString), color = MaterialTheme.colorScheme.error)
                TextButton(onClick = keys::refresh, enabled = !busy && !state.loading) {
                    Text(stringResource(R.string.account_key_retry))
                }
            }
            if (state.loading || state.busy) CircularProgressIndicator()
        }
    }
    state.displayedKey?.let { AccountKeyDialog(it, keys::hideKey) }
    if (replacing)
        AlertDialog(
            onDismissRequest = { replacing = false },
            title = { Text(stringResource(R.string.account_key_replace_title)) },
            text = { Text(stringResource(R.string.account_key_replace_warning)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        replacing = false
                        keys.replaceKey()
                    }
                ) {
                    Text(
                        stringResource(
                            if (state.hasKey) R.string.account_key_replace
                            else R.string.account_key_add
                        )
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { replacing = false }) {
                    Text(stringResource(R.string.account_cancel))
                }
            },
        )
}

@Composable
private fun AccountLoginScreen() {
    val app = LocalApp.current
    DisposableEffect(Unit) {
        app.onAccountLoginVisibilityChanged(true)
        onDispose { app.onAccountLoginVisibilityChanged(false) }
    }
    val adapter = app.model.friends
    val service = adapter.controller
    val state by service.state.collectAsStateWithLifecycle()
    val keys = adapter.keys
    val keyState by keys.state.collectAsStateWithLifecycle()
    val deletion by app.model.accountDeletion.state.collectAsStateWithLifecycle()
    val busy = state.busy || keyState.busy || keyState.loading || deletion.busy || deletion.pending
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    var method by rememberSaveable { mutableStateOf("") }
    var email by rememberSaveable { mutableStateOf("") }
    var link by remember { mutableStateOf("") }
    var key by remember { mutableStateOf("") }
    var scanFailed by remember { mutableStateOf(false) }
    AccountKeyLifetime(keys) {
        key = ""
        link = ""
    }
    LaunchedEffect(state.loginLink) { if (state.loginLink != null) method = "email" }
    BackHandler(method.isNotEmpty() && !busy) {
        method = ""
        key = ""
        link = ""
    }
    BackHandler(busy) {}
    Scaffold(
        topBar = {
            TopAppBar(
                expandedHeight =
                    if (method.isEmpty()) 52.dp else TopAppBarDefaults.TopAppBarExpandedHeight,
                title = {
                    when (method) {
                        "email" -> Text(stringResource(R.string.account_login_email))
                        "key" -> Text(stringResource(R.string.account_key_sign_in))
                        else -> Unit
                    }
                },
                navigationIcon = {
                    IconButton(
                        enabled = !busy,
                        onClick = {
                            if (method.isNotEmpty()) {
                                method = ""
                                key = ""
                                link = ""
                            } else {
                                keys.hideKey()
                                app.nav.popBackStack()
                            }
                        },
                    ) {
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
                .padding(
                    start = 24.dp,
                    end = 24.dp,
                    top = if (method.isEmpty()) 0.dp else 24.dp,
                    bottom = 24.dp,
                ),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (method.isEmpty()) {
                AccountLoginChoices(
                    enabled = !busy && adapter.configured,
                    onEmail = { method = "email" },
                    onGoogle = { (context as? Activity)?.let(adapter::signInGoogle) },
                    onApple = { (context as? Activity)?.let(adapter::signInApple) },
                    onCreateKeyAccount = keys::createAccount,
                    onKey = { method = "key" },
                    onPrivacy = { uri.openUri("https://festival.leongeorgi.de/privacy.html") },
                )
            } else if (method == "email") {
                OutlinedTextField(
                    email,
                    { email = it },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    label = { Text(stringResource(R.string.firebase_friends_email)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
                )
                Button(
                    onClick = { service.sendEmail(email) },
                    enabled = !busy && email.isNotBlank(),
                ) {
                    Text(stringResource(R.string.firebase_friends_send_email))
                }
                if (state.emailSent) Text(stringResource(R.string.firebase_friends_email_sent))
                state.loginLink?.let { incoming ->
                    Text(stringResource(R.string.firebase_friends_confirm_email))
                    Button(
                        onClick = { service.finishEmail(email, incoming) },
                        enabled = !busy && email.isNotBlank(),
                    ) {
                        Text(stringResource(R.string.firebase_friends_finish_email))
                    }
                }
                Spacer(Modifier.height(12.dp))
                Text(
                    stringResource(R.string.account_login_link_manually),
                    style = MaterialTheme.typography.titleSmall,
                )
                OutlinedTextField(
                    link,
                    { link = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(stringResource(R.string.firebase_friends_login_link)) },
                    visualTransformation = PasswordVisualTransformation(),
                )
                Button(
                    onClick = { service.finishEmail(email, link) },
                    enabled = !busy && email.isNotBlank() && link.isNotBlank(),
                ) {
                    Text(stringResource(R.string.firebase_friends_finish_email))
                }
            } else {
                OutlinedTextField(
                    key,
                    { key = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text(stringResource(R.string.account_key_input)) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                    visualTransformation = PasswordVisualTransformation(),
                )
                Button(onClick = { keys.signIn(key) }, enabled = !busy && key.isNotBlank()) {
                    Text(stringResource(R.string.account_key_sign_in))
                }
                TextButton(
                    onClick = {
                        scanFailed = false
                        GmsBarcodeScanning.getClient(context)
                            .startScan()
                            .addOnSuccessListener { key = it.rawValue.orEmpty() }
                            .addOnFailureListener { scanFailed = true }
                    },
                    enabled = !busy,
                ) {
                    Text(stringResource(R.string.account_key_scan))
                }
                if (scanFailed)
                    Text(
                        stringResource(R.string.account_key_scan_failed),
                        color = MaterialTheme.colorScheme.error,
                    )
                Text(
                    stringResource(R.string.account_key_management_footer),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            if (deletion.deleted) Text(stringResource(R.string.account_delete_success))
            if (!adapter.configured) Text(stringResource(R.string.firebase_friends_unavailable))
            state.error?.let {
                Text(stringResource(it.androidString), color = MaterialTheme.colorScheme.error)
            }
            keyState.error?.let {
                Text(stringResource(it.androidString), color = MaterialTheme.colorScheme.error)
            }
            if (busy) CircularProgressIndicator()
        }
    }
    keyState.displayedKey?.let { AccountKeyDialog(it, keys::hideKey) }
}

@Composable
private fun AccountLoginChoices(
    enabled: Boolean,
    onEmail: () -> Unit,
    onGoogle: () -> Unit,
    onApple: () -> Unit,
    onCreateKeyAccount: () -> Unit,
    onKey: () -> Unit,
    onPrivacy: () -> Unit,
) {
    val colors = MaterialTheme.colorScheme
    val type = MaterialTheme.typography
    Column(Modifier.fillMaxWidth()) {
        Text(
            stringResource(R.string.account_login),
            modifier = Modifier.semantics { heading() },
            style = type.displaySmall,
            fontSize = 40.sp,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(R.string.account_login_intro),
            style = type.bodyLarge,
            color = colors.onSurfaceVariant,
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = onEmail,
            enabled = enabled,
            modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
        ) {
            Text(stringResource(R.string.account_login_email), style = type.titleMedium)
        }

        Spacer(Modifier.height(28.dp))
        Text(
            stringResource(R.string.account_login_provider),
            modifier = Modifier.semantics { heading() },
            style = type.titleSmall,
            color = colors.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        ProviderLoginButton(
            R.string.firebase_friends_google, R.drawable.google_sign_in_logo, enabled, onGoogle,
        )
        Spacer(Modifier.height(8.dp))
        ProviderLoginButton(
            R.string.firebase_friends_apple, R.drawable.apple_sign_in_logo, enabled, onApple,
        )

        Spacer(Modifier.height(36.dp))
        Text(
            stringResource(R.string.account_login_without_email),
            modifier = Modifier.semantics { heading() },
            style = type.titleSmall,
            color = colors.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        KeyLoginAction(R.string.account_login_anonymous, first = true, enabled, onCreateKeyAccount)
        Spacer(Modifier.height(2.dp))
        KeyLoginAction(R.string.account_key_sign_in, first = false, enabled, onKey)
        Spacer(Modifier.height(14.dp))
        Text(
            stringResource(R.string.account_login_key_hint),
            style = type.bodyMedium,
            color = colors.onSurfaceVariant,
        )
        Spacer(Modifier.height(20.dp))
        HorizontalDivider(color = colors.surfaceContainerHigh)
        Spacer(Modifier.height(16.dp))
        Text(
            "${stringResource(R.string.account_login_local_hint)} ${stringResource(R.string.account_login_privacy_hint)}",
            style = type.bodyMedium,
            color = colors.onSurfaceVariant,
        )
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = onPrivacy, contentPadding = PaddingValues(0.dp)) {
            Text(stringResource(R.string.account_privacy))
        }
    }
}

@Composable
private fun ProviderLoginButton(title: Int, logo: Int, enabled: Boolean, onClick: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    val isApple = logo == R.drawable.apple_sign_in_logo
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().heightIn(min = 50.dp),
        border = BorderStroke(1.dp, if (enabled) Color(0xFF747775) else colors.outlineVariant),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = Color.White,
            contentColor = if (isApple) Color.Black else Color(0xFF1F1F1F),
            disabledContainerColor = Color.White,
            disabledContentColor = Color.Black.copy(alpha = .38f),
        ),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Image(
            painterResource(logo),
            contentDescription = null,
            modifier = Modifier.size(if (isApple) 34.dp else 20.dp)
                .alpha(if (enabled) 1f else .38f),
        )
        if (!isApple) Spacer(Modifier.width(10.dp))
        Text(
            stringResource(title),
            style = MaterialTheme.typography.titleSmall,
            fontFamily = if (isApple) null else GoogleSignInFont,
        )
    }
}

private val GoogleSignInFont = FontFamily(Font(R.font.google_sans_medium, FontWeight.Medium))

@Composable
private fun KeyLoginAction(title: Int, first: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val colors = MaterialTheme.colorScheme
    Surface(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth().semantics { role = Role.Button },
        shape = segmentedListShape(first = first, last = !first),
        color = when {
            !enabled -> colors.onSurface.copy(alpha = .12f)
            first -> colors.secondaryContainer
            else -> colors.surfaceContainer
        },
        contentColor = when {
            !enabled -> colors.onSurface.copy(alpha = .38f)
            first -> colors.onSecondaryContainer
            else -> colors.onSurface
        },
    ) {
        Row(
            Modifier.heightIn(min = 52.dp).padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(stringResource(title), Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
        }
    }
}

@Composable
private fun AccountKeyLifetime(keys: AccountKeyController, onBackground: () -> Unit = {}) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    val clear by rememberUpdatedState(onBackground)
    DisposableEffect(lifecycle, keys) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) {
                keys.hideKey()
                clear()
            }
        }
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer)
            keys.hideKey()
            clear()
        }
    }
}
