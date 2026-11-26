package com.bplusplus.prayer_audio

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.AudioAttributes
import android.media.session.MediaSession
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowAlarmManager
import org.robolectric.shadows.ShadowMediaSession
import org.robolectric.shadows.ShadowMediaPlayer
import org.robolectric.shadow.api.Shadow
import org.robolectric.util.ReflectionHelpers

// Robolectric's MediaController does not dispatch transport calls to a session.
@Implements(MediaSession::class)
class MediaSessionControlsShadow : ShadowMediaSession() {
    var callback: MediaSession.Callback? = null
    @Implementation fun setCallback(value: MediaSession.Callback?, handler: Handler?) {
        callback = value
    }
}

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class AdhanAudioTest {
    private val context get() = RuntimeEnvironment.getApplication() as Context
    private val audio get() = context.getSystemService(AudioManager::class.java)
    private val notifications get() = context.getSystemService(NotificationManager::class.java)

    @Before fun reset() {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().clear().commit()
        context.getSharedPreferences("adhan_volume_restore_v1", Context.MODE_PRIVATE).edit().clear().commit()
        AdhanAlarms.store(context).edit().clear().commit()
        shadowOf(notifications).setNotificationPolicyAccessGranted(true)
        notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
    }

    @Test fun silentAndVibrateOnlyPlayWhenExplicitlyEnabled() {
        for (mode in listOf(AudioManager.RINGER_MODE_SILENT, AudioManager.RINGER_MODE_VIBRATE)) {
            audio.ringerMode = mode
            assertFalse(AdhanPlaybackService.shouldPlay(notifications, audio, false))
            assertTrue(AdhanPlaybackService.shouldPlay(notifications, audio, true))
            assertEquals(mode, audio.ringerMode)
        }
    }

    @Test fun forceDoesNotOverrideDoNotDisturbBlockingAlarms() {
        notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        assertFalse(AdhanPlaybackService.shouldPlay(notifications, audio, true))
        notifications.setNotificationPolicy(NotificationManager.Policy(0, 0, 0))
        shadowOf(notifications).setConsolidatedNotificationPolicy(NotificationManager.Policy(0, 0, 0))
        notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        assertFalse(AdhanPlaybackService.shouldPlay(notifications, audio, true))
        notifications.setNotificationPolicy(NotificationManager.Policy(NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS, 0, 0))
        shadowOf(notifications).setConsolidatedNotificationPolicy(NotificationManager.Policy(NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS, 0, 0))
        assertTrue(AdhanPlaybackService.shouldPlay(notifications, audio, true))
        notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
        assertTrue(AdhanPlaybackService.shouldPlay(notifications, audio, true))
    }

    @Test fun automaticDndRulesCanBlockAlarmsEvenWhenDefaultPolicyAllowsThem() {
        notifications.setNotificationPolicy(NotificationManager.Policy(NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS, 0, 0))
        shadowOf(notifications).setConsolidatedNotificationPolicy(NotificationManager.Policy(0, 0, 0))
        notifications.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        assertFalse(AdhanPlaybackService.shouldPlay(notifications, audio, true))
    }

    @Test fun restoresTemporaryAlarmVolumeWithoutChangingNotificationVolume() {
        audio.setStreamVolume(AudioManager.STREAM_NOTIFICATION, 2, 0)
        val notificationVolume = audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION)
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 6, 0)
        context.getSharedPreferences("adhan_volume_restore_v1", Context.MODE_PRIVATE).edit()
            .putInt("original", 2).putInt("applied", 6).commit()
        AdhanPlaybackService.restoreVolume(context)
        assertEquals(2, audio.getStreamVolume(AudioManager.STREAM_ALARM))
        assertEquals(notificationVolume, audio.getStreamVolume(AudioManager.STREAM_NOTIFICATION))
    }

    @Test fun preservesUserVolumeAdjustmentDuringPlayback() {
        audio.setStreamVolume(AudioManager.STREAM_ALARM, 4, 0)
        context.getSharedPreferences("adhan_volume_restore_v1", Context.MODE_PRIVATE).edit()
            .putInt("original", 2).putInt("applied", 6).commit()
        AdhanPlaybackService.restoreVolume(context)
        assertEquals(4, audio.getStreamVolume(AudioManager.STREAM_ALARM))
    }

    @Test fun stagedAlarmDoesNotStartPlaybackUntilManifestCommitsIt() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("flutter.prayerNotification", true).commit()
        assertFalse(AdhanAlarms.committed(context, 123))
        prefs.edit().putString("flutter.prayer_alarm_manifest_v2", """{"alarms":[{"id":123}]}""").commit()
        assertTrue(AdhanAlarms.committed(context, 123))
        prefs.edit().putBoolean("flutter.prayerNotification", false).commit()
        assertFalse(AdhanAlarms.committed(context, 123))
    }

    @Test fun staleAndUncommittedAlarmsAreRemovedOnRestore() {
        AdhanAlarms.store(context).edit()
            .putString("123", """{"id":123,"epoch":1}""")
            .putString("124", JSONObject().put("id", 124).put("epoch", System.currentTimeMillis() + 60_000).toString())
            .commit()
        AdhanRestoreReceiver().onReceive(context, Intent(Intent.ACTION_BOOT_COMPLETED))
        assertTrue(AdhanAlarms.store(context).all.isEmpty())
    }

    @Test fun missingSoundDoesNotLeaveAPendingAlarm() {
        try {
            AdhanAlarms.schedule(context, JSONObject().put("id", 123).put("sound", "missing_sound")
                .put("epoch", System.currentTimeMillis() + 60_000))
            fail("Expected unavailable sound to fail")
        } catch (_: IllegalArgumentException) { }
        assertTrue(AdhanAlarms.pendingIds(context).isEmpty())
        assertTrue(shadowOf(context.getSystemService(AlarmManager::class.java)).scheduledAlarms.isEmpty())
    }

    @Test fun systemReminderSoundCanBeScheduledAndCancelledWithNativeAudio() {
        AdhanAlarms.schedule(context, JSONObject().put("id", 123).put("sound", "system")
            .put("epoch", System.currentTimeMillis() + 60_000))
        assertEquals(listOf(123), AdhanAlarms.pendingIds(context))
        val manager = shadowOf(context.getSystemService(AlarmManager::class.java))
        assertEquals(1, manager.scheduledAlarms.size)
        AdhanAlarms.cancel(context, 123)
        assertTrue(AdhanAlarms.pendingIds(context).isEmpty())
        assertTrue(manager.scheduledAlarms.isEmpty())
    }

    @Test @Config(sdk = [35]) fun revokedExactAlarmPermissionDoesNotReportAudioAsScheduled() {
        ShadowAlarmManager.setCanScheduleExactAlarms(false)
        AdhanAlarms.store(context).edit().putString("123", JSONObject().put("id", 123)
            .put("epoch", System.currentTimeMillis() + 60_000).toString()).commit()
        assertTrue(AdhanAlarms.pendingIds(context).isEmpty())
        try {
            AdhanAlarms.schedule(context, JSONObject().put("id", 124).put("sound", "sound"))
            fail("Expected exact permission to be required")
        } catch (_: SecurityException) { }
    }

    private fun withControls(block: (AdhanPlaybackService, JSONObject) -> Unit) {
        val controller = Robolectric.buildService(AdhanPlaybackService::class.java).create()
        val service = controller.get()
        val alarm = JSONObject().put("id", 123).put("name", "Fajr").put("body", "Prepare")
            .put("title", "Reminder before Fajr").put("stopLabel", "Stop").put("forceSound", true)
        service.startControls(alarm, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build())
        try { block(service, alarm) } finally { controller.destroy() }
    }

    @Test fun notificationTapDismissAndStopActionSilenceImmediately() {
        withControls { service, alarm ->
            val player = MediaPlayer()
            ReflectionHelpers.setField(service, "player", player)
            val session = service.session!!
            val notice = AdhanPlaybackService.notification(service, alarm, true, session)
            assertEquals(1, notice.actions.size)
            assertEquals("stop", shadowOf(notice.contentIntent).savedIntent.action)
            assertEquals("stop", shadowOf(notice.deleteIntent).savedIntent.action)
            assertEquals(notice.contentIntent, notice.actions[0].actionIntent)
            assertEquals(notice.deleteIntent, notice.actions[0].actionIntent)
            assertEquals("Prepare", notice.extras.getCharSequence(android.app.Notification.EXTRA_TEXT).toString())
            audio.setStreamVolume(AudioManager.STREAM_ALARM, 6, 0)
            context.getSharedPreferences("adhan_volume_restore_v1", Context.MODE_PRIVATE).edit()
                .putInt("original", 2).putInt("applied", 6).commit()
            service.onStartCommand(shadowOf(notice.deleteIntent).savedIntent, 0, 1)
            assertFalse(AdhanPlaybackService.running)
            assertEquals(ShadowMediaPlayer.State.END, shadowOf(player).state)
            assertNull(service.session)
            assertEquals(2, audio.getStreamVolume(AudioManager.STREAM_ALARM))
        }
    }

    @Test @Config(shadows = [MediaSessionControlsShadow::class]) fun mediaPauseAndStopReleaseCurrentPlayback() {
        for (pause in listOf(true, false)) withControls { service, _ ->
            val callback = Shadow.extract<MediaSessionControlsShadow>(service.session).callback!!
            if (pause) callback.onPause() else callback.onStop()
            assertFalse(AdhanPlaybackService.running)
            assertNull(service.session)
        }
    }

    @Test fun volumeDownCanSilenceTheCurrentOccurrenceWithoutDisablingFutureAlarms() {
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, 5, 0)
        AdhanAlarms.store(context).edit().putString("future", "future-alarm").commit()
        withControls { _, _ ->
            audio.setStreamVolume(AudioManager.STREAM_MUSIC, 4, 0)
            context.contentResolver.notifyChange(Settings.System.CONTENT_URI, null)
            shadowOf(Looper.getMainLooper()).idle()
            assertFalse(AdhanPlaybackService.running)
            assertEquals("future-alarm", AdhanAlarms.store(context).getString("future", null))
        }
    }

    @Test fun forcedPlaybackCanStartWhileSilentButANewRingerChangeStopsIt() {
        audio.ringerMode = AudioManager.RINGER_MODE_SILENT
        withControls { _, _ ->
            context.sendBroadcast(Intent(AudioManager.RINGER_MODE_CHANGED_ACTION))
            shadowOf(Looper.getMainLooper()).idle()
            assertTrue(AdhanPlaybackService.running)
            audio.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            context.sendBroadcast(Intent(AudioManager.RINGER_MODE_CHANGED_ACTION))
            shadowOf(Looper.getMainLooper()).idle()
            assertFalse(AdhanPlaybackService.running)
        }
    }

    @Test fun stopFromTheAppPreservesScheduledAlarmsAndUnrelatedNotifications() {
        withControls { _, alarm ->
            notifications.notify(42, AdhanPlaybackService.notification(context, alarm, false))
            notifications.notify(1234560, AdhanPlaybackService.notification(context, alarm, false))
            AdhanAlarms.store(context).edit().putString("future", "future-alarm").commit()
            AdhanPlaybackService.stopAllPrayerAudio(context)
            assertFalse(AdhanPlaybackService.running)
            assertEquals(listOf(42), notifications.activeNotifications.map { it.id })
            assertEquals("future-alarm", AdhanAlarms.store(context).getString("future", null))
        }
    }

    @Test fun foregroundVolumeKeyCanStopOnceAndReleaseMediaSession() {
        withControls { service, _ ->
            assertTrue(AdhanPlaybackService.stopIfPlaying())
            assertFalse(AdhanPlaybackService.stopIfPlaying())
            assertNull(service.session)
        }
    }
}
