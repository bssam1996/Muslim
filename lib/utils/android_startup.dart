import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import 'homewidget_utils.dart' as widgets;

class BackgroundSetup extends ChangeNotifier {
  BackgroundSetup(this._configure);
  final Future<void> Function() _configure;
  Future<void>? _pending;
  bool failed = false;
  bool complete = false;
  bool get running => _pending != null;

  Future<void> run() {
    if (_pending != null) return _pending!;
    if (complete) return Future.value();
    final completer = Completer<void>();
    _pending = completer.future;
    failed = false;
    notifyListeners();
    () async {
      try {
        await _configure();
        complete = true;
      } catch (error, stack) {
        failed = true;
        debugPrint('Background setup failed: $error\n$stack');
      } finally {
        _pending = null;
        notifyListeners();
        completer.complete();
      }
    }();
    return completer.future;
  }
}

final androidBackgroundSetup = BackgroundSetup(
  _configureAndroidBackgroundTasks,
);

Future<void> _configureAndroidBackgroundTasks() async {
  final now = DateTime.now();
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final manager = Workmanager();
  await manager.initialize(widgets.workManagerCallbackDispatcher);
  await manager.cancelByUniqueName('Muslim');
  await manager.registerPeriodicTask(
    widgets.dailyRefreshUniqueName,
    widgets.dailyRefreshTaskName,
    frequency: const Duration(days: 1),
    initialDelay: nextMidnight.difference(now),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
  await manager.registerPeriodicTask(
    widgets.frequentWidgetRefreshUniqueName,
    widgets.frequentWidgetRefreshTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
  if (!await AndroidAlarmManager.initialize()) {
    throw StateError('Alarm manager initialization failed');
  }
  // Home owns the startup prayer fetch. Do not fetch it a second time here.
  // A false result can mean exact-alarm permission is unavailable; the
  // registered periodic work remains the fallback in that case.
  await widgets.scheduleNextExactMidnightAlarm(source: 'AppStart');
  await widgets.bootstrapWidgetHighlightScheduling(source: 'AppStart');
}
