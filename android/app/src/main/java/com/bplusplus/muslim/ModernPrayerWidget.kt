package com.bplusplus.muslim

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.text.StaticLayout
import android.text.TextPaint
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.Bidi
import java.util.Locale

class HomeAppWidgetPortraitModern : ModernPrayerWidget(wide = false)
class HomeAppWidgetWideModern : ModernPrayerWidget(wide = true)

/** Shared data binding and sizing for the two optional modern designs. */
abstract class ModernPrayerWidget(private val wide: Boolean) : HomeWidgetProvider() {
    private data class Prayer(val key: String, val label: Int, val time: Int, val card: Int, val marker: Int)

    private val prayers = listOf(
        Prayer("fajr", R.id.fajr_label, R.id.fajr_text, R.id.fajr_card, R.id.modern_fajr_indicator),
        Prayer("sunrise", R.id.sunrise_label, R.id.sunrise_text, R.id.sunrise_card, R.id.modern_sunrise_indicator),
        Prayer("dhuhr", R.id.dhuhr_label, R.id.dhuhr_text, R.id.dhuhr_card, R.id.modern_dhuhr_indicator),
        Prayer("asr", R.id.asr_label, R.id.asr_text, R.id.asr_card, R.id.modern_asr_indicator),
        Prayer("maghrib", R.id.maghrib_label, R.id.maghrib_text, R.id.maghrib_card, R.id.modern_maghrib_indicator),
        Prayer("isha", R.id.isha_label, R.id.isha_text, R.id.isha_card, R.id.modern_isha_indicator)
    )

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager,
                          appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { id ->
            update(context, appWidgetManager, id, widgetData, appWidgetManager.getAppWidgetOptions(id))
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager,
                                           appWidgetId: Int, newOptions: Bundle) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        update(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context), newOptions)
    }

    private fun update(context: Context, manager: AppWidgetManager, id: Int,
                       data: SharedPreferences, options: Bundle) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            val sizes = options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
                ?.filter { it.width > 0 && it.height > 0 }?.distinct()?.take(16)
            if (!sizes.isNullOrEmpty()) {
                manager.updateAppWidget(id, RemoteViews(sizes.associateWith { createViews(context, data, it) }))
                return
            }
        }
        val portrait = SizeF(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).toFloat(),
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).toFloat())
        val landscape = SizeF(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).toFloat(),
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).toFloat())
        manager.updateAppWidget(id, RemoteViews(createViews(context, data, landscape),
            createViews(context, data, portrait)))
    }

    internal fun createViews(context: Context, data: SharedPreferences, size: SizeF): RemoteViews {
        val width = size.width.takeIf { it > 0 } ?: if (wide) 320f else 180f
        val height = size.height.takeIf { it > 0 } ?: if (wide) 60f else 240f
        val metrics = context.resources.displayMetrics
        fun px(dp: Float) = (dp * metrics.density).toInt()
        val labels = prayers.map { it.label to (data.getString("${it.key}_label", null)
            ?: context.getString(when (it.key) {
                "fajr" -> R.string.fajr_label
                "sunrise" -> R.string.sunrise_label
                "dhuhr" -> R.string.dhuhr_label
                "asr" -> R.string.asr_label
                "maghrib" -> R.string.maghrib_label
                else -> R.string.isha_label
            })) }
        val times = prayers.map { it.time to (data.getString("${it.key}_text", "—") ?: "—") }
        val hijri = data.getString("hijriDate_text", "—") ?: "—"
        val gregorian = data.getString("gregorianDate_text", "—") ?: "—"
        val nextKey = data.getString("next_prayer_key", "")?.trim()?.lowercase(Locale.ROOT)
        val nextIndex = prayers.indexOfFirst { it.key == nextKey }
        val rtl = !Bidi(labels.first().second, Bidi.DIRECTION_DEFAULT_LEFT_TO_RIGHT).baseIsLeftToRight()
        val compactWide = wide && height < 100f
        val portraitScale = ((height - 110f) / 70f).coerceIn(0f, 1f)
        val compactPortrait = !wide && (height < 150f || width < 150f)
        val horizontalPadding = if (wide) 8f else
            6f + 4f * ((width - 110f) / 70f).coerceIn(0f, 1f)
        val verticalPadding = if (wide) { if (compactWide) 1f else 10f }
            else 4f + 6f * portraitScale
        val rowPadding = 4f + 4f * portraitScale
        val innerWidth = width - horizontalPadding * 2
        val views = RemoteViews(context.packageName, if (wide) R.layout.home_app_widget_modern_wide
            else R.layout.home_app_widget_modern_portrait)

        // Keep a consistent size within each group, fitted to the translated text and actual space.
        fun fit(group: List<Pair<Int, String>>, desiredSp: Float, widthDp: Float,
                heightDp: Float): Float {
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                typeface = Typeface.create("sans-serif", Typeface.BOLD)
            }
            // A two-row widget must also fit when the system font scale is enlarged.
            val minSp = if (!wide && height < 150f) 4f else 8f
            var sp = desiredSp.coerceAtLeast(minSp)
            val availableWidth = px(widthDp.coerceAtLeast(1f)).coerceAtLeast(1)
            fun lineHeight(text: String): Int {
                val builder = StaticLayout.Builder.obtain(text, 0, text.length, paint, availableWidth)
                    .setIncludePad(false).setMaxLines(1)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) builder.setUseLineSpacingFromFallbacks(true)
                return builder.build().height
            }
            while (sp > minSp) {
                paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, metrics)
                val fits = group.all { (_, text) ->
                    paint.measureText(text) <= availableWidth && lineHeight(text) <= px(heightDp.coerceAtLeast(0f))
                }
                if (fits) break
                sp = (sp - 0.5f).coerceAtLeast(minSp)
            }
            group.forEach { (id, text) ->
                views.setTextViewText(id, text)
                views.setTextViewTextSize(id, TypedValue.COMPLEX_UNIT_SP, sp)
            }
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, metrics)
            return group.maxOf { lineHeight(it.second) } / metrics.density
        }

        views.setInt(R.id.layout_root, "setLayoutDirection", if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
        views.setViewPadding(R.id.layout_root, px(horizontalPadding), px(verticalPadding),
            px(horizontalPadding), px(verticalPadding))
        views.setOnClickPendingIntent(R.id.layout_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
        val dateHeight = fit(listOf(R.id.modern_hijri_top to hijri, R.id.modern_gregorian_top to gregorian),
            if (compactWide) 14f else 16f, innerWidth / 2 - if (wide) 12f else 4f,
            if (wide) { if (compactWide) 16f else 24f } else 14f + 10f * portraitScale)
        val dateGap = if (wide) { if (compactWide) 0f else 4f }
            else (14f + 14f * portraitScale - dateHeight).coerceAtLeast(0f)
        // Inset wide dates away from the corners; compact portrait dates use the full width.
        views.setViewPadding(R.id.modern_dates, if (wide) px(8f) else 0, 0,
            if (wide) px(8f) else 0, px(dateGap))
        val bodyHeight = height - verticalPadding * 2 - dateHeight - dateGap

        if (wide) {
            // Dates share the top line, leaving the full width for six larger prayer columns.
            val columnWidth = innerWidth / 6f
            val scale = (bodyHeight / 60f).coerceIn(1f, 1.8f)
            val textHeight = bodyHeight - if (compactWide) 1f else 7f
            val labelHeight = fit(labels, 12f * scale, columnWidth - 4, textHeight * 0.43f)
            fit(times, 16f * scale, columnWidth - 4, textHeight - labelHeight)
        } else {
            val rowHeight = bodyHeight / 6
            val columnWidth = (innerWidth - rowPadding * 2 - if (compactPortrait) 0f else 10f) / 2
            val lineHeight = rowHeight - (1f + 3f * portraitScale)
            fit(labels, (rowHeight * 0.43f).coerceIn(11f, 18f), columnWidth - 2, lineHeight)
            fit(times, (rowHeight * 0.5f).coerceIn(14f, 22f), columnWidth - 2, lineHeight)
            prayers.forEach { views.setViewPadding(it.card, px(rowPadding), 0, px(rowPadding), 0) }
        }
        prayers.forEachIndexed { index, prayer ->
            val highlighted = index == nextIndex
            views.setInt(prayer.card, "setBackgroundResource",
                if (highlighted) R.drawable.widget_modern_highlight else android.R.color.transparent)
            views.setViewVisibility(prayer.marker, if (compactWide || compactPortrait) View.GONE
                else if (highlighted) View.VISIBLE else View.INVISIBLE)
            views.setTextColor(prayer.label, context.getColor(if (highlighted) R.color.widget_modern_gold else R.color.widget_modern_muted))
            views.setTextColor(prayer.time, context.getColor(if (highlighted) R.color.widget_modern_gold else R.color.widget_modern_text))
        }
        return views
    }
}
