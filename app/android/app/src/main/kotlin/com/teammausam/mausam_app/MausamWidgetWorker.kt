package com.teammausam.mausam_app

import android.content.Context
import android.net.Uri
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/**
 * Keeps the widget warm while the app is closed (docs/06 §Home-screen widget → Background
 * refresh).
 *
 * Once an hour it calls `GET /home?lite=1` with the backend URL, guest token, location,
 * personas and language the app last stored, writes the compact snapshot into the same shared
 * storage the app writes, and redraws the widget. Best-effort and silent: no notification, no
 * retry storm, no new permission — INTERNET is the only one the app already holds.
 *
 * Nothing here runs unless the user has actually placed a widget: [enqueue] is called from
 * `MausamWidgetProvider.onEnabled` / `onUpdate`, and [cancel] from `onDisabled`.
 */
class MausamWidgetWorker(context: Context, params: WorkerParameters) :
    Worker(context, params) {

    override fun doWork(): Result {
        val prefs = HomeWidgetPlugin.getData(applicationContext)
        val backendUrl = prefs.getString(WidgetKeys.BACKEND_URL, null)?.trimEnd('/')
        val lat = prefs.getString(WidgetKeys.LAT, null)
        val lon = prefs.getString(WidgetKeys.LON, null)
        // Never onboarded, or the app has not published yet — leave the last snapshot alone.
        if (backendUrl.isNullOrBlank() || lat.isNullOrBlank() || lon.isNullOrBlank()) {
            return Result.success()
        }

        val lang = prefs.getString(WidgetKeys.LANG, null) ?: "en"
        val units = prefs.getString(WidgetKeys.UNITS, null) ?: "metric"
        val personas = prefs.getString(WidgetKeys.PERSONAS, null).orEmpty()
        val token = prefs.getString(WidgetKeys.TOKEN, null).orEmpty()

        val builder = Uri.parse("$backendUrl${WidgetKeys.API_PREFIX}/home").buildUpon()
            .appendQueryParameter("lat", lat)
            .appendQueryParameter("lon", lon)
            .appendQueryParameter("lang", lang)
            .appendQueryParameter("lite", "1")
        if (personas.isNotBlank()) builder.appendQueryParameter("personas", personas)

        val body = fetch(builder.build().toString(), token, lang)
            ?: return Result.success() // offline or backend down: keep what we have, try later

        return try {
            val snapshot = WidgetSnapshot.fromHome(JSONObject(body), lang, units)
            if (snapshot.isEmpty) return Result.success()
            prefs.edit().putString(WidgetKeys.SNAPSHOT, snapshot.toJson()).apply()
            MausamWidgetProvider.updateAll(applicationContext)
            Result.success()
        } catch (e: Exception) {
            // A malformed payload must not leave a half-written snapshot behind.
            Result.success()
        }
    }

    private fun fetch(url: String, token: String, lang: String): String? {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Accept-Language", lang)
                if (token.isNotBlank()) setRequestProperty("Authorization", "Bearer $token")
            }
            if (connection.responseCode !in 200..299) return null
            connection.inputStream.bufferedReader().use(BufferedReader::readText)
        } catch (e: Exception) {
            null
        } finally {
            connection?.disconnect()
        }
    }

    companion object {
        private const val CONNECT_TIMEOUT_MS = 8_000
        private const val READ_TIMEOUT_MS = 12_000
        private const val WORK_NAME = "mausam_widget_refresh"

        /** ~60 min; WorkManager's floor for periodic work is 15. */
        private const val INTERVAL_MINUTES = 60L

        fun enqueue(context: Context) {
            val request = PeriodicWorkRequestBuilder<MausamWidgetWorker>(
                INTERVAL_MINUTES,
                TimeUnit.MINUTES,
            )
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build(),
                )
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
