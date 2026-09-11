package com.teammausam.mausam_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import kotlin.math.roundToInt

/**
 * The Mausam home-screen widget (docs/06_MOBILE_SPEC.md §Home-screen widget).
 *
 * Draws the last `/home` snapshot the app (or the hourly background worker) stored: the hero
 * card — temperature, condition, location, freshness — plus the top pinned card with its
 * severity colour. It never fetches anything itself; RemoteViews cannot.
 *
 * Tapping the card opens the app at `mausam://home`; tapping the pinned row opens
 * `mausam://card/<type>`, which the app turns into that card's detail page.
 */
class MausamWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = WidgetSnapshot.parse(widgetData.getString(WidgetKeys.SNAPSHOT, null))
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                id,
                buildViews(context, snapshot, appWidgetManager.getAppWidgetOptions(id)),
            )
        }
        // Safety net: an install that already had the widget when this version landed never saw
        // onEnabled. KEEP means an existing schedule is left alone.
        MausamWidgetWorker.enqueue(context)
    }

    /** Re-render at the new size when the user resizes the widget. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val snapshot = WidgetSnapshot.parse(
            HomeWidgetPlugin.getData(context).getString(WidgetKeys.SNAPSHOT, null),
        )
        appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, snapshot, newOptions))
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        MausamWidgetWorker.enqueue(context)
    }

    override fun onDisabled(context: Context) {
        MausamWidgetWorker.cancel(context)
        super.onDisabled(context)
    }

    companion object {

        /** Below two cells of height there is only room for one row. */
        private const val TWO_CELL_MIN_HEIGHT_DP = 100

        /** Redraws every instance — used by the background worker after a successful fetch. */
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, MausamWidgetProvider::class.java),
            )
            if (ids.isEmpty()) return
            val snapshot = WidgetSnapshot.parse(
                HomeWidgetPlugin.getData(context).getString(WidgetKeys.SNAPSHOT, null),
            )
            for (id in ids) {
                manager.updateAppWidget(
                    id,
                    buildViews(context, snapshot, manager.getAppWidgetOptions(id)),
                )
            }
        }

        fun layoutFor(options: Bundle?): Int {
            val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
            return if (minHeight in 1 until TWO_CELL_MIN_HEIGHT_DP) {
                R.layout.mausam_widget_4x1
            } else {
                R.layout.mausam_widget_4x2
            }
        }

        fun buildViews(
            context: Context,
            snapshot: WidgetSnapshot,
            options: Bundle?,
        ): RemoteViews {
            val layoutId = layoutFor(options)
            val views = RemoteViews(context.packageName, layoutId)
            val hasTitleRow = layoutId == R.layout.mausam_widget_4x2

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse(WidgetKeys.URI_HOME),
                ),
            )

            if (snapshot.isEmpty) {
                // Nothing worth drawing — say so rather than showing an empty card.
                views.setViewVisibility(R.id.widget_content, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                return views
            }

            views.setViewVisibility(R.id.widget_content, View.VISIBLE)
            // The snapshot still renders when it is stale; the hint just says it is old.
            views.setViewVisibility(
                R.id.widget_empty,
                if (WidgetTime.isStale(snapshot.updatedAt)) View.VISIBLE else View.GONE,
            )

            val hero = snapshot.hero
            views.setTextViewText(R.id.widget_temp, formatTemp(hero?.tempC, snapshot.units))
            views.setTextViewText(R.id.widget_condition, hero?.condition.orEmpty())
            views.setTextViewText(R.id.widget_location, snapshot.locationName)
            views.setTextViewText(
                R.id.widget_age,
                WidgetTime.ageLabel(context, snapshot.updatedAt),
            )

            val pinned = snapshot.pinned
            if (pinned == null) {
                views.setViewVisibility(R.id.widget_pinned_row, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_pinned_row, View.VISIBLE)
                if (hasTitleRow) {
                    views.setTextViewText(R.id.widget_pinned_title, pinned.title)
                }
                views.setTextViewText(R.id.widget_pinned_insight, pinned.insight)
                views.setInt(R.id.widget_accent, "setColorFilter", parseColor(pinned.colorHex))
                // Honest data (docs/00 principle 6) — modelled data is labelled here too.
                views.setViewVisibility(
                    R.id.widget_estimated,
                    if (pinned.estimated) View.VISIBLE else View.GONE,
                )
                views.setOnClickPendingIntent(
                    R.id.widget_pinned_row,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse(WidgetKeys.cardUri(pinned.type)),
                    ),
                )
            }
            return views
        }

        /** `metric` → °C, `imperial` → °F. The app's own unit setting travels in the snapshot. */
        fun formatTemp(tempC: Double?, units: String): String {
            if (tempC == null) return "--°"
            val value = if (units == "imperial") tempC * 9.0 / 5.0 + 32.0 else tempC
            return "${value.roundToInt()}°"
        }

        fun parseColor(hex: String): Int = try {
            Color.parseColor(hex)
        } catch (e: IllegalArgumentException) {
            Color.parseColor("#1565C0")
        }
    }
}
