# Prayer alerts

Each prayer retains its existing enable switch, vibration/Adhan mode, and sound
selection. New settings are opt-in and stored as JSON under
`prayerNotificationOptions<Prayer>`. The master switch and each prayer switch
control both its prayer-time alert and its reminder.

## Adhan audio

Prayer-time sounds use the local `packages/prayer_audio` Android plugin so they
have playback controls. Ordinary sounds use notification audio; silent/vibrate
override or custom volume uses alarm audio. Vibration-only alerts and ordinary
reminders use `flutter_local_notifications`. If exact alarm access is denied,
ordinary prayer sounds retain the inexact notification fallback. Independent
audio requires exact alarm access. The plugin registers with background Flutter
engines as well as the main engine.

The plugin schedules exact, one-time alarms and starts a media playback foreground
service at the prayer instant. This requires Android's Alarms & reminders access.
The service requests transient audio focus and registers a media session for
notification, lock screen, and volume controls. Tap the playback notification,
use its Stop action, or use Stop current audio on the prayer notifications page
to stop immediately. Volume down in the app stops the current sound; while the
app is in the background, the active media session and volume observer handle
volume changes. A transition into silent/vibrate also stops the current sound.
The initial ringer state is ignored by that listener, so force-play can still
start while the phone is already silent. Stopping only affects current playback;
it does not disable future alarms. Completion, focus loss, error, and a ten-minute
timeout also release playback. Stop releases audio synchronously rather than
waiting for Android to destroy the service.
Without the silent/vibrate option, the service respects the ringer mode even when
a custom volume is selected. It respects Do Not Disturb's alarm policy and blocked
notifications. No global ringer mode or DND policy is changed.

Custom volume temporarily sets the alarm stream volume, independently of the
notification stream. Android quantizes this to the device's available volume steps.
The old alarm volume is restored on exit unless the user changed it during
playback. Recovery information survives process death and is checked at the next
engine startup or reboot. Fixed-volume devices can ignore volume changes.
The existing sound preview uses media playback; it previews the recording rather
than validating Android's scheduled alarm routing or volume.

## Reminders

Each prayer can have one reminder, from 1 to 180 minutes before it. Presets are
5, 10, 15, 20, 30, 45, and 60 minutes. Two localized message presets and a custom
message (up to 300 characters) are available. Reminder sounds inherit the prayer's
silent/vibrate override and custom volume, even if the prayer-time alert itself is
vibration only. Reminders with either audio setting enabled use the same native
playback service, including when the sound is the default system notification
sound. Vibration-only reminders never produce sound. Without those audio settings,
reminders use notification volume and respect silent mode. They can use the system
sound, vibration only, or a bundled recording. The default is the system sound.

The alarm manifest includes a delivery version so installing the playback-control
update replaces previously scheduled notifications on the next reconciliation.

Both kinds of alert participate in the existing seven-calendar-day reconciliation
and rollback. Reminder IDs use separate banks from prayer alerts. Their original
prayer instants are persisted so a reminder crossing midnight survives a partial
cache refresh correctly. Turning a reminder or prayer off cancels its pending
alerts even if no prayer data can be loaded. Native audio checks the committed
manifest before starting, so uncommitted replacements do not play.

To add the dedicated reminder recording later:

1. Use a unique lowercase resource name, such as `prayer_prepare.mp3`.
2. Add it under `assets/reminders/` and register that directory in `pubspec.yaml`.
3. Copy the same file to `android/app/src/main/res/raw/` with the same name.
4. Add `@raw/<resource_name>` to `android/app/src/main/res/raw/keep.xml` so release
   resource shrinking preserves the dynamically selected recording.
5. Rebuild. The reminder sound list discovers MP3 files in that asset directory.
   Verify the sound is still present in the release APK's Android resource table,
   as well as in the Flutter asset bundle. A debug APK alone does not exercise
   resource shrinking.

## Validation

Run `flutter test test/prayer_alert_options_test.dart` and the existing prayer
reliability/UI tests. Native audio policy, recovery, and permission tests run with
`:prayer_audio:testDebugUnitTest` from `android/`.

On Windows, this machine needed these build-only overrides for cross-drive Kotlin
caches and Gradle memory (the project configuration is unchanged):

```powershell
.\gradlew.bat :app:assembleDebug '-Ptarget-platform=android-arm64' '-Pkotlin.incremental=false' '-Dorg.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G'
```

Before release, verify on a physical Android device: each ringer mode with override
on/off; notification volume at zero; different Adhan volume settings and restoration;
DND allowing/blocking alarms; Stop/completion/focus loss; playback while locked and
the app closed; reboot restoration; revoked exact/notification permissions; and
reminder timing/text/sound including a midnight boundary. Automated tests cannot
verify the device's audible output or manufacturer battery restrictions.
