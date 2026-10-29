package de.leongeorgi.rudolstadt.loading

import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp

internal actual fun platformHttpClient(): HttpClient = HttpClient(OkHttp) { expectSuccess = false }
