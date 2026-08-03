import 'package:flutter_test/flutter_test.dart';
import 'package:work_rings/data/persistence.dart';

void main() {
  group('MirroredPersistence', () {
    final now = DateTime.utc(2026, 8, 3, 12);

    test('writes timestamped data locally and to iCloud', () async {
      final local = InMemoryPersistence();
      final cloud = InMemoryPersistence();
      final store = MirroredPersistence(
        local: local,
        cloud: cloud,
        clock: () => now,
      );

      await store.write({'sessions': const []});

      expect(await local.read(), await cloud.read());
      expect((await local.read())!['updatedAt'], now.toIso8601String());
    });

    test('newest copy wins and repairs the older store', () async {
      final local = InMemoryPersistence({
        'updatedAt': '2026-08-03T10:00:00.000Z',
        'source': 'local',
      });
      final cloud = InMemoryPersistence({
        'updatedAt': '2026-08-03T11:00:00.000Z',
        'source': 'cloud',
      });
      final store = MirroredPersistence(local: local, cloud: cloud);

      final result = await store.read();

      expect(result!['source'], 'cloud');
      expect((await local.read())!['source'], 'cloud');
    });

    test('cloud failure never prevents a local save', () async {
      final local = InMemoryPersistence();
      final store = MirroredPersistence(
        local: local,
        cloud: _FailingPersistence(),
        clock: () => now,
      );

      await store.write({'sessions': const []});

      expect((await local.read())!['sessions'], isEmpty);
    });

    test('existing local-only data is uploaded during load', () async {
      final local = InMemoryPersistence({'source': 'existing install'});
      final cloud = InMemoryPersistence();
      final store = MirroredPersistence(local: local, cloud: cloud);

      await store.read();

      expect((await cloud.read())!['source'], 'existing install');
    });
  });
}

class _FailingPersistence implements Persistence {
  @override
  Future<Map<String, dynamic>?> read() => Future.error(Exception('offline'));

  @override
  Future<void> write(Map<String, dynamic> data) =>
      Future.error(Exception('offline'));
}
