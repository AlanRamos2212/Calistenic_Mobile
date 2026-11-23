package com.example.calistenic_mobile

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.SeekBar
import android.widget.TextView
import android.widget.Toast

/**
 * Configuración de opacidad del widget de racha.
 *
 * Se abre de dos formas:
 *  1. Al añadir el widget (`android:configure` en streak_widget_info.xml).
 *  2. Al tocar el widget (PendingIntent desde StreakWidgetUpdater).
 *
 * En ambos casos recibe EXTRA_APPWIDGET_ID, guarda el valor en las mismas
 * preferencias de home_widget, repinta el widget y devuelve RESULT_OK.
 */
class WidgetOpacityConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    /** true cuando se abre tocando el widget; false cuando lo abre el picker al añadirlo. */
    private val isConfigureMode: Boolean
        get() = intent?.getBooleanExtra(EXTRA_FROM_WIDGET_TAP, false) != true

    companion object {
        const val EXTRA_FROM_WIDGET_TAP = "from_widget_tap"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Valor por defecto; finishWithoutChanges() lo cambia a RESULT_OK en el
        // flujo de añadido para que el launcher no descarte el widget.
        setResult(RESULT_CANCELED)
        setContentView(R.layout.widget_opacity_config)

        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        val valueLabel = findViewById<TextView>(R.id.opacity_value_label)
        val seekBar = findViewById<SeekBar>(R.id.opacity_seekbar)
        val savedOpacity = WidgetPrefs.readOpacity(this, appWidgetId)

        seekBar.progress = savedOpacity
        valueLabel.text = getString(R.string.widget_opacity_value, savedOpacity)

        seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                valueLabel.text = getString(R.string.widget_opacity_value, progress)
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
        })

        findViewById<Button>(R.id.opacity_save).setOnClickListener {
            WidgetPrefs.writeOpacity(this, appWidgetId, seekBar.progress)
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                StreakWidgetUpdater.updateAll(this)
            } else {
                StreakWidgetUpdater.update(this, AppWidgetManager.getInstance(this), appWidgetId)
            }
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
            )
            Toast.makeText(this, R.string.widget_opacity_saved, Toast.LENGTH_SHORT).show()
            finish()
        }

        findViewById<Button>(R.id.opacity_cancel).apply {
            // Al añadir: "cancelar" debe conservar el widget con opacidad 100%.
            // Al reajustar (toque): simplemente no cambia nada.
            text = getString(
                if (isConfigureMode) R.string.widget_opacity_use_default
                else R.string.widget_opacity_cancel,
            )
            setOnClickListener { finishWithoutChanges() }
        }

        findViewById<Button>(R.id.opacity_open_app).setOnClickListener {
            startActivity(Intent(this, MainActivity::class.java))
            finish()
        }
    }

    @Suppress("MissingSuperCall")
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        finishWithoutChanges()
    }

    /** Devuelve RESULT_OK en el flujo de añadido para que el launcher no descarte el widget. */
    private fun finishWithoutChanges() {
        if (isConfigureMode) {
            setResult(
                RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
            )
        }
        finish()
    }
}
