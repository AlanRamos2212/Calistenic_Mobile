package com.example.calistenic_mobile

import android.app.ActivityOptions
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

    private const val ACTION_OPEN_OPACITY =
        "com.example.calistenic_mobile.OPEN_WIDGET_OPACITY"

    fun update(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val prefs = context.getSharedPreferences(WidgetPrefs.PREFS_NAME, Context.MODE_PRIVATE)

        // home_widget puede guardar la racha como Int; leer por el mapa evita el
        // ClassCastException de un getString() tipado (defecto corregido en v1.1.5).
        val streak = prefs.all[StreakKeys.STREAK_DAYS]?.toString()
            ?.takeIf { it.isNotBlank() } ?: "0"

        val configPendingIntent = buildConfigPendingIntent(context, widgetId)

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
     * Desde API 34 (Android 14) el arranque de actividades en segundo plano está
     * restringido. Un toque al widget ocurre mientras la app está en background,
     * así que hay declarar explícitamente que el PendingIntent puede iniciar la
     * Activity (igual que hace `HomeWidgetLaunchIntent` en home_widget).
     * Sin esto, el launcher descarta el intent y abre la app por defecto.
     */
    private fun buildConfigPendingIntent(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, WidgetOpacityConfigActivity::class.java).apply {
            action = ACTION_OPEN_OPACITY
            `package` = context.packageName
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            putExtra(WidgetOpacityConfigActivity.EXTRA_FROM_WIDGET_TAP, true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return PendingIntent.getActivity(context, widgetId, intent, flags)
        }

        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
            )
        } else {
            options.pendingIntentBackgroundActivityStartMode =
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
        return PendingIntent.getActivity(context, widgetId, intent, flags, options.toBundle())
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
