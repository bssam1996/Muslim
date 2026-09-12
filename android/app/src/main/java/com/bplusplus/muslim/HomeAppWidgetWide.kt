package com.bplusplus.muslim

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.util.TypedValue
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
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
            updateWidget(context, appWidgetManager, widgetId, widgetData,
                appWidgetManager.getAppWidgetOptions(widgetId))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId,
            HomeWidgetPlugin.getData(context), newOptions)
    }

    private fun updateWidget(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
        options: Bundle
    ) {
        // Modern launchers supply the actual sizes, including foldable configurations.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                ?.filter { it.width > 0f && it.height > 0f }
                ?.distinct()
                ?.take(16) // RemoteViews supports at most 16 size variants.
            if (!sizes.isNullOrEmpty()) {
                manager.updateAppWidget(widgetId, RemoteViews(sizes.associateWith {
                    createViews(context, data, it)
                }))
                return
            }
        }

        // Older launchers report portrait/landscape bounds instead of exact sizes.
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        val portrait = SizeF(minWidth.toFloat(), maxHeight.toFloat())
        val landscape = SizeF(maxWidth.toFloat(), minHeight.toFloat())
        manager.updateAppWidget(widgetId, RemoteViews(
            createViews(context, data, landscape),
            createViews(context, data, portrait)
        ))
    }

    private fun createViews(
        context: Context,
        widgetData: SharedPreferences,
        size: SizeF
    ): RemoteViews = RemoteViews(context.packageName, R.layout.home_app_widget_wide).apply {
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

        applyAdaptiveSizing(context, size,
            listOf(R.id.fajr_label to fajrLabel, R.id.sunrise_label to sunriseLabel,
                R.id.dhuhr_label to dhuhrLabel, R.id.asr_label to asrLabel,
                R.id.maghrib_label to maghribLabel, R.id.isha_label to ishaLabel),
            listOf(R.id.fajr_text to fajrText, R.id.sunrise_text to sunriseText,
                R.id.dhuhr_text to dhuhrText, R.id.asr_text to asrText,
                R.id.maghrib_text to maghribText, R.id.isha_text to ishaText),
            listOf(R.id.gregorianDate_text to gregorianDate,
                R.id.hijriDate_text to hijriDate))

        applyWidePrayerState(nextPrayerKey, "fajr", R.id.fajr_card, R.id.fajr_label, R.id.fajr_text)
        applyWidePrayerState(nextPrayerKey, "sunrise", R.id.sunrise_card, R.id.sunrise_label, R.id.sunrise_text)
        applyWidePrayerState(nextPrayerKey, "dhuhr", R.id.dhuhr_card, R.id.dhuhr_label, R.id.dhuhr_text)
        applyWidePrayerState(nextPrayerKey, "asr", R.id.asr_card, R.id.asr_label, R.id.asr_text)
        applyWidePrayerState(nextPrayerKey, "maghrib", R.id.maghrib_card, R.id.maghrib_label, R.id.maghrib_text)
        applyWidePrayerState(nextPrayerKey, "isha", R.id.isha_card, R.id.isha_label, R.id.isha_text)
    }

    private fun RemoteViews.applyAdaptiveSizing(
        context: Context,
        size: SizeF,
        labels: List<Pair<Int, String?>>,
        times: List<Pair<Int, String?>>,
        dates: List<Pair<Int, String?>>
    ) {
        // Missing launcher bounds retain the XML's compact text and spacing.
        if (size.width <= 0f || size.height <= 0f) return

        val metrics = context.resources.displayMetrics
        val density = metrics.density
        // Keep short widgets compact, then grow gradually up to twice the base font size.
        val scale = (1f + (size.height - 64f) / 120f).coerceIn(1f, 2f)
        val gap = ((scale - 1f) * 8f * density).toInt()
        // Match the XML's root padding, header weights, margins and card borders.
        val weightedWidth = (size.width - 16f - 6f).coerceAtLeast(0f)
        val prayerWidth = ((weightedWidth * 0.76f - 15f) / 6f - 4f) * density
        val dateWidth = (weightedWidth * 0.24f - 10f - 4f) * density

        fun fitText(group: List<Pair<Int, String?>>, baseSp: Float,
                    availableWidth: Float, bold: Boolean = false) {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                typeface = Typeface.create("sans-serif-medium",
                    if (bold) Typeface.BOLD else Typeface.NORMAL)
            }
            var textSp = baseSp * scale
            // Measure actual translated text, including the user's system font scaling.
            // Never shrink below the existing size when a narrow widget is already crowded.
            while (textSp > baseSp) {
                paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, textSp, metrics)
                val fitsWidth = group.all { paint.measureText(it.second.orEmpty()) <= availableWidth }
                val lineHeight = paint.fontMetrics.let { it.bottom - it.top }
                val fitsHeight = lineHeight <= ((size.height - 20f) * density - gap) / 2f
                if (fitsWidth && fitsHeight) break
                textSp = (textSp - 0.5f).coerceAtLeast(baseSp)
            }
            group.forEach { (id, _) -> setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, textSp) }
        }

        fitText(labels, 9f, prayerWidth)
        fitText(times, 10f, prayerWidth, bold = true)
        fitText(dates, 10f, dateWidth)
        times.forEach { (id, _) -> setViewPadding(id, 0, gap, 0, 0) }
        setViewPadding(R.id.hijriDate_text, 0, gap, 0, 0)
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
