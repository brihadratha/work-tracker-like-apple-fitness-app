import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the app's JSON blob lives. Swappable so tests can run without a
/// platform channel.
abstract class Persistence {
  Future<Map<String, dynamic>?> read();
  Future<void> write(Map<String, dynamic> data);
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
