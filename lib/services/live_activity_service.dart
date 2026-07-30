import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Best-effort bridge to the iPhone Lock Screen and Dynamic Island timer.
class LiveActivityService {
  const LiveActivityService();

  static const _channel = MethodChannel('ai.atiq.workRings/live_activity');

  Future<void> start({
    required DateTime startedAt,
    required Duration elapsed,
    required String category,
    required int goalMinutes,
  }) => _invoke('start', {
    'startedAt': startedAt.millisecondsSinceEpoch,
    'elapsedSeconds': elapsed.inSeconds,
    'category': category,
    'goalMinutes': goalMinutes,
  });

  Future<void> update({
    required DateTime startedAt,
    required Duration elapsed,
    required String category,
    required int goalMinutes,
    required bool isPaused,
  }) => _invoke('update', {
    'startedAt': startedAt.millisecondsSinceEpoch,
    'elapsedSeconds': elapsed.inSeconds,
    'category': category,
    'goalMinutes': goalMinutes,
    'isPaused': isPaused,
  });

  Future<void> end({required Duration elapsed}) =>
      _invoke('end', {'elapsedSeconds': elapsed.inSeconds});

  Future<void> _invoke(String method, Map<String, Object> arguments) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Tracking stays authoritative if the native capability is unavailable.
    } on PlatformException {
      // Live Activities may be disabled or unsupported on this device.
    }
  }
}
