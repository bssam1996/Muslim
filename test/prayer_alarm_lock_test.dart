import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/utils/prayer_alarm_lock.dart';

Future<void> _worker(List<dynamic> message) async {
  final events = message[0] as SendPort;
  final name = message[1] as String;
  final id = message[2] as int;
  try {
    await withPrayerAlarmLock(() async {
      events.send('enter:$id');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      events.send('leave:$id');
    }, name: name);
  } catch (error) {
    events.send('error:$error');
  }
  events.send('done');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alarm transactions in separate isolates cannot overlap', () async {
    const name = 'phase_b_alarm_lock_parallel';
    final events = ReceivePort();
    final completed = Completer<void>();
    final errors = <String>[];
    var active = 0;
    var maximum = 0;
    var done = 0;
    final subscription = events.listen((message) {
      final event = message as String;
      if (event.startsWith('enter:')) {
        active++;
        if (active > maximum) maximum = active;
      } else if (event.startsWith('leave:')) {
        active--;
      } else if (event.startsWith('error:')) {
        errors.add(event);
      } else if (event == 'done' && ++done == 3) {
        completed.complete();
      }
    });
    try {
      for (var id = 0; id < 3; id++) {
        await Isolate.spawn(_worker, [events.sendPort, name, id]);
      }
      await completed.future.timeout(const Duration(seconds: 5));
      expect(errors, isEmpty);
      expect(maximum, 1);
      expect(active, 0);
      expect(IsolateNameServer.lookupPortByName(name), isNull);
    } finally {
      await subscription.cancel();
      events.close();
      IsolateNameServer.removePortNameMapping(name);
    }
  });

  test('failed owner releases the alarm lock', () async {
    const name = 'phase_b_alarm_lock_failure';
    await expectLater(
      withPrayerAlarmLock(() async => throw StateError('failed'), name: name),
      throwsStateError,
    );
    expect(await withPrayerAlarmLock(() async => 42, name: name), 42);
    expect(IsolateNameServer.lookupPortByName(name), isNull);
  });

  test(
    'terminated engine port does not permanently block future transactions',
    () async {
      const name = 'phase_b_alarm_lock_terminated';
      final dead = ReceivePort();
      expect(
        IsolateNameServer.registerPortWithName(dead.sendPort, name),
        isTrue,
      );
      dead.close();
      expect(
        await withPrayerAlarmLock(
          () async => 42,
          name: name,
          acknowledgementTimeout: const Duration(milliseconds: 5),
        ),
        42,
      );
      expect(IsolateNameServer.lookupPortByName(name), isNull);
    },
  );
}
