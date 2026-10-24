import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/UI/prayer_notifications/web_prayer_notifications.dart';
import 'package:muslim/utils/web_push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/daily_use_test_host.dart';

class FakePushService extends WebPushService {
  bool enabled = false;
  bool subscribed = false;
  bool rejectEnable = false;
  int testsSent = 0;
  @override
  Future<WebPushStatus> status() async => WebPushStatus(
    enabled: enabled,
    subscribed: subscribed,
    permission: subscribed && !enabled ? 'denied' : 'granted',
  );
  @override
  Future<void> enable(
    SharedPreferences prefs,
    Map<String, dynamic> config,
  ) async {
    if (rejectEnable) throw const WebPushException('permission_denied');
    enabled = true;
    subscribed = true;
  }

  @override
  Future<void> disable(SharedPreferences prefs) async {
    enabled = false;
    subscribed = false;
  }

  @override
  Future<void> update(
    SharedPreferences prefs, {
    String? language,
    List<String>? prayers,
  }) async {
    if (prayers != null) await prefs.setStringList(webPushPrayersKey, prayers);
  }

  @override
  Future<void> test() async {
    testsSent++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  initializeDailyUseTests();
  for (final locale in [const Locale('en', 'US'), const Locale('ar', 'EG')]) {
    testWidgets(
      'blocked browser can still delete its server subscription in $locale',
      (tester) async {
        final service = FakePushService()..subscribed = true;
        await pumpDailyPage(
          tester,
          WebPrayerNotificationsPage(
            prefs: SharedPreferences.getInstance(),
            service: service,
          ),
          locale: locale,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('web_push_remove')),
          200,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('web_push_remove')));
        await tester.pumpAndSettle();
        expect(service.subscribed, isFalse);
      },
    );
    testWidgets('web push enable, prayer selection and disable fit $locale', (
      tester,
    ) async {
      final service = FakePushService();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('prayerNotification', true);
      await pumpDailyPage(
        tester,
        WebPrayerNotificationsPage(
          prefs: Future.value(prefs),
          service: service,
        ),
        locale: locale,
      );
      await tester.tap(find.byKey(const ValueKey('web_push_enable')));
      await tester.pumpAndSettle();
      expect(service.enabled, isTrue);
      await tester.ensureVisible(find.byKey(const ValueKey('web_push_Fajr')));
      await tester.tap(find.byKey(const ValueKey('web_push_Fajr')));
      await tester.pumpAndSettle();
      expect(prefs.getStringList(webPushPrayersKey), isNot(contains('Fajr')));
      expect(prefs.getBool('prayerNotification'), isTrue);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('web_push_enable')),
        -200,
      );
      await tester.tap(find.byKey(const ValueKey('web_push_enable')));
      await tester.pumpAndSettle();
      expect(service.enabled, isFalse);
      expect(tester.takeException(), isNull);
    });
    testWidgets('denied permission keeps web push disabled in $locale', (
      tester,
    ) async {
      final service = FakePushService()..rejectEnable = true;
      await pumpDailyPage(
        tester,
        WebPrayerNotificationsPage(
          prefs: SharedPreferences.getInstance(),
          service: service,
        ),
        locale: locale,
      );
      await tester.tap(find.byKey(const ValueKey('web_push_enable')));
      await tester.pumpAndSettle();
      expect(service.enabled, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
