import 'dart:async';

/// Persists snapshots in user-action order without poisoning later writes.
class SerialTaskQueue {
  Future<void>? _tail;

  Future<T> run<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    final previous = _tail;
    final finished = Completer<void>();
    _tail = finished.future;
    () async {
      if (previous != null) await previous;
      try {
        final value = await operation();
        if (identical(_tail, finished.future)) _tail = null;
        finished.complete();
        result.complete(value);
      } catch (error, stack) {
        if (identical(_tail, finished.future)) _tail = null;
        finished.complete();
        result.completeError(error, stack);
      }
    }();
    return result.future;
  }
}
