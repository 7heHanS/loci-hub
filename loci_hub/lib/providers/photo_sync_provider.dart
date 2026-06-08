import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../core/utils/permission_handler.dart';
import '../../data/repositories/photo_repository.dart';
import 'journal_provider.dart';
import 'settings_provider.dart';

enum PhotoSyncStatus {
  idle,
  syncing,
  success,
  permissionDenied,
  error,
}

class PhotoSyncState {
  final PhotoSyncStatus status;
  final int syncedCount;
  final String? errorMessage;

  PhotoSyncState({
    required this.status,
    this.syncedCount = 0,
    this.errorMessage,
  });

  PhotoSyncState copyWith({
    PhotoSyncStatus? status,
    int? syncedCount,
    String? errorMessage,
  }) {
    return PhotoSyncState(
      status: status ?? this.status,
      syncedCount: syncedCount ?? this.syncedCount,
      errorMessage: errorMessage,
    );
  }
}

class PhotoSyncNotifier extends StateNotifier<PhotoSyncState> {
  final PhotoRepository _photoRepository;

  PhotoSyncNotifier(this._photoRepository)
      : super(PhotoSyncState(status: PhotoSyncStatus.idle));

  Future<void> syncPhotosForDate(String journalDateStr, WidgetRef ref) async {
    state = PhotoSyncState(status: PhotoSyncStatus.syncing);
    final tolerance = ref.read(matchingToleranceProvider);

    try {
      // 1. Verify photo access permission
      final access = await AppPermissionHandler.checkPhotoAccess();
      if (access == PhotoAccessLevel.denied) {
        final requested = await AppPermissionHandler.requestPhotoAccess();
        if (requested == PhotoAccessLevel.denied) {
          state = PhotoSyncState(status: PhotoSyncStatus.permissionDenied);
          return;
        }
      }

      // 2. Parse date
      final parts = journalDateStr.split('-');
      if (parts.length != 3) {
        state = PhotoSyncState(
          status: PhotoSyncStatus.error,
          errorMessage: '올바르지 않은 날짜 형식입니다.',
        );
        return;
      }

      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      final from = DateTime(year, month, day, 0, 0, 0);
      final to = DateTime(year, month, day, 23, 59, 59);

      // Save count before sync
      final beforePhotos = await _photoRepository.getPhotosForDate(journalDateStr);
      final beforeCount = beforePhotos.length;

      // 3. Trigger sync
      await _photoRepository.syncAndMatchPhotos(
        from: from,
        to: to,
        toleranceMinutes: tolerance,
      );

      // Fetch count after sync
      final afterPhotos = await _photoRepository.getPhotosForDate(journalDateStr);
      final afterCount = afterPhotos.length;
      final newPhotosCount = afterCount - beforeCount;

      state = PhotoSyncState(
        status: PhotoSyncStatus.success,
        syncedCount: newPhotosCount,
      );

      // Invalidate journalDataProvider and datesWithDataProvider to trigger UI updates
      ref.invalidate(journalDataProvider);
      ref.invalidate(datesWithDataProvider);

    } catch (e) {
      state = PhotoSyncState(
        status: PhotoSyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = PhotoSyncState(status: PhotoSyncStatus.idle);
  }
}

final photoSyncProvider =
    StateNotifierProvider<PhotoSyncNotifier, PhotoSyncState>((ref) {
  return PhotoSyncNotifier(getIt<PhotoRepository>());
});
