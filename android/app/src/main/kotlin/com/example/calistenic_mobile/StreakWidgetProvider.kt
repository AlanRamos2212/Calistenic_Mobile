package com.example.calistenic_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Android home screen widget showing the training streak ("Racha: N días").
 *
 * Data comes from Flutter through `home_widget` (StreakService.saveStreak →
 * HomeWidget.saveWidgetData), written to SharedPreferences["HomeWidgetPreferences"].
 * It intentionally does NOT read flutter_secure_storage: that storage is
 * encrypted with the app Keystore and is not readable from the widget process.
 *
 * Rendering (text, opacity and click intents) lives in StreakWidgetUpdater so
 * the configuration Activity can repaint the widget without duplicating logic.
 */
class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            StreakWidgetUpdater.update(context, appWidgetManager, widgetId)
        }
    }
}

object StreakKeys {
    const val STREAK_DAYS = "streak_days"
}
