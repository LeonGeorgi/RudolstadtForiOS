package de.leongeorgi.rudolstadt.android

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import de.leongeorgi.rudolstadt.android.data.*
import de.leongeorgi.rudolstadt.loading.*
import de.leongeorgi.rudolstadt.planning.ProgramRecommendations
import de.leongeorgi.rudolstadt.presentation.*
import de.leongeorgi.rudolstadt.profile.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

internal data class AppState(
    val settings: LocalSettings = LocalSettings(),
    val settingsReady: Boolean = false,
    val settingsFailed: Boolean = false,
    val content: FestivalContent? = null,
    val refreshing: Boolean = false,
    val loadFailed: Boolean = false,
    val refreshFailed: Boolean = false,
    val source: String = "bundledBackup",
    val updatedAt: Double? = null,
    val newsRefreshing: Boolean = false,
    val syncedProfile: PersonalProfile? = null,
) {
    val edition
        get() = Edition.find(settings.edition)

    val profile
        get() =
            ProfileState(
                if (edition.key == Edition.current.key)
                    syncedProfile ?: settings.profile(edition.key)
                else settings.profile(edition.key)
            )
}

internal class AppModel(application: Application) : AndroidViewModel(application) {
    val friends = FirebaseFriends(application)
    private var cityMap: OfflineCityMap? = null
    private var mapForeground = true
    val offlineMaps: OfflineCityMap
        get() =
            cityMap
                ?: OfflineCityMap(getApplication()).also {
                    it.foreground(mapForeground)
                    cityMap = it
                }

    fun mapForeground(value: Boolean) {
        mapForeground = value
        cityMap?.foreground(value)
    }

    private val store = application.localSettings
    private val repository = FestivalRepository(application)
    private val mutableState = MutableStateFlow(AppState())
    val state = mutableState.asStateFlow()
    val discovery = DiscoveryViewModel()
    val recommendations = RecommendationViewModel()
    val news = NewsViewModel()
    private val messages = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val storageErrors = messages.asSharedFlow()
    private var settingsJob: Job? = null
    private var loadJob: Job? = null
    private var newsJob: Job? = null
    private var recommendationJob: Job? = null
    private val generation = RefreshGeneration()
    private var checkedAt = 0.0
    private var newsCheckedAt = 0.0
    val ownProfile = FirebaseOwnProfile(application, friends, viewModelScope)
    private val archiveProfiles = mutableMapOf<String, FirebaseOwnProfile>()
    val accountDeletion =
        AccountDeletionController(friends, ownProfile.controller, friends.accountActions)
    private val ownProfileObservation =
        ownProfile.controller.observe { value ->
            if (value.initialized) {
                val changed = mutableState.value.syncedProfile != value.profile
                mutableState.update { it.copy(syncedProfile = value.profile) }
                friends.controller.syncProfile(
                    value.profile,
                    value.uid,
                    value.phase == OwnProfilePhase.READY,
                )
                if (changed && mutableState.value.content != null) recalculate()
            }
        }

    init {
        readSettings()
        val initialOwn = ownProfile.controller.current
        if (initialOwn.initialized) {
            mutableState.update { it.copy(syncedProfile = initialOwn.profile) }
            friends.controller.syncProfile(
                initialOwn.profile,
                initialOwn.uid,
                initialOwn.phase == OwnProfilePhase.READY,
            )
        }
    }

    fun readSettings() {
        settingsJob?.cancel()
        mutableState.update { it.copy(settingsFailed = false) }
        settingsJob = viewModelScope.launch {
            try {
                store.data.collect { settings ->
                    val old = mutableState.value
                    mutableState.update {
                        it.copy(settings = settings, settingsReady = true, settingsFailed = false)
                    }
                    if (!old.settingsReady || old.settings.edition != settings.edition) {
                        val edition = Edition.find(settings.edition)
                        if (!old.settingsReady) {
                            for (archive in Edition.all) {
                                if (archive.archive && archive.supportsFirebaseFriends &&
                                    archive.key in settings.ownProfileSync
                                ) profileSync(archive)
                            }
                        }
                        if (edition.archive && edition.supportsFirebaseFriends) profileSync(edition)
                        val archiveEdition =
                            edition.friendsEdition.takeIf {
                                edition.supportsFirebaseFriends && edition.archive
                            }
                        friends.controller.showArchive(archiveEdition)
                        loadEdition()
                        configureNewsNotifications(
                            getApplication(),
                            settings.newsNotifications && edition.live,
                        )
                    } else if (
                        old.settings.profile().savedEventIDs != settings.profile().savedEventIDs ||
                            old.settings.profile().artistPreferences !=
                                settings.profile().artistPreferences
                    )
                        recalculate()
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                Log.e("PersonalData", "Could not read local personal data", failure)
                mutableState.update { it.copy(settingsFailed = true) }
            }
        }
    }

    fun changeSettings(change: (LocalSettings) -> LocalSettings) {
        viewModelScope.launch {
            try {
                store.updateData(change)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                Log.e("PersonalData", "Could not persist local personal data", failure)
                messages.emit(Unit)
            }
        }
    }

    fun mutate(mutation: ProfileMutation) {
        val edition = mutableState.value.edition
        if (!edition.editable || !mutableState.value.settingsReady) return
        if (mutation.kind == "setArtistNote" && !edition.notesEditable) return
        if (edition.supportsFirebaseFriends) {
            profileSync(edition).mutate(mutation)
            return
        }
        changeSettings { settings ->
            settings.copy(
                profiles =
                    settings.profiles +
                        (edition.key to
                            ProfileReducer.apply(settings.profile(edition.key), mutation))
            )
        }
    }

    fun profileSync(edition: Edition): OwnProfileController =
        if (edition == Edition.current) ownProfile.controller
        else archiveProfiles.getOrPut(edition.key) {
            FirebaseOwnProfile(getApplication(), friends, viewModelScope, edition)
        }.controller

    fun saveEvent(id: Long) = mutate(ProfileMutation("toggleSavedEvent", id))

    fun rate(id: Long, rating: Int) = mutate(ProfileMutation("setArtistRating", id, rating))

    fun note(id: Long, text: String) = mutate(ProfileMutation("setArtistNote", id, text = text))

    fun selectEdition(key: String) = changeSettings { it.copy(edition = Edition.find(key).key) }

    fun scheduleFilter(filter: String) {
        val edition = state.value.edition.key
        changeSettings { it.copy(scheduleFilters = it.scheduleFilters + (edition to filter)) }
    }

    fun markRead(id: Long) = changeSettings { it.copy(readNews = it.readNews + id) }

    fun toggleRead(id: Long) = changeSettings { settings ->
        settings.copy(
            readNews =
                if (id in settings.readNews) settings.readNews - id else settings.readNews + id
        )
    }

    fun markAllRead() {
        val ids = news.current.items.map { it.newsID }
        changeSettings { it.copy(readNews = it.readNews + ids) }
    }

    fun notifications(enabled: Boolean) {
        changeSettings { it.copy(newsNotifications = enabled) }
        configureNewsNotifications(getApplication(), enabled && mutableState.value.edition.live)
    }

    private fun loadEdition() {
        loadJob?.cancel()
        loadJob = null
        newsJob?.cancel()
        newsJob = null
        recommendationJob?.cancel()
        generation.begin()
        mutableState.update {
            it.copy(
                content = null,
                loadFailed = false,
                refreshFailed = false,
                updatedAt = null,
                refreshing = false,
                newsRefreshing = false,
            )
        }
        recommendations.reset()
        discovery.clearFilters()
        discovery.search("")
        news.present(emptyList(), null, null, null)
        checkedAt = 0.0
        newsCheckedAt = 0.0
        refresh()
        refreshNews()
    }

    fun onForeground() {
        if (state.value.content != null) recalculate()
        if (state.value.settingsReady && now() - checkedAt > CachePolicy.maximumAgeSeconds)
            refresh()
        if (state.value.settingsReady && now() - newsCheckedAt > 180) refreshNews()
    }

    fun refresh(force: Boolean = false) {
        if (loadJob?.isActive == true) return
        val edition = mutableState.value.edition
        val token = generation.begin()
        loadJob = viewModelScope.launch {
            mutableState.update {
                it.copy(refreshing = true, refreshFailed = false, loadFailed = false)
            }
            val session = ProgramLoadSession(edition.live, mutableState.value.content != null)
            try {
                var cached: Pair<FestivalContent, Double>? = null
                if (edition.live && !force) {
                    cached = recover { repository.cached(edition) }
                    cached?.let {
                        publish(
                            token,
                            it.first,
                            if (CachePolicy.isStale(it.second, now())) "staleCache" else "cache",
                            it.second,
                        )
                    }
                }
                val action =
                    session.cacheRead(
                        cached != null,
                        cached != null && !CachePolicy.isStale(cached.second, now()),
                    )
                if (mutableState.value.content == null) {
                    val bundle = recover { repository.bundle(edition) }
                    if (bundle != null) {
                        publish(
                            token,
                            bundle,
                            when {
                                edition.archive -> "bundledArchive"
                                edition.experimental -> "bundledExperiment"
                                else -> "bundledBackup"
                            },
                            null,
                        )
                        session.bundleRead(true)
                    }
                }
                if (edition.live && (force || action == ProgramLoadAction.REFRESH)) {
                    try {
                        val (content, time) = repository.refresh(edition)
                        publish(token, content, "remote", time)
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (failure: Exception) {
                        Log.w("FestivalData", "Remote refresh failed", failure)
                        session.remoteFailed()
                        if (generation.isCurrent(token))
                            mutableState.update { it.copy(refreshFailed = true) }
                    }
                }
                if (generation.isCurrent(token))
                    mutableState.update { it.copy(loadFailed = it.content == null) }
            } finally {
                if (generation.isCurrent(token)) {
                    checkedAt = now()
                    mutableState.update { it.copy(refreshing = false) }
                }
            }
        }
    }

    private fun publish(token: Long, content: FestivalContent, source: String, time: Double?) {
        if (!generation.isCurrent(token) || content.edition.key != state.value.edition.key) return
        mutableState.update { it.copy(content = content, source = source, updatedAt = time) }
        recalculate()
    }

    private fun recalculate() {
        recommendationJob?.cancel()
        recommendations.inputsChanged()
        val input = state.value
        val content = input.content ?: return
        if (!content.edition.definition.automaticPlanning) {
            recommendations.disable()
            return
        }
        recommendationJob = viewModelScope.launch {
            delay(180)
            val token = recommendations.beginRefresh()
            val profile = input.profile
            val context = currentCoroutineContext()
            try {
                val result =
                    withContext(Dispatchers.Default) {
                        ProgramRecommendations.build(
                            content.program,
                            profile.profile.savedEventIDs,
                            profile.ratings,
                            now(),
                            true,
                            content.capabilities.planning?.eligibleIDs,
                            content.transfer,
                        ) {
                            !context.isActive
                        }
                    }
                recommendations.complete(token, result, now())
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (failure: Exception) {
                Log.e("Planning", "Could not calculate recommendations", failure)
                recommendations.unavailable()
            }
        }
    }

    fun refreshNews(force: Boolean = false) {
        if (!state.value.edition.live || newsJob?.isActive == true) return
        val editionKey = state.value.edition.key
        newsJob = viewModelScope.launch {
            mutableState.update { it.copy(newsRefreshing = true) }
            val request = news.beginRefresh()
            try {
                if (!force && news.current.items.isEmpty()) {
                    val cache = recover { repository.cachedNews() }
                    if (cache != null) news.applySnapshot(cache.first)
                    else recover { repository.bundledNews() }?.let(news::applySnapshot)
                }
                try {
                    val (snapshot, _) = repository.refreshNews()
                    if (news.isCurrent(request.generation)) {
                        news.applySnapshot(snapshot)
                        changeSettings {
                            it.copy(
                                knownNews =
                                    it.knownNews + news.current.items.map { item -> item.newsID },
                                newsBaseline = true,
                            )
                        }
                    }
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (failure: Exception) {
                    Log.w("FestivalNews", "News refresh failed", failure)
                    news.refreshFailed(request.generation)
                    if (news.current.items.isEmpty())
                        recover { repository.bundledNews() }?.let(news::applySnapshot)
                    news.bundleFinished(request.generation)
                }
            } finally {
                if (state.value.edition.key == editionKey) {
                    newsCheckedAt = now()
                    mutableState.update { it.copy(newsRefreshing = false) }
                }
            }
        }
    }

    private suspend fun <T> recover(block: suspend () -> T): T? =
        try {
            block()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (failure: Exception) {
            Log.w("FestivalData", "Could not read optional cached or bundled data", failure)
            null
        }

    override fun onCleared() {
        accountDeletion.close()
        friends.close()
        ownProfileObservation.cancel()
        ownProfile.close()
        archiveProfiles.values.forEach { it.close() }
        cityMap?.close()
        repository.close()
        super.onCleared()
    }
}

internal fun now() = System.currentTimeMillis() / 1000.0
