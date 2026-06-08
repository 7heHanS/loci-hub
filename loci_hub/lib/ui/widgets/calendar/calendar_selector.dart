import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/utils/timezone_utils.dart';
import '../../../providers/date_provider.dart';
import '../../../providers/journal_provider.dart';

class CalendarSelector extends ConsumerWidget {
  const CalendarSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDateStr = ref.watch(selectedDateProvider);
    final datesWithDataAsync = ref.watch(datesWithDataProvider);
    final theme = Theme.of(context);

    // Parse current selected date to DateTime
    DateTime selectedDateTime = DateTime.now();
    try {
      final parts = selectedDateStr.split('-');
      if (parts.length == 3) {
        selectedDateTime = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '날짜 선택',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          datesWithDataAsync.when(
            data: (datesList) {
              final Set<String> datesSet = datesList.toSet();

              return TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: selectedDateTime,
                selectedDayPredicate: (day) {
                  final formatted = TimezoneUtils.epochToJournalDate(
                    day.millisecondsSinceEpoch ~/ 1000,
                  );
                  return formatted == selectedDateStr;
                },
                eventLoader: (day) {
                  final formatted = TimezoneUtils.epochToJournalDate(
                    day.millisecondsSinceEpoch ~/ 1000,
                  );
                  // Return a dummy event list if this date has recorded data
                  return datesSet.contains(formatted) ? [true] : [];
                },
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  todayDecoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.secondary, width: 2),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                  markersAlignment: Alignment.bottomCenter,
                  markerDecoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  final formatted = TimezoneUtils.epochToJournalDate(
                    selectedDay.millisecondsSinceEpoch ~/ 1000,
                  );
                  ref.read(selectedDateProvider.notifier).state = formatted;
                  Navigator.of(context).pop();
                },
              );
            },
            loading: () => const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SizedBox(
              height: 300,
              child: Center(child: Text('오류 발생: $err')),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Helper static method to show the calendar bottom sheet.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CalendarSelector(),
    );
  }
}
