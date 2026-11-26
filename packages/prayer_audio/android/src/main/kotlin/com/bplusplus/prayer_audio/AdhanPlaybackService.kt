package com.bplusplus.prayer_audio

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.database.ContentObserver
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.MediaMetadata
import android.media.RingtoneManager
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import org.json.JSONObject
import kotlin.math.roundToInt

class AdhanPlaybackService : Service() {
    override fun onCreate() {
        super.onCreate()
        activeService = this
    }
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    internal var session: MediaSession? = null
        private set
    private var controlsRegistered = false
    private var lastRingerMode = AudioManager.RINGER_MODE_NORMAL
    private var lastVolumes = emptyMap<Int, Int>()
    private val handler = Handler(Looper.getMainLooper())
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) stopPlayback()
    }
    private val audio get() = getSystemService(AudioManager::class.java)
    private val ringerReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val mode = audio.ringerMode
            // Ignore the initial sticky broadcast; force-play may start while silent.
            if (mode != lastRingerMode && mode != AudioManager.RINGER_MODE_NORMAL) stopPlayback()
            lastRingerMode = mode
        }
    }
    private val volumeObserver = object : ContentObserver(handler) {
        override fun onChange(selfChange: Boolean) {
            val current = volumeSnapshot()
            if (running && current.any { (stream, value) -> value < (lastVolumes[stream] ?: value) }) {
                stopPlayback()
            }
            lastVolumes = current
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") {
            stopPlayback()
            return START_NOT_STICKY
        }
        val raw = intent?.getStringExtra("alarm") ?: run {
            stopPlayback()
            return START_NOT_STICKY
        }
        try {
            releaseAudio()
            val alarm = JSONObject(raw)
            val notification = notification(this, alarm, true)
            startForeground(PLAYBACK_ID, notification)
            val manager = getSystemService(NotificationManager::class.java)
            val channelBlocked = Build.VERSION.SDK_INT >= 26 &&
                manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE
            if (!manager.areNotificationsEnabled() || channelBlocked ||
                !shouldPlay(manager, audio, alarm.optBoolean("forceSound"))) {
                showFallback(this, alarm)
                stopPlayback()
                return START_NOT_STICKY
            }
            val independentAudio = alarm.optBoolean("forceSound") || !alarm.isNull("volume")
            val attributes = AudioAttributes.Builder().setUsage(if (independentAudio) AudioAttributes.USAGE_ALARM else AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
            val granted = if (Build.VERSION.SDK_INT >= 26) {
                focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener).build()
                audio.requestAudioFocus(focus!!)
            } else {
                @Suppress("DEPRECATION")
                audio.requestAudioFocus(focusListener, if (independentAudio) AudioManager.STREAM_ALARM else AudioManager.STREAM_NOTIFICATION, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            }
            if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                showFallback(this, alarm)
                stopPlayback()
                return START_NOT_STICKY
            }
            if (!alarm.isNull("volume") && !audio.isVolumeFixed) {
                val old = audio.getStreamVolume(AudioManager.STREAM_ALARM)
                val maximum = audio.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                val volume = alarm.getDouble("volume").coerceIn(0.0, 1.0)
                val applied = if (volume == 0.0) 0 else (volume * maximum).roundToInt().coerceAtLeast(1)
                getSharedPreferences(VOLUME_STORE, MODE_PRIVATE).edit()
                    .putInt("original", old).putInt("applied", applied).commit()
                audio.setStreamVolume(AudioManager.STREAM_ALARM, applied, 0)
            }
            startControls(alarm, attributes)
            manager.notify(PLAYBACK_ID, notification(this, alarm, true, session))
            val sound = alarm.getString("sound")
            val createdPlayer = MediaPlayer()
            player = createdPlayer
            createdPlayer.apply {
                setAudioAttributes(attributes)
                setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
                if (sound == "system") {
                    setDataSource(applicationContext, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                } else {
                    val resource = resources.getIdentifier(sound, "raw", packageName)
                    require(resource != 0)
                    resources.openRawResourceFd(resource).use { fd ->
                        setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                    }
                }
                setOnCompletionListener { stopPlayback() }
                setOnErrorListener { _, _, _ -> stopPlayback(); true }
                setOnPreparedListener { if (running && player === it) it.start() }
                prepareAsync()
            }
            // Bound playback even if an audio file or device fails to complete.
            handler.postDelayed({ stopPlayback() }, 10 * 60_000L)
        } catch (_: Exception) {
            try { showFallback(this, JSONObject(raw)) } catch (_: Exception) { }
            stopPlayback()
        }
        return START_NOT_STICKY
    }

    private fun volumeSnapshot() = listOf(AudioManager.STREAM_ALARM, AudioManager.STREAM_MUSIC,
        AudioManager.STREAM_RING, AudioManager.STREAM_NOTIFICATION).associateWith { audio.getStreamVolume(it) }

    internal fun startControls(alarm: JSONObject, attributes: AudioAttributes) {
        running = true
        session = MediaSession(this, "PrayerAudio").apply {
            setPlaybackToLocal(attributes)
            setCallback(object : MediaSession.Callback() {
                override fun onStop() = stopPlayback()
                override fun onPause() = stopPlayback()
            }, handler)
            setMetadata(MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, alarm.optString("title", alarm.optString("name")))
                .build())
            setPlaybackState(PlaybackState.Builder()
                .setActions(PlaybackState.ACTION_STOP or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_PLAY_PAUSE)
                .setState(PlaybackState.STATE_PLAYING, PlaybackState.PLAYBACK_POSITION_UNKNOWN, 1f).build())
            isActive = true
        }
        lastRingerMode = audio.ringerMode
        lastVolumes = volumeSnapshot()
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(ringerReceiver, IntentFilter(AudioManager.RINGER_MODE_CHANGED_ACTION), Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(ringerReceiver, IntentFilter(AudioManager.RINGER_MODE_CHANGED_ACTION))
        }
        contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, volumeObserver)
        controlsRegistered = true
    }

    internal fun stopPlayback() {
        // Release sound synchronously; service destruction can be deferred by Android.
        releaseAudio()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun releaseAudio() {
        running = false
        if (controlsRegistered) {
            unregisterReceiver(ringerReceiver)
            contentResolver.unregisterContentObserver(volumeObserver)
            controlsRegistered = false
        }
        session?.isActive = false
        session?.release()
        session = null
        handler.removeCallbacksAndMessages(null)
        player?.release()
        player = null
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
        else {
            @Suppress("DEPRECATION")
            audio.abandonAudioFocus(focusListener)
        }
        focus = null
        restoreVolume(this)
    }

    override fun onDestroy() {
        releaseAudio()
        if (activeService === this) activeService = null
        super.onDestroy()
    }

    companion object {
        internal var running = false
        private var activeService: AdhanPlaybackService? = null
        private const val CHANNEL = "muslim_adhan_playback_v1"
        private const val PLAYBACK_ID = 900001
        private const val VOLUME_STORE = "adhan_volume_restore_v1"

        /** Lets foreground volume/mute keys silence the current occurrence only. */
        fun stopIfPlaying(): Boolean {
            if (!running) return false
            activeService?.stopPlayback()
            return true
        }

        internal fun stopAllPrayerAudio(context: Context) {
            activeService?.stopPlayback()
            context.stopService(Intent(context, AdhanPlaybackService::class.java))
            // Also silence already-delivered notifications from the older sound path.
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.activeNotifications.filter {
                it.id in 0..5 || it.id in 1000000 until 3000000 || it.id in 11000000 until 13000000
            }.forEach { manager.cancel(it.tag, it.id) }
        }

        internal fun shouldPlay(manager: NotificationManager, audio: AudioManager, force: Boolean) =
            (force || audio.ringerMode == AudioManager.RINGER_MODE_NORMAL) && alarmsAllowed(manager)

        internal fun alarmsAllowed(manager: NotificationManager): Boolean = when (manager.currentInterruptionFilter) {
            NotificationManager.INTERRUPTION_FILTER_NONE -> false
            NotificationManager.INTERRUPTION_FILTER_PRIORITY -> {
                val policy = if (Build.VERSION.SDK_INT >= 30) manager.consolidatedNotificationPolicy
                    else manager.notificationPolicy
                policy.priorityCategories and NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS != 0
            }
            else -> true
        }

        internal fun restoreVolume(context: Context) {
            val prefs = context.getSharedPreferences(VOLUME_STORE, MODE_PRIVATE)
            if (!prefs.contains("original")) return
            val audio = context.getSystemService(AudioManager::class.java)
            try {
                // Preserve a volume change made by the user during playback.
                if (audio.getStreamVolume(AudioManager.STREAM_ALARM) == prefs.getInt("applied", -1)) {
                    audio.setStreamVolume(AudioManager.STREAM_ALARM, prefs.getInt("original", 0), 0)
                }
                prefs.edit().clear().commit()
            } catch (_: SecurityException) { /* Retry recovery after DND ends. */ }
        }

        internal fun showFallback(context: Context, alarm: JSONObject) {
            context.getSystemService(NotificationManager::class.java)
                .notify(alarm.getInt("id"), notification(context, alarm, false))
        }

        internal fun notification(context: Context, alarm: JSONObject, playing: Boolean, session: MediaSession? = null): Notification {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(
                    CHANNEL, alarm.optString("channelName", "Adhan playback"), NotificationManager.IMPORTANCE_HIGH
                ).apply { setSound(null, null); enableVibration(true) })
            }
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
                else Notification.Builder(context)
            builder.setSmallIcon(context.applicationInfo.icon)
                .setContentTitle(alarm.optString("title", alarm.getString("name")))
                .setContentText(alarm.optString("body"))
                .setSubText(if (playing) alarm.optString("stopHint", "Tap to stop") else null)
                .setStyle(Notification.BigTextStyle().bigText(alarm.optString("body")))
                .setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_ALARM)
                .setOngoing(playing).setAutoCancel(!playing)
            if (playing) {
                val stop = PendingIntent.getService(context, 0,
                    Intent(context, AdhanPlaybackService::class.java).setAction("stop"),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                builder.setContentIntent(stop).setDeleteIntent(stop)
                builder.addAction(Notification.Action.Builder(android.graphics.drawable.Icon.createWithResource(context, android.R.drawable.ic_media_pause),
                    alarm.optString("stopLabel", "Stop"), stop).build())
                if (session != null && !alarm.optBoolean("isReminder")) builder.setStyle(Notification.MediaStyle()
                    .setMediaSession(session.sessionToken).setShowActionsInCompactView(0))
            } else {
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launch != null) builder.setContentIntent(PendingIntent.getActivity(
                    context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            return builder.build()
        }
    }
}
