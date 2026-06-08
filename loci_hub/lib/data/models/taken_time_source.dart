enum TakenTimeSource {
  exifOriginal,     // Weight: 1.0
  exifDigitized,    // Weight: 0.9
  imageDateTime,    // Weight: 0.8
  assetCreateTime;  // Weight: 0.5

  String toDbValue() {
    switch (this) {
      case TakenTimeSource.exifOriginal:
        return 'exif_original';
      case TakenTimeSource.exifDigitized:
        return 'exif_digitized';
      case TakenTimeSource.imageDateTime:
        return 'image_datetime';
      case TakenTimeSource.assetCreateTime:
        return 'asset_create_time';
    }
  }

  static TakenTimeSource fromDb(String? value) {
    switch (value) {
      case 'exif_original':
        return TakenTimeSource.exifOriginal;
      case 'exif_digitized':
        return TakenTimeSource.exifDigitized;
      case 'image_datetime':
        return TakenTimeSource.imageDateTime;
      case 'asset_create_time':
      default:
        return TakenTimeSource.assetCreateTime;
    }
  }
}
