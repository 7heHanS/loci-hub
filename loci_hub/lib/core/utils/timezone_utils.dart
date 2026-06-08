class TimezoneUtils {
  /// Converts EXIF date-time string (typically "YYYY:MM:DD HH:MM:SS") 
  /// into UTC Epoch seconds. Interprets the EXIF date as local time.
  static int exifToUtcEpoch(String exifDateStr) {
    String normalized = exifDateStr.trim();
    if (normalized.length >= 19) {
      // Replace "YYYY:MM:DD" with "YYYY-MM-DD"
      final datePart = normalized.substring(0, 10).replaceAll(':', '-');
      final timePart = normalized.substring(11, 19);
      normalized = '$datePart $timePart';
    }
    
    final localDateTime = DateTime.parse(normalized);
    return localDateTime.millisecondsSinceEpoch ~/ 1000;
  }

  /// Converts UTC Epoch seconds to device local journal_date (YYYY-MM-DD).
  static String epochToJournalDate(int utcEpoch) {
    final localDateTime = DateTime.fromMillisecondsSinceEpoch(utcEpoch * 1000);
    final year = localDateTime.year.toString().padLeft(4, '0');
    final month = localDateTime.month.toString().padLeft(2, '0');
    final day = localDateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Returns today's journal_date (YYYY-MM-DD) based on local time.
  static String todayJournalDate() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
