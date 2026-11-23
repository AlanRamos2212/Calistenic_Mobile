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

    private const val COLOR_TITLE = 0xFFD9E4F2.toInt()
    private const val COLOR_STREAK = 0xFFFFFFFF.toInt()
    private const val COLOR_DAYS = 0xFFFFC36A.toInt()
    private const val COLOR_SUBTITLE = 0xFFB0BFD4.toInt()

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

        val opacity = WidgetPrefs.readOpacity(context, widgetId).coerceIn(0, 100)
        val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
            setTextViewText(
                R.id.widget_streak,
                context.getString(R.string.widget_streak_value, streak),
            )
            applyOpacity(this, opacity)

            // Fijamos el click en varias vistas: en algunos launchers el listener
            // del root no recibe los toques de los hijos. Todas las acciones
            // apuntan al mismo diálogo de opacidad.
            listOf(
                R.id.widget_root,
                R.id.widget_tap_area,
                R.id.widget_flame,
                R.id.widget_streak,
            ).forEach { setOnClickPendingIntent(it, configPendingIntent) }
        }

        manager.updateAppWidget(widgetId, views)
    }

    /**
     * `View.setAlpha(float)` sólo está marcado como @RemotableViewMethod desde
     * API 31 (Android 12). En API 24-30, usar `setFloat(..., "setAlpha", ...)`
     * lanza ActionException al aplicar el RemoteViews en el launcher y el widget
     * se queda con las vistas anteriores (por eso el toque abría la app).
     *
     * En API >= 31 aplicamos el alpha del root directamente. En versiones
     * anteriores replicamos el efecto con métodos remotables: alpha de la imagen
     * de fondo y de la flama, y alpha en el canal de los colores de texto.
     */
    private fun applyOpacity(views: RemoteViews, opacity: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setFloat(R.id.widget_root, "setAlpha", opacity / 100f)
            return
        }

        val level = (opacity * 255 / 100).coerceIn(0, 255)
        views.setInt(R.id.widget_background, "setImageAlpha", level)
        views.setInt(R.id.widget_flame, "setImageAlpha", level)
        views.setInt(R.id.widget_title_label, "setTextColor", withAlpha(COLOR_TITLE, level))
        views.setInt(R.id.widget_streak, "setTextColor", withAlpha(COLOR_STREAK, level))
        views.setInt(R.id.widget_days_label, "setTextColor", withAlpha(COLOR_DAYS, level))
        views.setInt(R.id.widget_subtitle_label, "setTextColor", withAlpha(COLOR_SUBTITLE, level))
    }

    /** Reemplaza el canal alpha de un color ARGB manteniendo RGB. */
    private fun withAlpha(argb: Int, alpha: Int): Int = (argb and 0x00FFFFFF) or (alpha shl 24)

    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, StreakWidgetProvider::class.java))
        ids.forEach { update(context, manager, it) }
    }
}
