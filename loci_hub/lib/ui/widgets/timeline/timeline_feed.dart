import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../data/models/location_log.dart';
import '../../../data/models/photo_metadata.dart';
import '../../../data/models/match_status.dart';

class TimelineEvent {
  final int timestamp;
  final String timeStr;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final PhotoMetadata? photo;
  final LocationLog? location;

  TimelineEvent({
    required this.timestamp,
    required this.timeStr,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.photo,
    this.location,
  });
}

class TimelineFeed extends StatelessWidget {
  final List<LocationLog> locationLogs;
  final List<PhotoMetadata> photos;

  const TimelineFeed({
    super.key,
    required this.locationLogs,
    required this.photos,
  });

  List<TimelineEvent> _compileEvents(BuildContext context) {
    final theme = Theme.of(context);
    final List<TimelineEvent> events = [];

    // 1. Add matched and unmatched photos
    for (final photo in photos) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(photo.takenAt * 1000).toLocal();
      final timeStr = DateFormat('HH:mm:ss').format(dateTime);

      String title = '사진 촬영';
      String subtitle = photo.assetTitle;
      IconData icon = Icons.photo;
      Color color = theme.colorScheme.primary;

      if (photo.matchStatus == MatchStatus.matched) {
        title = '사진 위치 매칭 완료';
        subtitle = '${photo.assetTitle}\n신뢰도: ${(photo.matchedConfidence! * 100).toStringAsFixed(0)}% (오차: ${photo.matchTimeDiffSeconds}초)';
        icon = Icons.add_photo_alternate;
        color = theme.colorScheme.tertiary; // Violet/purple hue
      } else if (photo.matchStatus == MatchStatus.unmatchedOutOfTolerance) {
        title = '사진 매칭 실패';
        subtitle = '${photo.assetTitle} (가까운 위치 로그 오차 초과)';
        icon = Icons.no_photography;
        color = theme.colorScheme.error;
      } else if (photo.matchStatus == MatchStatus.unmatchedNoLocation) {
        title = '사진 매칭 실패';
        subtitle = '${photo.assetTitle} (수집된 위치 로그 없음)';
        icon = Icons.no_photography;
        color = theme.colorScheme.outline;
      }

      events.add(
        TimelineEvent(
          timestamp: photo.takenAt,
          timeStr: timeStr,
          title: title,
          subtitle: subtitle,
          icon: icon,
          color: color,
          photo: photo,
        ),
      );
    }

    // 2. Add location state changes
    if (locationLogs.isNotEmpty) {
      // First log
      final firstLog = locationLogs.first;
      final firstTime = DateTime.fromMillisecondsSinceEpoch(firstLog.timestamp * 1000).toLocal();
      events.add(
        TimelineEvent(
          timestamp: firstLog.timestamp,
          timeStr: DateFormat('HH:mm').format(firstTime),
          title: '위치 기록 시작',
          subtitle: '첫 수집 포인트 (${firstLog.provider})',
          icon: Icons.play_arrow,
          color: theme.colorScheme.secondary,
          location: firstLog,
        ),
      );

      String currentActivity = '';
      int lastEventTime = firstLog.timestamp;

      for (int i = 0; i < locationLogs.length; i++) {
        final log = locationLogs[i];
        final act = log.activityType;
        final isLast = i == locationLogs.length - 1;

        // Condition for significant event: Activity change, or gap > 45 minutes
        final timeGap = log.timestamp - lastEventTime;
        final activityChanged = act != currentActivity && currentActivity.isNotEmpty;

        if (activityChanged || timeGap > 2700 || isLast) {
          currentActivity = act;
          lastEventTime = log.timestamp;

          final time = DateTime.fromMillisecondsSinceEpoch(log.timestamp * 1000).toLocal();
          final timeStr = DateFormat('HH:mm').format(time);

          String title = '이동 중';
          String subtitle = '';
          IconData icon = Icons.directions_walk;
          Color color = theme.colorScheme.secondary;

          if (act == 'stationary') {
            title = '정지 상태 감지';
            icon = Icons.location_on;
            color = theme.colorScheme.outline;
          } else if (act == 'vehicle') {
            title = '차량 이동 감지';
            icon = Icons.directions_car;
            color = theme.colorScheme.primaryContainer;
          }

          if (isLast && locationLogs.length > 1) {
            title = '위치 기록 종료';
            subtitle = '마지막 수집 포인트 (${log.provider})';
            icon = Icons.stop;
            color = theme.colorScheme.secondary;
          } else {
            final speedKmH = (log.speed * 3.6).toStringAsFixed(1);
            final accuracyM = log.accuracy.toStringAsFixed(1);
            subtitle = '속도: $speedKmH km/h | 정확도: ${accuracyM}m';
          }

          // Avoid duplicating first event timestamp
          if (log.timestamp != firstLog.timestamp || isLast) {
            events.add(
              TimelineEvent(
                timestamp: log.timestamp,
                timeStr: timeStr,
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: color,
                location: log,
              ),
            );
          }
        }
      }
    }

    // 3. Sort all events chronologically
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compiledEvents = _compileEvents(context);

    if (compiledEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: 64,
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '기록된 타임라인이 없습니다.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '백그라운드 위치 추적을 활성화하거나\n갤러리 사진을 동기화해보세요.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      itemCount: compiledEvents.length,
      itemBuilder: (context, index) {
        final event = compiledEvents[index];
        final isLast = index == compiledEvents.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline Node Line & Icon
              Container(
                width: 48,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    // Dot/Icon Container
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: event.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: event.color,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        event.icon,
                        size: 18,
                        color: event.color,
                      ),
                    ),
                    // Line
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                  ],
                ),
              ),

              // Event Detail Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, right: 8.0),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time tag and Title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  event.timeStr,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),

                          // If the event has photo asset, render thumbnail
                          if (event.photo != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                height: 160,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: FutureBuilder<dynamic>(
                                  future: AssetEntity.fromId(event.photo!.assetId).then(
                                    (entity) => entity?.thumbnailDataWithSize(
                                      const ThumbnailSize(400, 400),
                                    ),
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done &&
                                        snapshot.data != null) {
                                      return Image.memory(
                                        snapshot.data,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Center(
                                            child: Icon(Icons.broken_image, size: 48),
                                          );
                                        },
                                      );
                                    }
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
