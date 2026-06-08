import 'package:flutter_test/flutter_test.dart';
import 'package:loci_hub/data/models/location_log.dart';
import 'package:loci_hub/data/models/photo_metadata.dart';
import 'package:loci_hub/data/models/match_status.dart';
import 'package:loci_hub/data/models/taken_time_source.dart';
import 'package:loci_hub/services/llm/llm_service.dart';

void main() {
  group('LlmService Unit Tests', () {
    late LlmService llmService;

    setUp(() {
      llmService = LlmService();
    });

    test('parseJsonResponse parses clean JSON correctly', () {
      const jsonContent = '{"title": "성공적인 피크닉", "hashtags": "#피크닉 #화창함"}';
      final result = llmService.parseJsonResponse(jsonContent);

      expect(result.title, '성공적인 피크닉');
      expect(result.hashtags, '#피크닉 #화창함');
    });

    test('parseJsonResponse parses markdown code blocks correctly', () {
      const markdownJson = '''
```json
{
  "title": "산속을 걷는 상쾌함",
  "hashtags": "#등산 #힐링 #숲속"
}
```''';
      final result = llmService.parseJsonResponse(markdownJson);

      expect(result.title, '산속을 걷는 상쾌함');
      expect(result.hashtags, '#등산 #힐링 #숲속');
    });

    test('fallbackParse parses invalid JSON formatted plain text', () {
      const rawText = '''
제목: 노을빛 가득한 낭만적인 밤 산책
태그: #밤산책 #노을 #여유 #하루마무리
''';
      final result = llmService.fallbackParse(rawText);

      expect(result.title, contains('노을빛 가득한 낭만적인 밤 산책'));
      expect(result.hashtags, contains('#밤산책 #노을 #여유 #하루마무리'));
    });

    test('generatePrompt generates prompt containing stats', () {
      final logs = [
        LocationLog(
          id: 1,
          journalDate: '2026-06-08',
          timestamp: 1770000000,
          latitude: 37.5,
          longitude: 127.0,
          accuracy: 10.0,
          altitude: 50.0,
          speed: 1.2,
          heading: 90.0,
          provider: 'gps',
          activityType: 'walking',
          createdAt: 1770000000,
        ),
      ];

      final photos = [
        PhotoMetadata(
          assetId: '123',
          journalDate: '2026-06-08',
          assetTitle: 'test.jpg',
          relativePath: 'DCIM/',
          takenAt: 1770000000,
          takenTimeSource: TakenTimeSource.exifOriginal,
          matchStatus: MatchStatus.matched,
        ),
      ];

      final prompt = llmService.generatePrompt('2026-06-08', logs, photos);

      expect(prompt, contains('2026-06-08'));
      expect(prompt, contains('총 1개 좌표 수집'));
      expect(prompt, contains('도보 이동 1회'));
      expect(prompt, contains('총 1장'));
      expect(prompt, contains('상세 이동 동선'));
      expect(prompt, contains('이동 거리 분석'));
    });
  });
}
