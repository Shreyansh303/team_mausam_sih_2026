package com.teammausam.mausam_app

import android.content.Context
import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/**
 * Timestamps for the widget.
 *
 * `java.time` needs API 26 (or core-library desugaring, which this app does not enable) and the
 * app ships to minSdk 24, so this uses [SimpleDateFormat] with the `X` pattern letters, which
 * are available from API 24.
 */
object WidgetTime {

    /** docs/06 §Home-screen widget — older than this and the widget asks to be opened. */
    const val STALE_AFTER_MS = 6L * 60L * 60L * 1000L

    private val PATTERNS = listOf(
        "yyyy-MM-dd'T'HH:mm:ssXXX",
        "yyyy-MM-dd'T'HH:mm:ss",
    )

    /** ISO-8601 with or without an offset (and with optional fractional seconds) → epoch ms. */
    fun parseIso(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        // Drop fractional seconds: the backend emits them on live payloads and never on fixtures.
        var text = value.trim().replace(Regex("\\.\\d+"), "")
        if (text.endsWith("Z")) text = text.dropLast(1) + "+00:00"
        for (pattern in PATTERNS) {
            try {
                val format = SimpleDateFormat(pattern, Locale.US)
                if (!pattern.contains("X")) format.timeZone = TimeZone.getDefault()
                return format.parse(text)?.time
            } catch (e: ParseException) {
                // try the next pattern
            } catch (e: IllegalArgumentException) {
                // malformed pattern for this platform — treat as unparseable
            }
        }
        return null
    }

    fun ageMillis(iso: String?, now: Long = System.currentTimeMillis()): Long? {
        val at = parseIso(iso) ?: return null
        return (now - at).coerceAtLeast(0L)
    }

    fun isStale(iso: String?, now: Long = System.currentTimeMillis()): Boolean {
        val age = ageMillis(iso, now) ?: return true
        return age > STALE_AFTER_MS
    }

    /** "just now" / "12 min ago" / "3 h ago" / "2 d ago", from the widget's own string resources. */
    fun ageLabel(context: Context, iso: String?, now: Long = System.currentTimeMillis()): String {
        val age = ageMillis(iso, now) ?: return ""
        val minutes = age / 60_000L
        return when {
            minutes < 1L -> context.getString(R.string.widget_age_now)
            minutes < 60L -> context.getString(R.string.widget_age_minutes, minutes.toInt())
            minutes < 48L * 60L ->
                context.getString(R.string.widget_age_hours, (minutes / 60L).toInt())
            else -> context.getString(R.string.widget_age_days, (minutes / (60L * 24L)).toInt())
        }
    }
}
