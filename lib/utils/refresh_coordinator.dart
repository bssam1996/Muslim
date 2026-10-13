import 'dart:async';

/// Shares an in-flight refresh and backs off automatic retries after failures.
/// Explicit user retries always remain available.
class RefreshCoordinator {
  RefreshCoordinator({
    DateTime Function()? now,
    this.retryDelay = const Duration(minutes: 1),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration retryDelay;
  Future<bool>? _pending;
  DateTime? _retryAfter;

  bool get canRefreshAutomatically =>
      _pending == null &&
      (_retryAfter == null || !_now().isBefore(_retryAfter!));

  /// Settings may change while a request is running. Wait for that request,
  /// then read the latest configuration instead of sharing its old result.
  Future<bool> runAfterCurrent(Future<bool> Function() refresh) async {
    final pending = _pending;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        // An earlier failure must not prevent the new configuration loading.
      }
    }
    return run(refresh);
  }

  Future<bool> run(Future<bool> Function() refresh, {bool automatic = false}) {
    if (_pending != null) return _pending!;
    if (automatic && !canRefreshAutomatically) return Future.value(false);
    final completer = Completer<bool>();
    _pending = completer.future;
    () async {
      try {
        final success = await refresh();
        _retryAfter = success ? null : _now().add(retryDelay);
        completer.complete(success);
      } catch (error, stack) {
        _retryAfter = _now().add(retryDelay);
        completer.completeError(error, stack);
      } finally {
        _pending = null;
      }
    }();
    return completer.future;
  }
}
