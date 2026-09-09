package com.teammausam.mausam_app

/**
 * Keys in the shared storage the home-screen widget reads.
 *
 * Mirrors `HomeWidgetKeys` in `app/lib/data/widget/home_widget_bridge.dart` — the Dart side
 * writes them through the `home_widget` plugin, this side reads them back and the background
 * worker writes [SNAPSHOT] itself. Change both files together.
 */
object WidgetKeys {
    const val SNAPSHOT = "mausam_snapshot"
    const val BACKEND_URL = "mausam_backend_url"
    const val TOKEN = "mausam_token"
    const val LAT = "mausam_lat"
    const val LON = "mausam_lon"
    const val PERSONAS = "mausam_personas"
    const val LANG = "mausam_lang"
    const val UNITS = "mausam_units"

    /** docs/04_API_CONTRACT.md — every REST path hangs off `{BACKEND}/api/v1`. */
    const val API_PREFIX = "/api/v1"

    /** Deep links the widget's tap targets carry into MainActivity. */
    const val URI_SCHEME = "mausam"
    const val URI_HOME = "mausam://home"

    fun cardUri(type: String): String = "mausam://card/$type"
}
