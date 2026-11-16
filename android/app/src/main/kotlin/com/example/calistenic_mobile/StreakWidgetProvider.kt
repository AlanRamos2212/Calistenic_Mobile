package com.example.calistenic_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Android home screen widget showing the training streak
 * ("Racha: N días"). Tapping it opens the app (MainActivity).
 *
 * Data comes from Flutter through `home_widget` (StreakService.saveStreak →
 * HomeWidget.saveWidgetData), delivered here as the `widgetData`
 * SharedPreferences parameter. It intentionally does NOT read
 * flutter_secure_storage: that storage is encrypted with the app Keystore
 * and is not readable from the widget process.
 */
class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            // Read via the raw map: HomeWidget may store the streak as Int
            // (HomeWidget.saveWidgetData<int>) and a typed getString() would
            // throw ClassCastException, crashing the whole app process.
            val streak = widgetData.all[StreakKeys.STREAK_DAYS]?.toString()
                    ?.takeIf { it.isNotBlank() } ?: "0"

            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setTextViewText(
                    R.id.widget_streak,
                    context.getString(R.string.widget_streak_value, streak)
                )

                // Tap on the whole widget → open the app.
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, launchIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

object StreakKeys {
    const val STREAK_DAYS = "streak_days"
}
