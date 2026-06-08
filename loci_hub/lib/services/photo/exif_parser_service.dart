import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../core/utils/timezone_utils.dart';
import '../../data/models/taken_time_source.dart';

class TakenTimeResult {
  final int timestamp; // UTC Epoch seconds
  final TakenTimeSource source;

  TakenTimeResult({
    required this.timestamp,
    required this.source,
  });
}

class ExifParserService {
  /// Extracts the creation time and source of a photo asset.
  /// Prioritizes EXIF DateTimeOriginal, falling back to other EXIF tags or the file creation date.
  Future<TakenTimeResult> extractTakenTime(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) {
      // Fallback 1: No file handle (Scoped Storage limitation / remote file)
      final fallbackTime = asset.createDateTime.millisecondsSinceEpoch ~/ 1000;
      return TakenTimeResult(
        timestamp: fallbackTime,
        source: TakenTimeSource.assetCreateTime,
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final Map<String, IfdTag> tags = await readExifFromBytes(bytes);

      String? dateStr;
      TakenTimeSource source = TakenTimeSource.assetCreateTime;

      // Check tags in order of preference
      if (tags.containsKey('EXIF DateTimeOriginal')) {
        dateStr = tags['EXIF DateTimeOriginal']?.toString();
        source = TakenTimeSource.exifOriginal;
      } else if (tags.containsKey('EXIF DateTimeDigitized')) {
        dateStr = tags['EXIF DateTimeDigitized']?.toString();
        source = TakenTimeSource.exifDigitized;
      } else if (tags.containsKey('Image DateTime')) {
        dateStr = tags['Image DateTime']?.toString();
        source = TakenTimeSource.imageDateTime;
      }

      if (dateStr != null && dateStr.trim().isNotEmpty) {
        try {
          final timestamp = TimezoneUtils.exifToUtcEpoch(dateStr);
          return TakenTimeResult(timestamp: timestamp, source: source);
        } catch (_) {
          // Fallback if the EXIF date string format is corrupted or unparsable
        }
      }
    } catch (_) {
      // Fallback if file read or EXIF parse throws an exception
    }

    // Fallback 2: Default to asset's local createDateTime metadata
    final fallbackTime = asset.createDateTime.millisecondsSinceEpoch ~/ 1000;
    return TakenTimeResult(
      timestamp: fallbackTime,
      source: TakenTimeSource.assetCreateTime,
    );
  }
}
