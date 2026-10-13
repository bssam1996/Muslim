import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

const prayerAlarmLockName = 'muslim.prayer_alarms.v2';

/// Coordinates the foreground isolate and Flutter background engines in the
/// same app process. The owner publishes a port only for the transaction.
Future<T> withPrayerAlarmLock<T>(
  Future<T> Function() action, {
  String name = prayerAlarmLockName,
  Duration acknowledgementTimeout = const Duration(seconds: 10),
}) async {
  while (true) {
    final owner = ReceivePort();
    if (IsolateNameServer.registerPortWithName(owner.sendPort, name)) {
      final waiters = <SendPort>[];
      final subscription = owner.listen((message) {
        if (message is SendPort) {
          waiters.add(message);
          message.send('waiting');
        }
      });
      try {
        return await action();
      } finally {
        if (IsolateNameServer.lookupPortByName(name) == owner.sendPort) {
          IsolateNameServer.removePortNameMapping(name);
        }
        for (final waiter in waiters) {
          waiter.send('released');
        }
        await subscription.cancel();
        owner.close();
      }
    }
    owner.close();
    final holder = IsolateNameServer.lookupPortByName(name);
    if (holder == null) continue;
    final reply = ReceivePort();
    final acknowledged = Completer<void>();
    final released = Completer<void>();
    final subscription = reply.listen((message) {
      if (!acknowledged.isCompleted) acknowledged.complete();
      if (message == 'released' && !released.isCompleted) released.complete();
    });
    holder.send(reply.sendPort);
    try {
      await acknowledged.future.timeout(acknowledgementTimeout);
      // Check liveness again if the owning engine disappears after replying.
      await released.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      if (!acknowledged.isCompleted &&
          IsolateNameServer.lookupPortByName(name) == holder) {
        IsolateNameServer.removePortNameMapping(name);
      }
    } finally {
      await subscription.cancel();
      reply.close();
    }
  }
}
