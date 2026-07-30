import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LiveActivityActionType { pause, resume, stop }

@immutable
class LiveActivityAction {
  const LiveActivityAction({
    required this.type,
    required this.sessionId,
    required this.elapsed,
    required this.occurredAt,
  });

  final LiveActivityActionType type;
  final String sessionId;
  final Duration elapsed;
  final DateTime occurredAt;
}

/// Best-effort bridge to the iPhone Lock Screen and Dynamic Island timer.
class LiveActivityService {
  const LiveActivityService();

  static const _channel = MethodChannel('ai.atiq.workRings/live_activity');

  Future<void> start({
    required String sessionId,
    required DateTime startedAt,
    required Duration elapsed,
    required String category,
    required int goalMinutes,
  }) => _invoke('start', {
    'sessionId': sessionId,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'elapsedSeconds': elapsed.inSeconds,
    'category': category,
    'goalMinutes': goalMinutes,
  });

  Future<void> update({
    required String sessionId,
    required DateTime startedAt,
    required Duration elapsed,
    required String category,
    required int goalMinutes,
    required bool isPaused,
  }) => _invoke('update', {
    'sessionId': sessionId,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'elapsedSeconds': elapsed.inSeconds,
    'category': category,
    'goalMinutes': goalMinutes,
    'isPaused': isPaused,
  });

  /// Makes ActivityKit exactly mirror the app's current session, recreating a
  /// missing activity and removing any activity left over from an older one.
  Future<void> synchronize({
    required String sessionId,
    required DateTime startedAt,
    required Duration elapsed,
    required String category,
    required int goalMinutes,
    required bool isPaused,
  }) => _invoke('synchronize', {
    'sessionId': sessionId,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'elapsedSeconds': elapsed.inSeconds,
    'category': category,
    'goalMinutes': goalMinutes,
    'isPaused': isPaused,
  });

  Future<Duration?> end({required Duration elapsed, String? sessionId}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      final seconds = await _channel.invokeMethod<num>('end', {
        'elapsedSeconds': elapsed.inSeconds,
        'sessionId': ?sessionId,
      });
      return seconds == null ? null : Duration(seconds: seconds.round());
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Returns the latest action performed in the Live Activity exactly once.
  Future<LiveActivityAction?> takePendingAction() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'takePendingAction',
      );
      if (raw == null) return null;
      final type = switch (raw['type']) {
        'pause' => LiveActivityActionType.pause,
        'resume' => LiveActivityActionType.resume,
        'stop' => LiveActivityActionType.stop,
        _ => null,
      };
      final sessionId = raw['sessionId'] as String?;
      final seconds = raw['elapsedSeconds'] as num?;
      final occurredAt = raw['occurredAt'] as num?;
      if (type == null ||
          sessionId == null ||
          seconds == null ||
          occurredAt == null) {
        return null;
      }
      return LiveActivityAction(
        type: type,
        sessionId: sessionId,
        elapsed: Duration(seconds: seconds.round()),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAt.round()),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

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
