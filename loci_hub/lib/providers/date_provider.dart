import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/timezone_utils.dart';

final selectedDateProvider = StateProvider<String>((ref) {
  return TimezoneUtils.todayJournalDate();
});
