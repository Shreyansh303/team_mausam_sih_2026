package com.teammausam.mausam_app

import org.json.JSONObject

/**
 * The compact payload the widget draws, and the two ways it gets built.
 *
 * The schema is defined once in `app/lib/data/widget/widget_snapshot.dart`; this file is its
 * Kotlin twin, because the hourly background refresh runs with no Flutter engine attached and
 * has to produce byte-compatible JSON from a raw `/home?lite=1` response.
 *
 * Card content is never translated here — it arrives already localized from the backend
 * (docs/04 `lang`).
 */
data class WidgetSnapshot(
    val locationName: String,
    val updatedAt: String?,
    val lang: String,
    val units: String,
    val hero: Hero?,
    val pinned: Pinned?,
) {
    data class Hero(
        val tempC: Double?,
        val condition: String,
        val feelsLikeC: Double?,
        val tmaxC: Double?,
        val tminC: Double?,
    )

    data class Pinned(
        val type: String,
        val title: String,
        val insight: String,
        val severity: String,
        val colorHex: String,
        val estimated: Boolean,
    )

    val isEmpty: Boolean get() = hero == null && pinned == null

    companion object {
        const val SCHEMA_VERSION = 1

        private const val INFO_HEX = "#1565C0"
        private const val YELLOW_HEX = "#F5C518"
        private const val ORANGE_HEX = "#F28C28"
        private const val RED_HEX = "#D32F2F"

        val EMPTY = WidgetSnapshot("", null, "en", "metric", null, null)

        /** Reads what the app (or a previous worker run) stored. Never throws. */
        fun parse(raw: String?): WidgetSnapshot {
            if (raw.isNullOrBlank()) return EMPTY
            return try {
                val json = JSONObject(raw)
                if (json.optInt("v", SCHEMA_VERSION) > SCHEMA_VERSION) return EMPTY
                val heroJson = json.optJSONObject("hero")
                val pinnedJson = json.optJSONObject("pinned")
                WidgetSnapshot(
                    locationName = json.optString("location", ""),
                    updatedAt = json.optStringOrNull("updated_at"),
                    lang = json.optString("lang", "en"),
                    units = json.optString("units", "metric"),
                    hero = heroJson?.let {
                        Hero(
                            tempC = it.optDoubleOrNull("temp_c"),
                            condition = it.optString("condition", ""),
                            feelsLikeC = it.optDoubleOrNull("feels_like_c"),
                            tmaxC = it.optDoubleOrNull("tmax_c"),
                            tminC = it.optDoubleOrNull("tmin_c"),
                        )
                    },
                    pinned = pinnedJson?.let {
                        Pinned(
                            type = it.optString("type", ""),
                            title = it.optString("title", ""),
                            insight = it.optString("insight", ""),
                            severity = it.optString("severity", "info"),
                            colorHex = it.optString("color_hex", INFO_HEX),
                            estimated = it.optBoolean("estimated", false),
                        )
                    },
                )
            } catch (e: Exception) {
                EMPTY
            }
        }

        /**
         * Builds a snapshot from a `/home` (or `/home?lite=1`) response, with the same selection
         * rules as `WidgetSnapshot.fromHome` in Dart: the `hero` card, plus `pinned.first` when
         * anything is pinned and otherwise the top ranked card.
         */
        fun fromHome(home: JSONObject, lang: String, units: String): WidgetSnapshot {
            val pinnedArray = home.optJSONArray("pinned")
            val cards = home.optJSONArray("cards")
            val top = when {
                pinnedArray != null && pinnedArray.length() > 0 -> pinnedArray.optJSONObject(0)
                cards != null && cards.length() > 0 -> cards.optJSONObject(0)
                else -> null
            }
            val heroCard = home.optJSONObject("hero")
            val heroData = heroCard?.optJSONObject("data")
            return WidgetSnapshot(
                locationName = home.optJSONObject("location")?.optString("name", "") ?: "",
                updatedAt = newestFreshness(home),
                lang = lang,
                units = units,
                hero = heroCard?.let {
                    Hero(
                        tempC = heroData?.optDoubleOrNull("temp_c"),
                        condition = heroData?.optString("condition_text", "")?.ifEmpty {
                            it.optString("subtitle", "")
                        } ?: it.optString("subtitle", ""),
                        feelsLikeC = heroData?.optDoubleOrNull("feels_like_c"),
                        tmaxC = heroData?.optDoubleOrNull("tmax_c"),
                        tminC = heroData?.optDoubleOrNull("tmin_c"),
                    )
                },
                pinned = top?.let {
                    val headline = it.optJSONObject("insight")?.optString("headline", "").orEmpty()
                    Pinned(
                        type = it.optString("type", ""),
                        title = it.optString("title", ""),
                        insight = headline.ifEmpty { it.optString("subtitle", "") },
                        severity = it.optString("severity", "info"),
                        colorHex = colorFor(it),
                        estimated = it.optBoolean("estimated", false) ||
                            it.optString("source", "") == "estimated",
                    )
                },
            )
        }

        /** The newest of `freshness.*`, falling back to `generated_at` (mirrors the Dart model). */
        private fun newestFreshness(home: JSONObject): String? {
            val freshness = home.optJSONObject("freshness")
            var best: String? = null
            var bestAt: Long = Long.MIN_VALUE
            if (freshness != null) {
                for (key in freshness.keys()) {
                    val value = freshness.optStringOrNull(key) ?: continue
                    val at = WidgetTime.parseIso(value) ?: continue
                    if (at > bestAt) {
                        bestAt = at
                        best = value
                    }
                }
            }
            return best ?: home.optStringOrNull("generated_at")
        }

        /**
         * A `warnings` card takes the IMD colour of the warning it carries (docs/04
         * `Warning.color_hex`); anything else the severity band from docs/02 §Card anatomy.
         */
        fun colorFor(card: JSONObject): String {
            if (card.optString("type", "") == "warnings") {
                val first = card.optJSONObject("data")?.optJSONArray("warnings")?.optJSONObject(0)
                if (first != null) {
                    val hex = first.optStringOrNull("color_hex")
                    if (hex != null) return hex
                    when (first.optString("severity", "")) {
                        "red" -> return RED_HEX
                        "orange" -> return ORANGE_HEX
                        "yellow" -> return YELLOW_HEX
                    }
                }
            }
            return when (card.optString("severity", "")) {
                "severe" -> RED_HEX
                "warning" -> ORANGE_HEX
                "watch" -> YELLOW_HEX
                else -> INFO_HEX
            }
        }
    }

    /** The exact shape `WidgetSnapshot.fromJson` in Dart reads back. */
    fun toJson(): String {
        val json = JSONObject()
        json.put("v", SCHEMA_VERSION)
        json.put("location", locationName)
        json.put("updated_at", updatedAt ?: JSONObject.NULL)
        json.put("lang", lang)
        json.put("units", units)
        json.put(
            "hero",
            hero?.let {
                JSONObject()
                    .put("temp_c", it.tempC ?: JSONObject.NULL)
                    .put("condition", it.condition)
                    .put("feels_like_c", it.feelsLikeC ?: JSONObject.NULL)
                    .put("tmax_c", it.tmaxC ?: JSONObject.NULL)
                    .put("tmin_c", it.tminC ?: JSONObject.NULL)
            } ?: JSONObject.NULL,
        )
        json.put(
            "pinned",
            pinned?.let {
                JSONObject()
                    .put("type", it.type)
                    .put("title", it.title)
                    .put("insight", it.insight)
                    .put("severity", it.severity)
                    .put("color_hex", it.colorHex)
                    .put("estimated", it.estimated)
            } ?: JSONObject.NULL,
        )
        return json.toString()
    }
}

private fun JSONObject.optStringOrNull(key: String): String? {
    if (isNull(key)) return null
    val value = optString(key, "")
    return value.ifEmpty { null }
}

private fun JSONObject.optDoubleOrNull(key: String): Double? {
    if (isNull(key)) return null
    val value = optDouble(key, Double.NaN)
    return if (value.isNaN()) null else value
}
