import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/tracking_provider.dart';

class TrackingStatusIndicator extends ConsumerWidget {
  const TrackingStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingProvider);
    final theme = Theme.of(context);

    final String statusText = trackingState.isTracking ? '추적 활성화됨' : '추적 중지됨';
    final Color statusColor = trackingState.isTracking ? theme.colorScheme.tertiary : theme.colorScheme.outline;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Blinking / Glowing dot
            _BlinkingDot(isActive: trackingState.isTracking, color: statusColor),
            const SizedBox(width: 12),
            
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (trackingState.isTracking) ...[
                    const SizedBox(height: 2),
                    Text(
                      trackingState.currentActivity != null
                          ? '현재 상태: ${_translateActivity(trackingState.currentActivity!)}'
                          : 'GPS 신호 대기 중...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    Text(
                      '위치 로깅을 시작하려면 켜기 버튼을 누르세요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            
            // Toggle Switch or Button
            Switch(
              value: trackingState.isTracking,
              activeColor: theme.colorScheme.primary,
              onChanged: (val) async {
                final success = await ref.read(trackingProvider.notifier).toggleTracking();
                if (!success && context.mounted) {
                  final error = ref.read(trackingProvider).permissionErrorMessage;
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        action: SnackBarAction(
                          label: '설정',
                          onPressed: () {
                            // Open settings
                            ref.read(trackingProvider.notifier);
                          },
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _translateActivity(String act) {
    switch (act) {
      case 'stationary':
        return '정지';
      case 'walking':
        return '도보 이동';
      case 'vehicle':
        return '차량 이동';
      default:
        return '이동';
    }
  }
}

class _BlinkingDot extends StatefulWidget {
  final bool isActive;
  final Color color;

  const _BlinkingDot({required this.isActive, required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isActive) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BlinkingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(
              widget.isActive ? 0.3 + 0.7 * _animationController.value : 1.0,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.5 * _animationController.value),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
        );
      },
    );
  }
}
