import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/photo_repository.dart';
import '../../services/llm/llm_service.dart';
import 'journal_provider.dart';

enum LlmStatus {
  idle,
  generating,
  success,
  error,
}

class LlmState {
  final LlmStatus status;
  final String? errorMessage;

  LlmState({
    required this.status,
    this.errorMessage,
  });

  LlmState copyWith({
    LlmStatus? status,
    String? errorMessage,
  }) {
    return LlmState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class LlmNotifier extends StateNotifier<LlmState> {
  LlmNotifier() : super(LlmState(status: LlmStatus.idle));

  /// Generates the one-line diary summary and hashtags for a specific date
  /// and updates the daily journal.
  Future<bool> generateSummaryForDate(String date, WidgetRef ref) async {
    state = LlmState(status: LlmStatus.generating);

    try {
      final journalRepo = getIt<JournalRepository>();
      final locationRepo = getIt<LocationRepository>();
      final photoRepo = getIt<PhotoRepository>();
      final llmService = getIt<LlmService>();

      // 1. Fetch daily data
      final journal = await journalRepo.ensureJournalExists(date);
      final logs = await locationRepo.getLocationsForDate(date);
      final photos = await photoRepo.getPhotosForDate(date);

      if (logs.isEmpty && photos.isEmpty) {
        state = LlmState(
          status: LlmStatus.error,
          errorMessage: '오늘 하루의 위치 기록이나 동기화된 사진이 없습니다.\n요약을 생성하려면 기록을 먼저 쌓아주세요.',
        );
        return false;
      }

      // 2. Call local LLM service
      final result = await llmService.generateSummary(
        date: date,
        logs: logs,
        photos: photos,
      );

      // 3. Update DB
      final updatedJournal = journal.copyWith(
        aiTitle: result.title,
        aiSummary: result.hashtags,
      );
      await journalRepo.updateJournal(updatedJournal);

      state = LlmState(status: LlmStatus.success);

      // 4. Invalidate provider to refresh the UI
      ref.invalidate(journalDataProvider);
      return true;
    } catch (e) {
      String msg = e.toString();
      // Clean up common exception prefixes for friendly user messages
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring(11);
      }
      state = LlmState(
        status: LlmStatus.error,
        errorMessage: msg,
      );
      return false;
    }
  }

  void reset() {
    state = LlmState(status: LlmStatus.idle);
  }
}

final llmProvider = StateNotifierProvider<LlmNotifier, LlmState>((ref) {
  return LlmNotifier();
});
