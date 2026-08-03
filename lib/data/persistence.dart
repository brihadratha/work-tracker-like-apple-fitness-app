import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Where the app's JSON blob lives. Swappable so tests can run without a
/// platform channel.
abstract class Persistence {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
}

/// Mirrors a local store to a best-effort cloud store.
///
/// Local persistence remains authoritative when the cloud is unavailable. On
/// startup the newest timestamped copy wins and repairs the older store.
class MirroredPersistence implements Persistence {
  MirroredPersistence({
    required this.local,
    required this.cloud,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Persistence local;
  final Persistence cloud;
  final DateTime Function() _clock;

  @override
  Future<Map<String, dynamic>?> read() async {
    final results = await Future.wait([_safeRead(local), _safeRead(cloud)]);
    final localData = results[0];
    final cloudData = results[1];
    final newest = _newest(localData, cloudData);
    if (newest == null) return null;

    if (!identical(newest, localData)) await _safeWrite(local, newest);
    if (!identical(newest, cloudData)) await _safeWrite(cloud, newest);
    return newest;
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    final stamped = Map<String, dynamic>.from(data)
      ..['updatedAt'] = _clock().toUtc().toIso8601String();
    await local.write(stamped);
    await _safeWrite(cloud, stamped);
  }

  static Map<String, dynamic>? _newest(
    Map<String, dynamic>? local,
    Map<String, dynamic>? cloud,
  ) {
    if (local == null) return cloud;
    if (cloud == null) return local;
    final localTime = DateTime.tryParse(local['updatedAt'] as String? ?? '');
    final cloudTime = DateTime.tryParse(cloud['updatedAt'] as String? ?? '');
    if (localTime == null) return cloudTime == null ? local : cloud;
    if (cloudTime == null) return local;
    return cloudTime.isAfter(localTime) ? cloud : local;
  }

  static Future<Map<String, dynamic>?> _safeRead(Persistence store) async {
    try {
      return await store.read();
    } catch (error) {
      debugPrint('Cloud persistence read failed: $error');
      return null;
    }
  }

  static Future<void> _safeWrite(
    Persistence store,
    Map<String, dynamic> data,
  ) async {
    try {
      await store.write(data);
    } catch (error) {
      // Cloud availability must never prevent local work from being saved.
      debugPrint('Cloud persistence write failed: $error');
    }
  }
}

/// Reads and writes the app's JSON document through the native iCloud bridge.
class ICloudPersistence implements Persistence {
  ICloudPersistence({this.fileName = 'work_rings.json', MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('work_rings/icloud');

  final String fileName;
  final MethodChannel _channel;

  @override
  Future<Map<String, dynamic>?> read() async {
    final raw = await _channel.invokeMethod<String>('read', {
      'fileName': fileName,
    });
    if (raw == null || raw.trim().isEmpty) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> write(Map<String, dynamic> data) => _channel.invokeMethod<void>(
    'write',
    {'fileName': fileName, 'contents': jsonEncode(data)},
  );
}

/// Writes a single JSON document into the app's documents directory.
class FilePersistence implements Persistence {
  FilePersistence({this.fileName = 'work_rings.json'});

  final String fileName;
  File? _cachedFile;

  Future<File> _file() async {
    final cached = _cachedFile;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    return _cachedFile = File('${dir.path}/$fileName');
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // A corrupt or unreadable store shouldn't stop the app from opening;
      // the user starts fresh rather than seeing a crash.
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    final file = await _file();
    // Write to a sibling temp file first so a crash mid-write can't truncate
    // the real store.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(file.path);
  }
}

/// In-memory store used by tests and previews.
class InMemoryPersistence implements Persistence {
  InMemoryPersistence([this._data]);

  Map<String, dynamic>? _data;

  @override
  Future<Map<String, dynamic>?> read() async => _data;

  @override
  Future<void> write(Map<String, dynamic> data) async => _data = data;
}
