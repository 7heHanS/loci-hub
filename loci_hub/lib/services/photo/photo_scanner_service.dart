import 'package:photo_manager/photo_manager.dart';

class PhotoScannerService {
  /// Scans the local gallery for photo assets taken within the specified date range.
  Future<List<AssetEntity>> scanNewPhotos({
    required DateTime from,
    required DateTime to,
  }) async {
    // 1. Request/verify permission to access the gallery
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && permission != PermissionState.limited) {
      return []; // Access denied
    }

    // 2. Fetch path list containing only images filtered by date range
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        createTimeCond: DateTimeCond(
          min: from,
          max: to,
        ),
      ),
    );

    if (paths.isEmpty) {
      return [];
    }

    // 3. Get all assets from the first path (typically "Recent" or "All Images")
    final recentPath = paths.first;
    final assetCount = await recentPath.assetCountAsync;
    
    if (assetCount == 0) {
      return [];
    }

    final List<AssetEntity> assets = await recentPath.getAssetListRange(
      start: 0,
      end: assetCount,
    );

    return assets;
  }
}
