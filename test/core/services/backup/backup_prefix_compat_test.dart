import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/core/services/backup/data_sync.dart';

void main() {
  group('parseBackupTimestamp dual-prefix', () {
    test('parses legacy kelivo_backup filename', () {
      final t = DataSync.parseBackupTimestamp(
        'kelivo_backup_2025-01-19T12-34-56.123456.zip',
      );
      expect(t, isNotNull);
      expect(t!.year, 2025);
      expect(t.month, 1);
      expect(t.day, 19);
      expect(t.hour, 12);
      expect(t.minute, 34);
      expect(t.second, 56);
    });

    test('parses new sakrylle_backup filename', () {
      final t = DataSync.parseBackupTimestamp(
        'sakrylle_backup_2026-06-10T08-09-10.000111.zip',
      );
      expect(t, isNotNull);
      expect(t!.year, 2026);
      expect(t.month, 6);
      expect(t.day, 10);
      expect(t.hour, 8);
      expect(t.minute, 9);
      expect(t.second, 10);
    });

    test('returns null for unrelated filename', () {
      expect(DataSync.parseBackupTimestamp('random.zip'), isNull);
    });
  });
}
