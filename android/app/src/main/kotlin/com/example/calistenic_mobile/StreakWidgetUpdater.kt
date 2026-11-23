package com.example.calistenic_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

/** Pinta el widget de racha y comparte el código entre el provider y la configuración. */
object StreakWidgetUpdater {

    fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences(WidgetPrefs.PREFS_NAME, Context.MODE_PRIVATE)

        // home_widget puede guardar la racha como Int; leer por el mapa evita el
        // ClassCastException de un getString() tipado (defecto corregido en v1.1.5).
        val streak = prefs.all[StreakKeys.STREAK_DAYS]?.toString()
            ?.takeIf { it.isNotBlank() } ?: "0"

        val configIntent = Intent(context, WidgetOpacityConfigActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(WidgetOpacityConfigActivity.EXTRA_FROM_WIDGET_TAP, true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val configPendingIntent = PendingIntent.getActivity(context, widgetId, configIntent, flags)

        val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
            setTextViewText(
                R.id.widget_streak,
                context.getString(R.string.widget_streak_value, streak),
            )
            // Opacidad configurada al añadir el widget (0-100 → 0f-1f).
            setFloat(R.id.widget_root, "setAlpha", WidgetPrefs.readOpacity(context, widgetId) / 100f)
            // Toque en el widget → pantalla de opacidad. El botón "Abrir" de esa
            // pantalla mantiene el acceso a la app que antes daba el toque directo.
            setOnClickPendingIntent(R.id.widget_root, configPendingIntent)
        }

        manager.updateAppWidget(widgetId, views)
    }

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, StreakWidgetProvider::class.java))
        ids.forEach { update(context, manager, it) }
    }
}
