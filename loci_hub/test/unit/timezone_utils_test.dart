import 'package:flutter_test/flutter_test.dart';
import 'package:loci_hub/core/utils/timezone_utils.dart';

void main() {
  group('TimezoneUtils Tests', () {
    test('exifToUtcEpoch parses EXIF format to correct UTC epoch', () {
      // Input: local date representation in EXIF format
      const exifStr = '2026:06:08 10:30:15';
      
      // Parse it manually to check
      final expectedDateTime = DateTime(2026, 6, 8, 10, 30, 15);
      final expectedEpoch = expectedDateTime.millisecondsSinceEpoch ~/ 1000;
      
      final actualEpoch = TimezoneUtils.exifToUtcEpoch(exifStr);
      expect(actualEpoch, expectedEpoch);
    });

    test('epochToJournalDate parses UTC epoch to local YYYY-MM-DD date string', () {
      final now = DateTime.now();
      final epoch = now.millisecondsSinceEpoch ~/ 1000;
      
      // Expected journal date string in local timezone
      final year = now.year.toString().padLeft(4, '0');
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final expectedJournalDate = '$year-$month-$day';
      
      final actualJournalDate = TimezoneUtils.epochToJournalDate(epoch);
      expect(actualJournalDate, expectedJournalDate);
    });

    test('todayJournalDate matches current local date in YYYY-MM-DD format', () {
      final now = DateTime.now();
      final year = now.year.toString().padLeft(4, '0');
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final expectedJournalDate = '$year-$month-$day';
      
      expect(TimezoneUtils.todayJournalDate(), expectedJournalDate);
    });
  });
}
