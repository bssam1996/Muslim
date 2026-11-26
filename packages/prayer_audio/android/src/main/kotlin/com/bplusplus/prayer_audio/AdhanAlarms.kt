package com.bplusplus.prayer_audio

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.media.RingtoneManager
import org.json.JSONObject

internal object AdhanAlarms {
    fun store(context: Context) = context.getSharedPreferences("scheduled_adhan_v1", Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(AlarmManager::class.java)
    private fun operation(context: Context, id: Int) = PendingIntent.getBroadcast(
        context, id, Intent(context, AdhanAlarmReceiver::class.java).putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    @Synchronized fun schedule(context: Context, alarm: JSONObject) {
        val manager = manager(context)
        if (Build.VERSION.SDK_INT >= 31 && !manager.canScheduleExactAlarms()) {
            throw SecurityException("Exact alarm permission is required for prayer audio")
        }
        val sound = alarm.getString("sound")
        val available = if (sound == "system") RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) != null
            else context.resources.getIdentifier(sound, "raw", context.packageName) != 0
        require(available) { "Prayer sound is unavailable" }
        val id = alarm.getInt("id")
        check(store(context).edit().putString(id.toString(), alarm.toString()).commit())
        try {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, alarm.getLong("epoch"), operation(context, id))
        } catch (error: Exception) {
            store(context).edit().remove(id.toString()).commit()
            throw error
        }
    }

    @Synchronized fun cancel(context: Context, id: Int) {
        manager(context).cancel(operation(context, id))
        store(context).edit().remove(id.toString()).commit()
    }

    fun pendingIds(context: Context): List<Int> {
        if (Build.VERSION.SDK_INT >= 31 && !manager(context).canScheduleExactAlarms()) return emptyList()
        return store(context).all.mapNotNull { (key, value) ->
        try {
            val alarm = JSONObject(value as String)
            if (alarm.getLong("epoch") > System.currentTimeMillis()) key.toIntOrNull() else null
        } catch (_: Exception) { null }
        }
    }

    fun committed(context: Context, id: Int): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("flutter.prayerNotification", false)) return false
        return try {
            val alarms = JSONObject(prefs.getString("flutter.prayer_alarm_manifest_v2", "{}")!!)
                .getJSONArray("alarms")
            (0 until alarms.length()).any { alarms.getJSONObject(it).getInt("id") == id }
        } catch (_: Exception) { false }
    }

    fun restore(context: Context) {
        AdhanPlaybackService.restoreVolume(context)
        store(context).all.forEach { (key, value) ->
            try {
                val alarm = JSONObject(value as String)
                if (alarm.getLong("epoch") > System.currentTimeMillis() && committed(context, key.toInt())) {
                    schedule(context, alarm)
                } else cancel(context, key.toInt())
            } catch (_: Exception) {
                // Permission may have been revoked. The settings page reports it.
            }
        }
    }
}

class AdhanRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AdhanAlarms.restore(context)
    }
}

class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        val raw = AdhanAlarms.store(context).getString(id.toString(), null) ?: return
        AdhanAlarms.cancel(context, id)
        if (!AdhanAlarms.committed(context, id)) return
        val alarm = JSONObject(raw)
        if (System.currentTimeMillis() - alarm.getLong("epoch") > 5 * 60_000) return
        val service = Intent(context, AdhanPlaybackService::class.java).putExtra("alarm", raw)
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(service)
            else context.startService(service)
        } catch (_: Exception) {
            // Keep a visible alert if Android denies background audio.
            AdhanPlaybackService.showFallback(context, alarm)
        }
    }
}
