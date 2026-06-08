import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/daily_journal.dart';
import '../../../providers/llm_provider.dart';

class AiSummaryCard extends ConsumerWidget {
  final DailyJournal? journal;
  final String date;

  const AiSummaryCard({
    super.key,
    required this.journal,
    required this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final llmState = ref.watch(llmProvider);
    final theme = Theme.of(context);

    // Watch status changes to show SnackBar on success/error
    ref.listen(llmProvider, (previous, next) {
      if (next.status == LlmStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI 한줄 일기가 생성되었습니다!'),
            backgroundColor: theme.colorScheme.primary,
          ),
        );
        ref.read(llmProvider.notifier).reset();
      } else if (next.status == LlmStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? '요약 생성 실패'),
            backgroundColor: theme.colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(llmProvider.notifier).reset();
      }
    });

    final hasData = journal != null &&
        journal!.aiTitle != null &&
        journal!.aiTitle!.trim().isNotEmpty;

    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasData 
              ? theme.colorScheme.primary.withOpacity(0.3) 
              : theme.colorScheme.outlineVariant,
          width: hasData ? 1.5 : 1.0,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: hasData
                ? [
                    theme.colorScheme.primaryContainer.withOpacity(0.15),
                    theme.colorScheme.tertiaryContainer.withOpacity(0.15),
                  ]
                : [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerLow,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: AI Assistant Label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasData
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: hasData
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI 한줄 일기 & 태그',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasData 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (hasData && llmState.status != LlmStatus.generating)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: '일기 다시 생성',
                      onPressed: () {
                        ref.read(llmProvider.notifier).generateSummaryForDate(date, ref);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Content based on LLM Status
              if (llmState.status == LlmStatus.generating) ...[
                // Generating state
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '로컬 AI 모델이 오늘 하루를 분석하는 중...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (hasData) ...[
                // Success / Existing data state
                Text(
                  '"${journal!.aiTitle}"',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  journal!.aiSummary ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // Idle / No data state
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '오늘 하루가 어땠는지 온디바이스 AI 비서에게 요약을 부탁해보세요.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(llmProvider.notifier).generateSummaryForDate(date, ref);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        '생성',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
