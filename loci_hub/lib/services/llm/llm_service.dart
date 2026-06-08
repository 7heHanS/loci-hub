import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../data/models/location_log.dart';
import '../../data/models/photo_metadata.dart';
import '../../data/models/match_status.dart';

class AiResult {
  final String title;
  final String hashtags;

  AiResult({required this.title, required this.hashtags});
}

class LlmService {
  static const String _serverUrl = 'http://localhost:9379/v1/chat/completions';
  static const String _modelName = 'gemma-4-e4b-it';

  /// Generates a one-line diary title and hashtags using local gemma-4-e4b-it model.
  Future<AiResult> generateSummary({
    required String date,
    required List<LocationLog> logs,
    required List<PhotoMetadata> photos,
  }) async {
    final prompt = generatePrompt(date, logs, photos);

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse(_serverUrl);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=UTF-8');

      final body = {
        'model': _modelName,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      };

      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final content = decoded['choices'][0]['message']['content'] as String;
        return parseJsonResponse(content);
      } else {
        throw HttpException(
          '로컬 AI 서버가 에러 코드를 반환했습니다 (Status: ${response.statusCode})',
          uri: uri,
        );
      }
    } on SocketException catch (e) {
      throw SocketException(
        '로컬 AI 모델 서버(9379 포트)에 연결할 수 없습니다. Edge Gallery 앱에서 Gemma-4 모델이 실행 중인지 확인해주세요. (오류: ${e.message})',
        osError: e.osError,
        address: e.address,
        port: e.port,
      );
    } finally {
      client.close();
    }
  }

  String generatePrompt(String date, List<LocationLog> logs, List<PhotoMetadata> photos) {
    int totalLogs = logs.length;
    int totalPhotos = photos.length;

    int stationaryCount = logs.where((l) => l.activityType == 'stationary').length;
    int walkingCount = logs.where((l) => l.activityType == 'walking').length;
    int vehicleCount = logs.where((l) => l.activityType == 'vehicle').length;

    String timeRange = '기록 없음';
    if (logs.isNotEmpty) {
      final start = DateTime.fromMillisecondsSinceEpoch(logs.first.timestamp * 1000).toLocal();
      final end = DateTime.fromMillisecondsSinceEpoch(logs.last.timestamp * 1000).toLocal();
      final formatter = DateFormat('HH:mm');
      timeRange = '${formatter.format(start)} ~ ${formatter.format(end)}';
    }

    List<String> photoTimes = [];
    int matchedCount = 0;
    for (final photo in photos) {
      if (photo.matchStatus == MatchStatus.matched) {
        matchedCount++;
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(photo.takenAt * 1000).toLocal();
      photoTimes.add(DateFormat('HH:mm').format(dt));
    }

    return '''
당신은 사용자의 하루 위치 이동 기록과 사진 기록을 바탕으로 일기를 작성해주는 똑똑한 On-device 개인 비서입니다.
아래의 하루 동안의 수집된 데이터를 바탕으로, 오늘 하루를 함축하는 감성적이고 읽기 좋은 "한 줄 요약"과 연관된 "해시태그"를 생성해 주세요.

데이터:
- 날짜: $date
- 위치 수집 범위: $timeRange (총 $totalLogs개 좌표 수집)
- 상태별 수집 비중: 정지 상태 $stationaryCount회, 도보 이동 $walkingCount회, 차량 이동 $vehicleCount회
- 촬영한 사진: 총 $totalPhotos장 (촬영 시각: ${photoTimes.join(', ')} / 그 중 $matchedCount장은 위치 매칭 완료)

조건:
1. "한 줄 요약"은 소설이나 에세이 같은 느낌의 감성적이고 자연스러운 문장으로 작성해 주세요. (예: "노을빛 아래에서 천천히 동네를 산책하며 깊은 숨을 내쉬었던 고즈넉한 하루")
2. "해시태그"는 일기 내용과 어울리는 3개에서 5개의 태그로 띄어쓰기로 구분하여 작성해 주세요. (예: "#산책 #노을 #여유 #일상")
3. 한국어(Korean)로만 답변해 주세요.
4. 반드시 아래 지정된 JSON 형식으로만 응답해 주세요. 다른 설명이나 텍스트는 일체 포함하지 마세요.

JSON 형식:
{
  "title": "여기에 감성적인 한 줄 요약을 적으세요.",
  "hashtags": "여기에 해시태그를 적으세요."
}
''';
  }

  AiResult parseJsonResponse(String content) {
    String cleanContent = content.trim();
    if (cleanContent.startsWith('```')) {
      final firstNewline = cleanContent.indexOf('\n');
      final lastBackticks = cleanContent.lastIndexOf('```');
      if (firstNewline != -1 && lastBackticks != -1 && lastBackticks > firstNewline) {
        cleanContent = cleanContent.substring(firstNewline + 1, lastBackticks).trim();
      }
      if (cleanContent.startsWith('json')) {
        cleanContent = cleanContent.substring(4).trim();
      }
    }

    try {
      final parsed = jsonDecode(cleanContent) as Map<String, dynamic>;
      final title = parsed['title'] as String? ?? '오늘 하루도 무사히 마무리했습니다.';
      final hashtags = parsed['hashtags'] as String? ?? '#일상';
      return AiResult(title: title, hashtags: hashtags);
    } catch (e) {
      return fallbackParse(content);
    }
  }

  AiResult _parseContentValue(String content, String key) {
    final keyPattern = RegExp('"$key"\\s*:\\s*"([^"]+)"');
    final match = keyPattern.firstMatch(content);
    if (match != null && match.groupCount >= 1) {
      return AiResult(title: match.group(1)!, hashtags: '');
    }
    return AiResult(title: '', hashtags: '');
  }

  AiResult fallbackParse(String content) {
    // Attempt key-based regex extraction first
    final titleMatch = _parseContentValue(content, 'title');
    final hashtagsMatch = _parseContentValue(content, 'hashtags');
    if (titleMatch.title.isNotEmpty && hashtagsMatch.title.isNotEmpty) {
      return AiResult(title: titleMatch.title, hashtags: hashtagsMatch.title);
    }

    final lines = content.split('\n');
    String title = '';
    String hashtags = '';
    for (var line in lines) {
      if (line.contains('#')) {
        hashtags += ' ${line.trim()}';
      } else if (line.trim().isNotEmpty && !line.contains('{') && !line.contains('}') && title.isEmpty) {
        title = line.trim();
      }
    }

    if (title.isEmpty) title = '오늘 하루도 즐거운 시간이었습니다.';
    if (hashtags.isEmpty) hashtags = '#일상 #하루';

    return AiResult(
      title: title.replaceAll(RegExp(r'["\{\}\[\]]'), '').trim(),
      hashtags: hashtags.replaceAll(RegExp(r'["\{\}\[\]]'), '').trim(),
    );
  }
}
