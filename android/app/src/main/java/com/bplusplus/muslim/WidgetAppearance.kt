package com.bplusplus.muslim

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.os.Build
import android.widget.RemoteViews

/** Independent from the Flutter app theme; missing/unknown preferences follow the device. */
internal class WidgetAppearance(private val context: Context, data: SharedPreferences) {
    private val mode = data.getString("widget_theme_mode", "system")
        .takeIf { it == "light" || it == "dark" } ?: "system"
    private val dark = when (mode) {
        "light" -> false
        "dark" -> true
        else -> context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
            Configuration.UI_MODE_NIGHT_YES
    }

    fun background(views: RemoteViews, id: Int, light: Int, dark: Int, system: Int) {
        views.setInt(id, "setBackgroundResource", when (mode) {
            "light" -> light
            "dark" -> dark
            else -> system
        })
    }

    fun text(views: RemoteViews, id: Int, light: String, night: String) {
        val dayColor = Color.parseColor(light)
        val nightColor = Color.parseColor(night)
        if (mode == "system" && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Resolve at the launcher when applied, including after a system theme change.
            views.setColorInt(id, "setTextColor", dayColor, nightColor)
        } else {
            views.setTextColor(id, if (dark) nightColor else dayColor)
        }
    }

    fun classic(views: RemoteViews, next: String, wide: Boolean) {
        background(views, R.id.layout_root, R.drawable.home_widget_bg_root_light,
            R.drawable.home_widget_bg_root, R.drawable.home_widget_bg_root_system)
        background(views, R.id.widget_header, R.drawable.home_widget_bg_header_light,
            R.drawable.home_widget_bg_header, R.drawable.home_widget_bg_header_system)
        text(views, R.id.gregorianDate_text, "#284A6B", "#E5F2FF")
        text(views, R.id.hijriDate_text, "#284A6B", "#E5F2FF")
        val prayers = listOf(
            Triple("fajr", R.id.fajr_label, R.id.fajr_text),
            Triple("sunrise", R.id.sunrise_label, R.id.sunrise_text),
            Triple("dhuhr", R.id.dhuhr_label, R.id.dhuhr_text),
            Triple("asr", R.id.asr_label, R.id.asr_text),
            Triple("maghrib", R.id.maghrib_label, R.id.maghrib_text),
            Triple("isha", R.id.isha_label, R.id.isha_text)
        )
        val cards = listOf(R.id.fajr_card, R.id.sunrise_card, R.id.dhuhr_card,
            R.id.asr_card, R.id.maghrib_card, R.id.isha_card)
        prayers.forEachIndexed { index, (key, label, time) ->
            val highlighted = key == next
            if (wide) {
                if (highlighted) background(views, cards[index],
                    R.drawable.home_widget_bg_prayer_card_highlight_light,
                    R.drawable.home_widget_bg_prayer_card_highlight,
                    R.drawable.home_widget_bg_prayer_card_highlight_system)
                else background(views, cards[index], R.drawable.home_widget_bg_prayer_card_light,
                    R.drawable.home_widget_bg_prayer_card, R.drawable.home_widget_bg_prayer_card_system)
            } else if (highlighted) {
                background(views, label, R.drawable.home_widget_bg_prayer_label_highlight_light,
                    R.drawable.home_widget_bg_prayer_label_highlight,
                    R.drawable.home_widget_bg_prayer_label_highlight_system)
                background(views, time, R.drawable.home_widget_bg_prayer_time_highlight_light,
                    R.drawable.home_widget_bg_prayer_time_highlight,
                    R.drawable.home_widget_bg_prayer_time_highlight_system)
            } else {
                background(views, label, R.drawable.home_widget_bg_prayer_label_light,
                    R.drawable.home_widget_bg_prayer_label, R.drawable.home_widget_bg_prayer_label_system)
                background(views, time, R.drawable.home_widget_bg_prayer_time_light,
                    R.drawable.home_widget_bg_prayer_time, R.drawable.home_widget_bg_prayer_time_system)
            }
            text(views, label, if (highlighted) "#674400" else if (wide) "#365675" else "#244769",
                if (highlighted) "#FFF4D4" else if (wide) "#D8EDFF" else "#E8F6FF")
            text(views, time, if (highlighted) "#123957" else "#122F4B",
                if (highlighted) "#FFFFFF" else "#E4F2FD")
        }
    }
}
