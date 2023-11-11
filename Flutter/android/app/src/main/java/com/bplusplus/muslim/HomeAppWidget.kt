package com.bplusplus.muslim

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Implementation of App Widget functionality.
 */

class HomeAppWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_app_widget).apply {

                // Open App on Widget Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context,
                        MainActivity::class.java)
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
//                val gregorianText = widgetData.getString("gregorianName_text", "")
                val gregorianDate = widgetData.getString("gregorianDate_text", "")
//                val hijriText = widgetData.getString("hijriName_text", "")
                val hijriDate = widgetData.getString("hijriDate_text", "")

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


                // Pending intent to update counter on button click
//                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context,
//                        Uri.parse("myAppWidget://updateprayers"))
//                setOnClickPendingIntent(R.id.bt_update, backgroundIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
