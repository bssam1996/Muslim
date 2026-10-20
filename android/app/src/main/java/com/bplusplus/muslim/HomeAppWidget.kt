package com.bplusplus.muslim

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

class HomeAppWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            appWidgetManager.updateAppWidget(widgetId, createViews(context, widgetData))
        }
    }

    internal fun createViews(context: Context, widgetData: SharedPreferences): RemoteViews =
        RemoteViews(context.packageName, R.layout.home_app_widget).apply {
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            setOnClickPendingIntent(R.id.layout_root, pendingIntent)

            val fajrText = prayerWidgetText(context, widgetData, "fajr_text", "-")
            val fajrLabel = widgetData.getString("fajr_label", "Fajr")
            val sunriseText = prayerWidgetText(context, widgetData, "sunrise_text", "-")
            val sunriseLabel = widgetData.getString("sunrise_label", "Sunrise")
            val dhuhrText = prayerWidgetText(context, widgetData, "dhuhr_text", "-")
            val dhuhrLabel = widgetData.getString("dhuhr_label", "Dhuhr")
            val asrText = prayerWidgetText(context, widgetData, "asr_text", "-")
            val asrLabel = widgetData.getString("asr_label", "Asr")
            val maghribText = prayerWidgetText(context, widgetData, "maghrib_text", "-")
            val maghribLabel = widgetData.getString("maghrib_label", "Maghrib")
            val ishaText = prayerWidgetText(context, widgetData, "isha_text", "-")
            val ishaLabel = widgetData.getString("isha_label", "Isha")
            val gregorianDate = prayerWidgetText(context, widgetData, "gregorianDate_text", "")
            val hijriDate = prayerWidgetText(context, widgetData, "hijriDate_text", "")
            val nextPrayerKey = prayerWidgetText(context, widgetData, "next_prayer_key", "")
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

            WidgetAppearance(context, widgetData).classic(this, nextPrayerKey, wide = false)
        }
}
