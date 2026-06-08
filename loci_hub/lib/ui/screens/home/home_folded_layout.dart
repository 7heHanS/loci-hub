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
import '../../widgets/common/ai_summary_card.dart';
import '../../widgets/map/loci_map_view.dart';
import '../../widgets/timeline/timeline_feed.dart';

class HomeFoldedLayout extends ConsumerWidget {
  const HomeFoldedLayout({super.key});

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
        title: const Text('LociHub (접힘 모드)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
          // Date Selector Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _navigateDay(ref, -1),
                ),
                InkWell(
                  onTap: () => CalendarSelector.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          selectedDate,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _navigateDay(ref, 1),
                ),
              ],
            ),
          ),

          // Main content loaded reactively
          Expanded(
            child: journalDataAsync.when(
              data: (data) {
                return Column(
                  children: [
                    // Map View (Fixed height to prevent overflow on smaller screens)
                    Container(
                      height: 170.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
                          top: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                      ),
                      child: LociMapView(
                        locationLogs: data.locationLogs,
                        photos: data.photos,
                        liveLatitude: trackingState.currentLatitude,
                        liveLongitude: trackingState.currentLongitude,
                      ),
                    ),

                    // Controls Row (Sync Button & Metrics)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.gps_fixed, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${data.locationLogs.length}개',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(Icons.photo_library, size: 14, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${data.photos.length}장',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          syncState.status == PhotoSyncStatus.syncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : FilledButton(
                                  onPressed: () {
                                    ref
                                        .read(photoSyncProvider.notifier)
                                        .syncPhotosForDate(selectedDate, ref);
                                  },
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sync, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '동기화',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),

                    // AI Summary Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                      child: AiSummaryCard(
                        journal: data.journal,
                        date: selectedDate,
                      ),
                    ),

                    // Timeline Feed (Rest of the height)
                    Expanded(
                      child: TimelineFeed(
                        locationLogs: data.locationLogs,
                        photos: data.photos,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text('데이터 로딩 중 오류 발생: $err'),
                ),
              ),
            ),
          ),

          // Bottom Tracking Switch Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: const TrackingStatusIndicator(),
          ),
        ],
      ),
      ),
    );
  }
}
