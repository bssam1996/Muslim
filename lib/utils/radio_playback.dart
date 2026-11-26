import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum RadioPlaybackState { buffering, playing, paused, error }

abstract interface class RadioAudioBackend {
  Stream<PlayerState> get states;
  Future<void> play(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class RadioAudioPlayer implements RadioAudioBackend {
  final _player = AudioPlayer();
  @override
  Stream<PlayerState> get states => _player.onPlayerStateChanged;
  @override
  Future<void> play(String url) => _player.play(UrlSource(url));
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> resume() => _player.resume();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

/// One player per connection attempt prevents late timed-out streams from
/// taking over a retry. Closing the dialog stops and disposes its player.
class RadioPlayback extends ChangeNotifier {
  RadioPlayback({
    RadioAudioBackend Function()? createPlayer,
    this.connectionTimeout = const Duration(seconds: 15),
  }) : _createPlayer = createPlayer ?? RadioAudioPlayer.new;
  final RadioAudioBackend Function() _createPlayer;
  final Duration connectionTimeout;
  RadioAudioBackend? _player;
  StreamSubscription<PlayerState>? _subscription;
  int _generation = 0;
  bool _closed = false;
  RadioPlaybackState state = RadioPlaybackState.buffering;

  void _setState(RadioPlaybackState value) {
    if (_closed) return;
    state = value;
    notifyListeners();
  }

  Future<void> connect(String url) async {
    if (_closed) return;
    final generation = ++_generation;
    final old = _player;
    _player = null;
    await _subscription?.cancel();
    if (old != null) unawaited(_release(old));
    if (_closed || generation != _generation) return;
    _setState(RadioPlaybackState.buffering);
    try {
      final player = _createPlayer();
      _player = player;
      _subscription = player.states.listen((value) {
        if (_closed ||
            generation != _generation ||
            state == RadioPlaybackState.buffering) {
          return;
        }
        if (value == PlayerState.paused) _setState(RadioPlaybackState.paused);
        if (value == PlayerState.playing) _setState(RadioPlaybackState.playing);
        if (value == PlayerState.completed || value == PlayerState.stopped) {
          _fail(player, generation);
        }
      }, onError: (Object _) => _fail(player, generation));
      final connection = player.play(url);
      // If preparation completes after timeout/disposal, stop that old player.
      unawaited(
        connection.then((_) async {
          if (_closed || generation != _generation || _player != player) {
            try {
              await player.stop().timeout(const Duration(seconds: 2));
            } catch (_) {}
          }
        }, onError: (Object _) {}),
      );
      await connection.timeout(connectionTimeout);
      if (!_closed && generation == _generation && _player == player) {
        _setState(RadioPlaybackState.playing);
      }
    } catch (_) {
      if (!_closed && generation == _generation) {
        final player = _player;
        if (player != null) {
          _fail(player, generation);
        } else {
          _setState(RadioPlaybackState.error);
        }
      }
    }
  }

  void _fail(RadioAudioBackend player, int generation) {
    if (_closed || generation != _generation || _player != player) return;
    _player = null;
    unawaited(_subscription?.cancel());
    unawaited(_release(player));
    _setState(RadioPlaybackState.error);
  }

  Future<void> toggle() async {
    final player = _player;
    final generation = _generation;
    if (player == null || _closed || state == RadioPlaybackState.buffering) {
      return;
    }
    try {
      final pause = state == RadioPlaybackState.playing;
      await (pause ? player.pause() : player.resume()).timeout(
        connectionTimeout,
      );
      if (!_closed && generation == _generation && _player == player) {
        _setState(
          pause ? RadioPlaybackState.paused : RadioPlaybackState.playing,
        );
      }
    } catch (_) {
      _fail(player, generation);
    }
  }

  Future<void> _release(RadioAudioBackend player) async {
    try {
      await player.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await player.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    final player = _player;
    if (player != null) unawaited(_release(player));
    _player = null;
    super.dispose();
  }
}
