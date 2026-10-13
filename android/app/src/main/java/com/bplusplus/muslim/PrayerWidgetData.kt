package com.bplusplus.muslim

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Calendar

internal fun prayerWidgetText(
    context: Context,
    data: SharedPreferences,
    key: String,
    fallback: String
): String? {
    val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    val today = formatter.format(Date())
    val nextDay = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
    val displayDate = data.getString("prayer_data_date", "")
    val tomorrowPreview = displayDate == formatter.format(nextDay.time) &&
        data.getString("widget_calculated_date", "") == today
    if (displayDate == today || tomorrowPreview) {
        if (key == "next_prayer_key") {
            val expires = (data.all["next_prayer_epoch_ms"] as? Number)?.toLong() ?: 0L
            if (expires <= System.currentTimeMillis()) return ""
        }
        return data.getString(key, fallback)
    }
    return when (key) {
        "next_prayer_key" -> ""
        "gregorianDate_text" -> data.getString("prayer_unavailable_text", null)
            ?: context.getString(R.string.prayer_times_unavailable)
        else -> "-"
    }
}
