package com.bplusplus.muslim

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

class HomeAppWidgetWide : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_app_widget_wide).apply {
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.layout_root, pendingIntent)

                val fajrText = widgetData.getString("fajr_text", "-")
                val fajrLabel = widgetData.getString("fajr_label", "Fajr")
                val sunriseText = widgetData.getString("sunrise_text", "-")
                val sunriseLabel = widgetData.getString("sunrise_label", "Sunrise")
                val dhuhrText = widgetData.getString("dhuhr_text", "-")
                val dhuhrLabel = widgetData.getString("dhuhr_label", "Dhuhr")
                val asrText = widgetData.getString("asr_text", "-")
                val asrLabel = widgetData.getString("asr_label", "Asr")
                val maghribText = widgetData.getString("maghrib_text", "-")
                val maghribLabel = widgetData.getString("maghrib_label", "Maghrib")
                val ishaText = widgetData.getString("isha_text", "-")
                val ishaLabel = widgetData.getString("isha_label", "Isha")
                val gregorianDate = widgetData.getString("gregorianDate_text", "")
                val hijriDate = widgetData.getString("hijriDate_text", "")
                val nextPrayerKey = widgetData.getString("next_prayer_key", "")
                    ?.trim()
                    ?.lowercase(Locale.US)
                    ?: ""

                setTextViewText(R.id.fajr_text, fajrText)
                setTextViewText(R.id.fajr_label, fajrLabel)
                setTextViewText(R.id.sunrise_text, sunriseText)
                setTextViewText(R.id.sunrise_label, sunriseLabel)
                setTextViewText(R.id.dhuhr_text, dhuhrText)
                setTextViewText(R.id.dhuhr_label, dhuhrLabel)
                setTextViewText(R.id.asr_text, asrText)
                setTextViewText(R.id.asr_label, asrLabel)
                setTextViewText(R.id.maghrib_text, maghribText)
                setTextViewText(R.id.maghrib_label, maghribLabel)
                setTextViewText(R.id.isha_text, ishaText)
                setTextViewText(R.id.isha_label, ishaLabel)
                setTextViewText(R.id.gregorianDate_text, gregorianDate)
                setTextViewText(R.id.hijriDate_text, hijriDate)

                applyWidePrayerState(nextPrayerKey, "fajr", R.id.fajr_card, R.id.fajr_label, R.id.fajr_text)
                applyWidePrayerState(nextPrayerKey, "sunrise", R.id.sunrise_card, R.id.sunrise_label, R.id.sunrise_text)
                applyWidePrayerState(nextPrayerKey, "dhuhr", R.id.dhuhr_card, R.id.dhuhr_label, R.id.dhuhr_text)
                applyWidePrayerState(nextPrayerKey, "asr", R.id.asr_card, R.id.asr_label, R.id.asr_text)
                applyWidePrayerState(nextPrayerKey, "maghrib", R.id.maghrib_card, R.id.maghrib_label, R.id.maghrib_text)
                applyWidePrayerState(nextPrayerKey, "isha", R.id.isha_card, R.id.isha_label, R.id.isha_text)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun RemoteViews.applyWidePrayerState(
        nextPrayerKey: String,
        prayerKey: String,
        cardViewId: Int,
        labelViewId: Int,
        timeViewId: Int
    ) {
        val highlighted = nextPrayerKey == prayerKey
        setInt(
            cardViewId,
            "setBackgroundResource",
            if (highlighted) R.drawable.home_widget_bg_prayer_card_highlight
            else R.drawable.home_widget_bg_prayer_card
        )
        setTextColor(
            labelViewId,
            if (highlighted) Color.parseColor("#FFF4D4") else Color.parseColor("#D8EDFF")
        )
        setTextColor(
            timeViewId,
            if (highlighted) Color.parseColor("#FFFFFF") else Color.parseColor("#E4F2FD")
        )
    }
}
