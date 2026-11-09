@file:OptIn(
    androidx.compose.material3.ExperimentalMaterial3Api::class,
    androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class,
)

package de.leongeorgi.rudolstadt.android

import android.app.Activity
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.gestures.snapping.SnapPosition
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.google.mlkit.vision.codescanner.GmsBarcodeScanning
import de.leongeorgi.rudolstadt.profile.*

private enum class FriendsPage {
    HOME,
    INVITATION,
    ACCEPT,
    RECOMMENDATIONS,
    ALL_FRIENDS,
    DETAIL,
    CAMERA,
}

@Composable
internal fun FriendsScreen() {
    AccountRequired { FriendsContent() }
}

@Composable
private fun FriendsContent() {
    val app = LocalApp.current
    val service = app.model.friends.controller
    val state by service.state.collectAsStateWithLifecycle()
    val keyState by app.model.friends.keys.state.collectAsStateWithLifecycle()
    val deletionController = app.model.accountDeletion
    val deletion by deletionController.state.collectAsStateWithLifecycle()
    val edition = app.state.edition
    val accountSync = app.model.ownProfile.controller
    val account by accountSync.state.collectAsStateWithLifecycle()
    val syncController = app.model.profileSync(edition)
    val sync by syncController.state.collectAsStateWithLifecycle()
    val busy = state.busy || keyState.busy || deletion.busy || deletion.pending
    val canSaveProfile = !busy && state.uid != null && account.uid == state.uid
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    var page by rememberSaveable(state.uid) { mutableStateOf(FriendsPage.HOME) }
    var detailReturnPage by rememberSaveable(state.uid) { mutableStateOf(FriendsPage.HOME) }
    var selectedUID by rememberSaveable(state.uid) { mutableStateOf<String?>(null) }
    var detailSection by
        rememberSaveable(state.uid, selectedUID) {
            mutableStateOf<FriendProfileSection?>(null)
        }
    val friendOverviewState = key(state.uid, selectedUID) { rememberLazyListState() }
    val homeListState = key(state.uid) { rememberLazyListState() }
    val homeAppBarState = key(state.uid) { rememberTopAppBarState() }
    val allFriendsListState = key(state.uid) { rememberLazyListState() }
    val friendPagerState = key(state.uid) { rememberPagerState { state.connections.size } }
    var removing by remember(state.uid) { mutableStateOf<FriendConnection?>(null) }
    val requestFriendRemoval: ((FriendConnection) -> Unit)? =
        if (busy) null else { friend -> removing = friend }
    var editingProfile by rememberSaveable(state.uid) { mutableStateOf(false) }
    var setupName by rememberSaveable(state.uid) { mutableStateOf("") }
    var setupHue by rememberSaveable(state.uid) { mutableDoubleStateOf(ProfileReducer.defaultHue) }
    var choosingBadgeColor by rememberSaveable(state.uid) { mutableStateOf(false) }
    var deletingAccount by remember(state.uid) { mutableStateOf(false) }
    val identityName = state.identity?.name ?: account.profile.badgeName.orEmpty()
    val identityHue = state.identity?.hue ?: account.profile.badgeHue
    val syncProblem = sync.problem
    val friendProfiles =
        when {
            edition.live -> state.friends
            edition.friendsEdition == state.archiveEdition -> state.archiveFriends
            else -> emptyList()
        }
    val recommendations = rememberFriendRecommendations(friendProfiles)
    val profileMenu: @Composable (Boolean) -> Unit = { showAsText ->
        FriendsProfileMenu(
            busy = busy,
            showAsText = showAsText,
            name = identityName,
            hue = identityHue,
            active = state.active,
            isKeyAccount = keyState.isKeyAccount,
            edit = { editingProfile = true },
            key = { app.navigate("account/key") },
            signOut = service::signOut,
            delete = { deletingAccount = true },
        )
    }
    val profileActions: @Composable RowScope.() -> Unit = {
        IconButton(
            onClick = syncController::retry,
            enabled =
                !busy &&
                    state.uid != null &&
                    (sync.phase == OwnProfilePhase.READY || sync.problem != null),
        ) {
            Icon(Icons.Default.Sync, stringResource(R.string.profile_sync_now))
        }
        profileMenu(false)
    }

    fun back() {
        if (page == FriendsPage.DETAIL && detailSection != null) {
            detailSection = null
            return
        }
        if (page == FriendsPage.ACCEPT) service.dismissInvite()
        page = if (page == FriendsPage.DETAIL) detailReturnPage else FriendsPage.HOME
    }
    fun openFriend(friend: FriendConnection) {
        detailReturnPage = page
        selectedUID = friend.uid
        detailSection = null
        page = FriendsPage.DETAIL
    }
    fun createInvitation() {
        page = FriendsPage.INVITATION
        service.createInvite()
    }
    fun saveProfile(name: String, hue: Double) {
        if (
            !canSaveProfile ||
                service.current.uid != state.uid ||
                accountSync.current.uid != state.uid
        )
            return
        val selected = accountSync.current.profile.copy(badgeName = name, badgeHue = hue)
        accountSync.mutate(ProfileMutation("updateBadge", text = name, hue = hue))
        service.activate(selected)
    }
    fun scan() {
        GmsBarcodeScanning.getClient(context)
            .startScan()
            .addOnSuccessListener {
                if (!service.receive(it.rawValue.orEmpty())) service.invalidLink()
            }
            .addOnFailureListener { page = FriendsPage.CAMERA }
    }

    LaunchedEffect(state.active, state.invitation) {
        if (state.active && state.invitation != null) page = FriendsPage.ACCEPT
        else if (page == FriendsPage.ACCEPT) page = FriendsPage.HOME
    }
    LaunchedEffect(page, state.invitation, state.busy, state.active) {
        if (
            page == FriendsPage.ACCEPT &&
                state.active &&
                !state.busy &&
                state.previewName == null &&
                state.error == null
        )
            service.previewInvite()
    }
    BackHandler(page != FriendsPage.HOME && state.active) { back() }
    BackHandler(!state.active && state.identityLoaded && choosingBadgeColor && !deletion.pending) {
        if (!busy) choosingBadgeColor = false
    }

    if (deletion.pending) {
        Page(stringResource(R.string.firebase_friends_title)) { modifier ->
            Column(modifier.padding(24.dp)) {
                AccountDeletionFeedback(deletion, deletionController::retry)
            }
        }
        return
    }
    if (!app.model.friends.configured) {
        Page(stringResource(R.string.firebase_friends_title)) { modifier ->
            Text(stringResource(R.string.firebase_friends_unavailable), modifier.padding(24.dp))
        }
        return
    }

    when {
        !state.active -> {
            val title = when {
                !state.identityLoaded -> R.string.firebase_friends_title
                choosingBadgeColor -> R.string.friends_ui_color
                else -> R.string.friends_ui_setup
            }
            val cleanName = setupName.trim()
            Page(
                stringResource(title),
                onBack = if (state.identityLoaded && choosingBadgeColor) {
                    { if (!busy) choosingBadgeColor = false }
                } else null,
            ) { modifier ->
                Column(
                    modifier.imePadding().verticalScroll(rememberScrollState()).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    if (state.identityLoaded) {
                        if (choosingBadgeColor) {
                            ProfileHueWheel(
                                cleanName,
                                setupHue,
                                { setupHue = it },
                                Modifier.align(Alignment.CenterHorizontally),
                            )
                            Text(stringResource(R.string.friends_ui_color_hint))
                        } else {
                            ProfileBadgeAvatar(
                                cleanName,
                                ProfileReducer.defaultHue,
                                112.dp,
                                Modifier.align(Alignment.CenterHorizontally).clearAndSetSemantics {},
                            )
                            Text(
                                stringResource(R.string.friends_ui_name_prompt),
                                style = MaterialTheme.typography.titleMedium,
                            )
                            OutlinedTextField(
                                setupName,
                                { setupName = it.take(40) },
                                Modifier.fillMaxWidth(),
                                label = { Text(stringResource(R.string.friends_ui_name)) },
                                singleLine = true,
                            )
                        }
                        FriendActionButton(
                            stringResource(R.string.save),
                            !busy && cleanName.isNotEmpty() && (!choosingBadgeColor || canSaveProfile),
                        ) {
                            if (choosingBadgeColor) saveProfile(cleanName, setupHue)
                            else {
                                focusManager.clearFocus()
                                setupName = cleanName
                                choosingBadgeColor = true
                            }
                        }
                    } else if (state.error == null && !state.busy) {
                        CircularProgressIndicator(Modifier.align(Alignment.CenterHorizontally))
                    }
                    profileMenu(true)
                    AccountDeletionFeedback(deletion, deletionController::retry)
                    syncProblem?.let {
                        Text(stringResource(it.androidString), color = MaterialTheme.colorScheme.error)
                        TextButton(onClick = syncController::retry, enabled = !busy) {
                            Text(stringResource(R.string.profile_sync_retry))
                        }
                    }
                    FriendFeedback(state)
                }
            }
        }
        page == FriendsPage.INVITATION ->
            Page(stringResource(R.string.friends_ui_invitation), onBack = ::back) { modifier ->
                Column(
                    modifier.verticalScroll(rememberScrollState()).padding(24.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                ) {
                    Text(stringResource(R.string.friends_ui_invite_hint))
                    if (state.busy)
                        CircularProgressIndicator(Modifier.align(Alignment.CenterHorizontally))
                    else
                        state.ownInvite?.let { url ->
                            FriendQRCode(url, Modifier.align(Alignment.CenterHorizontally))
                            Text(
                                stringResource(R.string.firebase_friends_invite_lifetime),
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            FriendActionButton(
                                stringResource(R.string.firebase_friends_share),
                                !busy,
                            ) {
                                share(context, url)
                            }
                        }
                    FriendFeedback(state)
                    TextButton(
                        onClick = service::createInvite,
                        enabled = !busy,
                        modifier = Modifier.align(Alignment.CenterHorizontally),
                    ) {
                        Text(stringResource(R.string.friends_ui_new_invite))
                    }
                }
            }
        page == FriendsPage.ACCEPT ->
            Page(stringResource(R.string.friends_ui_invitation), onBack = ::back) { modifier ->
                Column(
                    modifier.verticalScroll(rememberScrollState()).padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                ) {
                    Spacer(Modifier.height(8.dp))
                    state.previewName?.let { friendName ->
                        Icon(
                            Icons.Default.AccountCircle,
                            null,
                            Modifier.size(80.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(friendName, style = MaterialTheme.typography.headlineSmall)
                        Text(stringResource(R.string.friends_ui_invited_by, friendName))
                        Text(
                            stringResource(R.string.firebase_friends_consent),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(8.dp))
                        FriendActionButton(
                            stringResource(R.string.friends_ui_accept),
                            !busy,
                            service::acceptInvite,
                        )
                    }
                    FriendFeedback(state)
                    if (state.error != null)
                        TextButton(onClick = service::previewInvite, enabled = !busy) {
                            Text(stringResource(R.string.retry))
                        }
                    TextButton(onClick = ::back, enabled = !busy) {
                        Text(stringResource(R.string.firebase_friends_dismiss))
                    }
                }
            }
        page == FriendsPage.CAMERA ->
            Page(stringResource(R.string.friends_ui_scan), onBack = ::back) { modifier ->
                Column(modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
                    Card(shape = RoundedCornerShape(24.dp)) {
                        Column(
                            Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            Text(
                                stringResource(R.string.friends_ui_scanner_unavailable),
                                style = MaterialTheme.typography.titleLarge,
                            )
                            Text(stringResource(R.string.friends_ui_scanner_hint))
                        }
                    }
                    FriendActionButton(stringResource(R.string.retry), action = ::scan)
                }
            }
        page == FriendsPage.RECOMMENDATIONS ->
            Page(stringResource(R.string.friends_ui_recommendations_title), onBack = ::back) {
                modifier ->
                LazyColumn(
                    modifier,
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    if (recommendations.isEmpty())
                        item { Text(stringResource(R.string.friends_ui_recommendations_empty)) }
                    items(recommendations, key = { it.artistID }) {
                        FriendRecommendationRow(it, friendProfiles)
                    }
                }
            }
        page == FriendsPage.ALL_FRIENDS ->
            Page(stringResource(R.string.friends_ui_all), onBack = ::back) { modifier ->
                LazyColumn(
                    modifier,
                    state = allFriendsListState,
                    contentPadding = PaddingValues(vertical = 16.dp),
                ) {
                    if (state.error != null || state.busy)
                        item {
                            Box(Modifier.padding(horizontal = 16.dp).padding(bottom = 12.dp)) {
                                FriendFeedback(state, retry = service::retryPublish)
                            }
                        }
                    if (state.connections.isEmpty())
                        item {
                            Text(
                                stringResource(R.string.friends_ui_empty),
                                Modifier.padding(16.dp),
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    itemsIndexed(state.connections, key = { _, friend -> friend.uid }) {
                        index,
                        friend ->
                        FriendListSegment(
                            connection = friend,
                            index = index,
                            count = state.connections.size,
                            open = { openFriend(friend) },
                            remove = requestFriendRemoval?.let { request -> { request(friend) } },
                        )
                    }
                }
            }
        page == FriendsPage.DETAIL -> {
            val uid = selectedUID
            val friend = state.connections.firstOrNull { it.uid == uid }
            val name = friend?.name ?: stringResource(R.string.firebase_friends_details)
            val section = detailSection
            Page(
                section?.let { friendProfileSectionTitle(it, name) } ?: name,
                onBack = ::back,
            ) { modifier ->
                FriendDetail(
                    modifier = modifier,
                    connection = friend,
                    profile = friendProfiles.firstOrNull { it.profileID == uid },
                    section = section,
                    overviewState = friendOverviewState,
                    onOpenSection = { detailSection = it },
                )
            }
        }
        else -> {
            val scrollBehavior = TopAppBarDefaults.exitUntilCollapsedScrollBehavior(homeAppBarState)
            val showAccountFeedback =
                deletion.problem != null || deletion.busy || syncProblem != null
            val showFriendsFeedback = state.error != null || state.busy
            Scaffold(
                modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
                topBar = {
                    LargeFlexibleTopAppBar(
                        title = { Text(stringResource(R.string.firebase_friends_title)) },
                        navigationIcon = {
                            IconButton(onClick = { app.nav.popBackStack() }) {
                                Icon(
                                    Icons.AutoMirrored.Filled.ArrowBack,
                                    stringResource(R.string.back),
                                )
                            }
                        },
                        actions = {
                            FriendsAddMenu(
                                busy,
                                invite = ::createInvitation,
                                scan = ::scan,
                            )
                            profileActions()
                        },
                        scrollBehavior = scrollBehavior,
                    )
                },
            ) { padding ->
                LazyColumn(
                    Modifier.fillMaxSize()
                        .padding(padding)
                        .semantics { testTagsAsResourceId = true }
                        .testTag("friends-home"),
                    state = homeListState,
                    contentPadding = PaddingValues(vertical = 12.dp),
                    verticalArrangement =
                        if (
                            state.connections.isEmpty() &&
                                !showAccountFeedback &&
                                !showFriendsFeedback
                        )
                            Arrangement.Center
                        else Arrangement.Top,
                ) {
                    if (showAccountFeedback)
                        item {
                            Column(
                                Modifier.padding(horizontal = 16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                AccountDeletionFeedback(deletion, deletionController::retry)
                                syncProblem?.let {
                                    Text(stringResource(it.androidString), color = MaterialTheme.colorScheme.error)
                                }
                            }
                        }
                    if (showFriendsFeedback)
                        item {
                            Box(Modifier.padding(horizontal = 16.dp)) {
                                FriendFeedback(state, retry = service::retryPublish)
                            }
                        }
                    if (state.connections.isEmpty()) {
                        item {
                            EmptyFriendsContent(
                                enabled = !busy,
                                invite = ::createInvitation,
                                scan = ::scan,
                            )
                        }
                    } else {
                        item {
                            Row(
                                Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    stringResource(R.string.friends_ui_recommendations),
                                    Modifier.weight(1f),
                                    style = MaterialTheme.typography.titleLarge,
                                )
                                TextButton(
                                    onClick = { page = FriendsPage.RECOMMENDATIONS },
                                    modifier = Modifier.testTag("friends-recommendations"),
                                ) {
                                    Text(stringResource(R.string.friends_ui_see_all))
                                }
                            }
                        }
                        if (recommendations.isEmpty())
                            item {
                                Text(
                                    stringResource(R.string.friends_ui_recommendations_empty),
                                    Modifier.padding(24.dp),
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        else
                            item {
                                BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 8.dp)) {
                                    val rowState = rememberLazyListState()
                                    LazyRow(
                                        state = rowState,
                                        flingBehavior =
                                            rememberSnapFlingBehavior(rowState, SnapPosition.Start),
                                        contentPadding =
                                            PaddingValues(
                                                start = 16.dp,
                                                end =
                                                    (maxWidth - 224.dp - 16.dp).coerceAtLeast(
                                                        16.dp
                                                    ),
                                            ),
                                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                                    ) {
                                        items(recommendations.take(12), key = { it.artistID }) {
                                            FriendRecommendationTile(it, friendProfiles)
                                        }
                                    }
                                }
                            }
                        item {
                            val allFriendsLabel = stringResource(R.string.friends_ui_all)
                            Row(
                                Modifier.fillMaxWidth()
                                    .padding(horizontal = 16.dp)
                                    .padding(top = 20.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                            ) {
                                Text(
                                    stringResource(
                                        R.string.friends_ui_count,
                                        state.connections.size,
                                    ),
                                    Modifier.weight(1f).semantics { heading() },
                                    style = MaterialTheme.typography.titleLarge,
                                )
                                TextButton(
                                    onClick = { page = FriendsPage.ALL_FRIENDS },
                                    modifier =
                                        Modifier.testTag("friends-all").semantics {
                                            contentDescription = allFriendsLabel
                                        },
                                ) {
                                    Text(stringResource(R.string.friends_ui_see_all))
                                }
                            }
                        }
                        item {
                            FriendProfilePager(
                                state.connections,
                                friendPagerState,
                                open = ::openFriend,
                                remove = requestFriendRemoval,
                            )
                        }
                        item { Spacer(Modifier.height(24.dp)) }
                    }
                }
            }
        }
    }
    if (state.active && editingProfile) {
        FriendProfileEditor(
            initialName = identityName,
            initialHue = identityHue,
            busy = !canSaveProfile,
            onDismiss = { editingProfile = false },
            onSave = { name, hue ->
                editingProfile = false
                saveProfile(name, hue)
            },
        )
    }
    if (deletingAccount) {
        AlertDialog(
            onDismissRequest = { deletingAccount = false },
            title = { Text(stringResource(R.string.account_delete_title)) },
            text = { Text(stringResource(R.string.account_delete_warning)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        deletingAccount = false
                        app.model.friends.keys.hideKey()
                        (context as? Activity)?.let { activity ->
                            deletionController.deleteAccount { owner, completed ->
                                app.model.friends.prepareAccountDeletion(activity, owner, completed)
                            }
                        }
                    },
                    enabled = !busy,
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                ) {
                    Text(stringResource(R.string.account_delete_action))
                }
            },
            dismissButton = {
                TextButton(onClick = { deletingAccount = false }) {
                    Text(stringResource(R.string.account_cancel))
                }
            },
        )
    }
    removing?.let { friend ->
        AlertDialog(
            onDismissRequest = { removing = null },
            title = { Text(stringResource(R.string.firebase_friends_remove)) },
            text = { Text(stringResource(R.string.firebase_friends_remove_consent)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        service.removeFriend(friend.uid)
                        removing = null
                    },
                    enabled = !busy,
                ) {
                    Text(stringResource(R.string.firebase_friends_remove))
                }
            },
            dismissButton = {
                TextButton(onClick = { removing = null }) {
                    Text(stringResource(R.string.account_cancel))
                }
            },
        )
    }
}

@Composable
private fun EmptyFriendsContent(enabled: Boolean, invite: () -> Unit, scan: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            Icons.Default.People,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(R.string.friends_ui_empty),
            modifier = Modifier.semantics { heading() },
            style =
                MaterialTheme.typography.headlineSmall.copy(
                    fontSize = 26.sp,
                    fontWeight = FontWeight.SemiBold,
                ),
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            stringResource(R.string.friends_ui_empty_description),
            modifier = Modifier.widthIn(max = 276.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = invite,
            modifier = Modifier.widthIn(min = 190.dp).heightIn(min = 56.dp),
            enabled = enabled,
        ) {
            Text(stringResource(R.string.firebase_friends_invite), textAlign = TextAlign.Center)
        }
        Spacer(Modifier.height(8.dp))
        TextButton(onClick = scan, enabled = enabled, modifier = Modifier.heightIn(min = 48.dp)) {
            Text(stringResource(R.string.friends_ui_scan), textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun FriendsAddMenu(
    busy: Boolean,
    invite: () -> Unit,
    scan: () -> Unit,
) {
    var adding by remember { mutableStateOf(false) }
    Box {
        FilledTonalIconButton(
            onClick = { adding = true },
            enabled = !busy,
            modifier = Modifier.testTag("friends-add"),
        ) {
            Icon(Icons.Default.PersonAdd, stringResource(R.string.friends_ui_add))
        }
        ExpressiveContextMenu(expanded = adding, onDismissRequest = { adding = false }) {
            ExpressiveMenuGroup {
                ExpressiveMenuItem(
                    label = stringResource(R.string.firebase_friends_invite),
                    icon = Icons.Default.QrCode2,
                    enabled = !busy,
                    onClick = {
                        adding = false
                        invite()
                    },
                )
                ExpressiveMenuItem(
                    label = stringResource(R.string.friends_ui_scan),
                    icon = Icons.Default.QrCodeScanner,
                    enabled = !busy,
                    onClick = {
                        adding = false
                        scan()
                    },
                )
            }
        }
    }
}

@Composable
private fun FriendsProfileMenu(
    busy: Boolean,
    showAsText: Boolean,
    name: String,
    hue: Double,
    active: Boolean,
    isKeyAccount: Boolean,
    edit: () -> Unit,
    key: () -> Unit,
    signOut: () -> Unit,
    delete: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val profileLabel = stringResource(R.string.friends_ui_profile)
    Box {
        if (showAsText) {
            TextButton(onClick = { expanded = true }, enabled = !busy) {
                Text(stringResource(R.string.account_title))
            }
        } else {
            IconButton(
                onClick = { expanded = true },
                enabled = !busy,
                modifier = Modifier.testTag("friends-profile").semantics {
                    contentDescription = profileLabel
                },
            ) {
                ProfileBadgeAvatar(name, hue, 40.dp)
            }
        }
        ExpressiveContextMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            ExpressiveMenuGroup {
                if (active) {
                    ExpressiveMenuItem(
                        label = stringResource(R.string.friends_ui_edit_profile),
                        icon = Icons.Default.Edit,
                        enabled = !busy,
                        onClick = {
                            expanded = false
                            edit()
                        },
                    )
                }
                if (isKeyAccount) {
                    ExpressiveMenuItem(
                        label = stringResource(R.string.account_key_title),
                        icon = Icons.Default.Key,
                        enabled = !busy,
                        onClick = {
                            expanded = false
                            key()
                        },
                    )
                }
                ExpressiveMenuItem(
                    label = stringResource(R.string.firebase_friends_sign_out),
                    icon = Icons.AutoMirrored.Filled.Logout,
                    enabled = !busy,
                    onClick = {
                        expanded = false
                        signOut()
                    },
                )
            }
            ExpressiveMenuGroup {
                ExpressiveMenuItem(
                    label = stringResource(R.string.account_delete_short),
                    icon = Icons.Default.DeleteOutline,
                    enabled = !busy,
                    destructive = true,
                    onClick = {
                        expanded = false
                        delete()
                    },
                )
            }
        }
    }
}

@Composable
private fun AccountDeletionFeedback(state: AccountDeletionState, retry: () -> Unit) {
    state.problem?.let {
        val message = when (it) {
            AccountDeletionProblem.LOCAL_STORAGE -> R.string.account_delete_error_local
            AccountDeletionProblem.AUTHENTICATION -> R.string.account_delete_error_auth
            AccountDeletionProblem.CONNECTION -> R.string.account_delete_error_connection
        }
        Text(stringResource(message), color = MaterialTheme.colorScheme.error)
    }
    if (state.pending) {
        Text(stringResource(R.string.account_delete_pending))
        TextButton(onClick = retry, enabled = !state.busy) {
            Text(stringResource(R.string.account_delete_retry))
        }
    }
    if (state.busy) CircularProgressIndicator()
}
