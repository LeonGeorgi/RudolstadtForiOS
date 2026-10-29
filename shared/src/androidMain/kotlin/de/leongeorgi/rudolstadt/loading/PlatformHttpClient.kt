package de.leongeorgi.rudolstadt.loading

import io.ktor.client.HttpClient
import io.ktor.client.engine.android.Android

internal actual fun platformHttpClient(): HttpClient = HttpClient(Android) { expectSuccess = false }
