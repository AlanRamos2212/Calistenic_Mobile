package com.example.calistenic_mobile

import android.appwidget.AppWidgetManager
import android.content.Context

/**
 * Preferencias compartidas con el plugin `home_widget` 0.10.x.
 *
 * El plugin guarda los datos del widget en un SharedPreferences llamado
 * "HomeWidgetPreferences" (constante interna `HomeWidgetPlugin.PREFERENCES`).
 * Replicamos el nombre aquí para que la Activity de configuración y el
 * AppWidgetProvider lean exactamente el mismo archivo sin depender de símbolos
 * `internal` del plugin. La racha sigue siendo escrita por Flutter; la opacidad
 * la escribe esta Activity nativa.
 */
object WidgetPrefs {
    const val PREFS_NAME = "HomeWidgetPreferences"
    const val OPACITY_KEY = "widget_opacity"
    const val DEFAULT_OPACITY = 100

    /** Cada instancia del widget puede tener su propia opacidad. */
    private fun keyFor(widgetId: Int): String = when (widgetId) {
        AppWidgetManager.INVALID_APPWIDGET_ID -> OPACITY_KEY
        else -> "${OPACITY_KEY}_$widgetId"
    }

    fun readOpacity(context: Context, widgetId: Int): Int {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val perWidget = prefs.getInt(keyFor(widgetId), -1)
        return if (perWidget >= 0) {
            perWidget.coerceIn(0, 100)
        } else {
            prefs.getInt(OPACITY_KEY, DEFAULT_OPACITY).coerceIn(0, 100)
        }
    }

    fun writeOpacity(context: Context, widgetId: Int, opacity: Int) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            // commit() (no apply) para que el update inmediato del widget ya lea el valor.
            .putInt(keyFor(widgetId), opacity.coerceIn(0, 100))
            .commit()
    }
}
