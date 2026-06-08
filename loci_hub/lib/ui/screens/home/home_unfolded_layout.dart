import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../../providers/date_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../providers/photo_sync_provider.dart';
import '../../../providers/tracking_provider.dart';
import '../../widgets/calendar/calendar_selector.dart';
import '../../widgets/common/tracking_status_indicator.dart';
import '../../widgets/map/loci_map_view.dart';
import '../../widgets/timeline/timeline_feed.dart';

class HomeUnfoldedLayout extends ConsumerWidget {
  const HomeUnfoldedLayout({super.key});

  void _navigateDay(WidgetRef ref, int days) {
    final currentDateStr = ref.read(selectedDateProvider);
    try {
      final parts = currentDateStr.split('-');
      if (parts.length == 3) {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final newDate = date.add(Duration(days: days));
        final formatted = TimezoneUtils.epochToJournalDate(
          newDate.millisecondsSinceEpoch ~/ 1000,
        );
        ref.read(selectedDateProvider.notifier).state = formatted;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final journalDataAsync = ref.watch(journalDataProvider);
    final syncState = ref.watch(photoSyncProvider);
    final trackingState = ref.watch(trackingProvider);
    final theme = Theme.of(context);

    // Watch sync status to show SnackBar notifications
    ref.listen(photoSyncProvider, (previous, next) {
      if (next.status == PhotoSyncStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.syncedCount > 0
                  ? '사진 동기화 완료! ${next.syncedCount}장의 사진이 매칭되었습니다.'
                  : '새로운 사진이 없습니다.',
            ),
            backgroundColor: theme.colorScheme.tertiary,
          ),
        );
        ref.read(photoSyncProvider.notifier).reset();
      } else if (next.status == PhotoSyncStatus.permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('갤러리 접근 권한이 필요합니다.')),
        );
        ref.read(photoSyncProvider.notifier).reset();
      } else if (next.status == PhotoSyncStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('동기화 오류: ${next.errorMessage}')),
        );
        ref.read(photoSyncProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('LociHub Dashboard (펼침 모드)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Side: Google Map (60% width)
          Expanded(
            flex: 6,
            child: journalDataAsync.when(
              data: (data) => LociMapView(
                locationLogs: data.locationLogs,
                photos: data.photos,
                liveLatitude: trackingState.currentLatitude,
                liveLongitude: trackingState.currentLongitude,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('지도 로드 중 오류: $err')),
            ),
          ),

          // Divider
          VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),

          // Right Side: Control Panel & Timeline (40% width)
          Expanded(
            flex: 4,
            child: Container(
              color: theme.colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  // Header Block
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Date selector
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => _navigateDay(ref, -1),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => CalendarSelector.show(context),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                selectedDate,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _navigateDay(ref, 1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats Card & Sync button
                        journalDataAsync.when(
                          data: (data) => Card(
                            elevation: 0,
                            color: theme.colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatCol(context, '위치 포인트', '${data.locationLogs.length}개'),
                                  _buildStatCol(context, '동기화 사진', '${data.photos.length}장'),
                                  syncState.status == PhotoSyncStatus.syncing
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : TextButton.icon(
                                          onPressed: () {
                                            ref
                                                .read(photoSyncProvider.notifier)
                                                .syncPhotosForDate(selectedDate, ref);
                                          },
                                          icon: const Icon(Icons.sync, size: 16),
                                          label: const Text('동기화'),
                                        ),
                                ],
                              ),
                            ),
                          ),
                          loading: () => const SizedBox(height: 50),
                          error: (_, __) => const SizedBox(height: 50),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Middle Block: Timeline Feed list
                  Expanded(
                    child: journalDataAsync.when(
                      data: (data) => TimelineFeed(
                        locationLogs: data.locationLogs,
                        photos: data.photos,
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(child: Text('오류: $err')),
                    ),
                  ),

                  const Divider(height: 1),

                  // Bottom Block: Tracking Switch
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const TrackingStatusIndicator(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
