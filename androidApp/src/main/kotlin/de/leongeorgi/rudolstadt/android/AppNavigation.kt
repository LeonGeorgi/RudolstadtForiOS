package de.leongeorgi.rudolstadt.android

import androidx.compose.runtime.Composable
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navigation

internal val appSections = listOf("map", "program", "artists", "news", "more")

internal fun NavHostController.currentSection(): String =
    currentDestination?.hierarchy?.firstOrNull { it.route in appSections }?.route ?: "program"

/** Nested graphs give each primary destination its own restorable back stack. */
internal fun NavHostController.selectSection(section: String) {
    if (currentSection() == section) return
    navigate(section) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

@Composable
internal fun FestivalNavHost(nav: NavHostController) {
    NavHost(nav, "program") {
        appSections.forEach { section ->
            navigation(startDestination = "$section/home", route = section) {
                composable("$section/home") {
                    when (section) {
                        "program" -> ScheduleScreen()
                        "artists" -> ArtistsScreen()
                        "map" -> MapScreen()
                        "news" -> NewsScreen()
                        "more" -> MoreScreen()
                    }
                }
                composable("$section/stage-map/{id}") {
                    MapScreen(it.arguments?.getString("id").orEmpty(), back = true)
                }
                val eventArgument =
                    listOf(
                        navArgument("event") {
                            type = NavType.LongType
                            defaultValue = -1L
                        }
                    )
                composable(
                    "$section/artist/{id}?event={event}&focus={focus}",
                    arguments = eventArgument + navArgument("focus") {
                        type = NavType.BoolType
                        defaultValue = false
                    },
                ) {
                    ArtistScreen(
                        it.arguments?.getString("id")?.toLongOrNull(),
                        it.arguments?.getLong("event")?.takeIf { value -> value >= 0 },
                        scrollToHighlightedEvent = it.arguments?.getBoolean("focus") == true,
                    )
                }
                composable("$section/place/{id}?event={event}", arguments = eventArgument) {
                    PlaceScreen(
                        it.arguments?.getString("id"),
                        it.arguments?.getLong("event")?.takeIf { value -> value >= 0 },
                    )
                }
                composable("$section/event/{id}") {
                    ConcertDetailScreen(it.arguments?.getString("id")?.toLongOrNull())
                }
                composable("$section/country/{code}") {
                    CountryScreen(it.arguments?.getString("code").orEmpty())
                }
                composable("$section/tag/{id}") {
                    TagScreen(it.arguments?.getString("id").orEmpty())
                }
                composable("$section/world") { WorldScreen() }
                composable("$section/genre/{id}") {
                    GenreScreen(it.arguments?.getString("id").orEmpty())
                }
                composable("$section/news/{id}") {
                    NewsDetail(it.arguments?.getString("id")?.toLongOrNull())
                }
                composable("$section/settings") { SettingsScreen() }
                composable("$section/information") { InformationScreen() }
                composable("$section/about") { AboutScreen() }
                composable("$section/licenses") { LicensesScreen() }
            }
        }
    }
}
