# Web prayer notifications

Web Push is separate from Android's local notifications. Android's plugin,
alarms, channels, sounds and preference keys are unchanged. Web preferences use
`web_push_*_v1` keys and the browser holds a random subscription credential.

The server implementation lives in the existing **MuslimAPI** repository at
`D:\PythonApps\MuslimAPI`, in `utils/web_push.py`. See its `WEB_PUSH.md` for
database, VAPID keys and scheduler setup. Both repositories must be deployed.

## App behavior

- Settings and the navigation drawer open a web-specific notifications screen.
- Enabling asks browser permission from the user's tap, registers
  `prayer_push_worker.js`, and saves a subscription and prayer configuration.
- The server uses the same prayer engine, coordinates, method, school and tune
  values as the Flutter app. It stores each date separately in the location's
  IANA timezone, including daylight saving changes.
- A scheduler calls the authenticated backend endpoint every minute. The
  backend keeps three days of jobs and refreshes every six hours, independently
  of page visits. Failed schedule calculations retry after one minute.
- App startup, resume and saved calculation/location/language changes sync the
  subscription. Each prayer can be toggled separately. Disabling deletes the
  server subscription and jobs before unsubscribing in the browser.
- Next-reminder dates are displayed in the device's timezone and labelled as
  such. Delivery uses the chosen location's timezone.
- Full adhan playback is unavailable through web notification sounds. Internet
  access and browser/OS permission are required; delivery may be late. iOS/iPadOS
  16.4+ users must add the site to their Home Screen and open it as a web app.
- Location updates require opening the app and choosing the new location.

## Build and hosting

Production defaults to `https://muslim-api-mu.vercel.app/web-push`. Override it
for another deployment or local development:

```sh
flutter build web --release --dart-define=WEB_PUSH_API_URL=https://your-api.example/web-push
flutter run -d chrome --web-port=5000 --dart-define=WEB_PUSH_API_URL=http://127.0.0.1:8000/web-push
```

Add the app's exact origin (e.g. `http://localhost:5000` during development) to
the backend's `APP_ORIGINS`. Production app and API URLs must use HTTPS.

Subdirectory hosting works with `--base-href /muslim/`; worker, notification
icon and click URLs are resolved relative to that base path. The custom
`flutter_bootstrap.js` prevents Flutter's deprecated cache worker from replacing
the prayer push worker at the same scope. Serve worker JavaScript directly,
without SPA fallback rewrites or long-lived cache headers. Do not inject a
second service worker at the same scope through the hosting provider.

If the backend is not configured, the screen explains that web reminders are
unavailable. Browser permission alone never counts as an active subscription.

## Validation

```sh
flutter test test/web_push_service_test.dart test/web_prayer_notifications_test.dart
node --test test/web_push_browser_test.cjs
flutter test
flutter build web --release
```

Backend tests cover actual prayer-engine parity, daily time changes, DST,
disabled prayers, deletion, ownership/authentication, retries, expired reminders
and updates while the prayer calculation fails. Browser bridge tests cover
permission gesture order, worker scope, subscribe rollback, server deletion
before browser unsubscribe, permission revocation and notification clicks.

After deployment, test on real devices: enable and send a test, close the tab
and send another test, then check a scheduled prayer. Repeat on Android Chrome,
desktop and an iOS Home Screen web app. Actual push delivery needs real VAPID
keys, a configured database, and a live scheduler; mocks cannot prove delivery.
