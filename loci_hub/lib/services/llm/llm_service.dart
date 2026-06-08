import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p)/2 + 
              cos(lat1 * p) * cos(lat2 * p) * 
              (1 - cos((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Generates a one-line diary title and hashtags using Google Gemini Cloud API.
  Future<AiResult> generateSummary({
    required String apiKey,
    required String date,
    required List<LocationLog> logs,
    required List<PhotoMetadata> photos,
    String? base64Image,
  }) async {
    final prompt = generatePrompt(date, logs, photos);

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey';
      final uri = Uri.parse(url);
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=UTF-8');

      final parts = <Map<String, dynamic>>[
        {'text': prompt}
      ];

      if (base64Image != null && base64Image.isNotEmpty) {
        parts.add({
          'inlineData': {
            'mimeType': 'image/jpeg',
            'data': base64Image,
          }
        });
      }

      final body = {
        'contents': [
          {
            'parts': parts
          }
        ],
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': {
            'type': 'OBJECT',
            'properties': {
              'title': {
                'type': 'STRING',
                'description': '감성적인 오늘의 한 줄 일기 요약 (60자 이내)'
              },
              'hashtags': {
                'type': 'STRING',
                'description': '일기와 어울리는 해시태그 3~5개 (스페이스로 구분, 예: "#산책 #일상")'
              }
            },
            'required': ['title', 'hashtags']
          }
        }
      };

      request.write(jsonEncode(body));
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>?;
        if (candidates == null || candidates.isEmpty) {
          throw Exception('Gemini API가 빈 응답을 반환했습니다.');
        }
        final contentText = candidates[0]['content']['parts'][0]['text'] as String;
        return parseJsonResponse(contentText);
      } else {
        String errorMsg = 'Gemini API 호출 실패 (Status: ${response.statusCode})';
        try {
          final decodedErr = jsonDecode(responseBody) as Map<String, dynamic>;
          final msg = decodedErr['error']['message'] as String?;
          if (msg != null && msg.isNotEmpty) {
            errorMsg = 'Gemini 오류: $msg';
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } on SocketException catch (e) {
      throw SocketException(
        '인터넷 연결을 확인해주세요. Gemini API 서버에 연결할 수 없습니다. (오류: ${e.message})',
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

    // Haversine cumulative distance and radius
    double totalDistance = 0.0;
    for (int i = 0; i < logs.length - 1; i++) {
      totalDistance += _calculateDistance(
        logs[i].latitude,
        logs[i].longitude,
        logs[i + 1].latitude,
        logs[i + 1].longitude,
      );
    }

    double radius = 0.0;
    if (logs.isNotEmpty) {
      radius = _calculateDistance(
        logs.first.latitude,
        logs.first.longitude,
        logs.last.latitude,
        logs.last.longitude,
      );
    }

    // Extrapolate representative path waypoints (up to 5)
    List<String> waypoints = [];
    final stationaryLogs = logs.where((l) => l.activityType == 'stationary').toList();
    final sourceList = stationaryLogs.length >= 3 ? stationaryLogs : logs;

    if (sourceList.isNotEmpty) {
      int step = (sourceList.length / 5).clamp(1, double.infinity).toInt();
      for (int i = 0; i < sourceList.length; i += step) {
        if (waypoints.length >= 5) break;
        final log = sourceList[i];
        final dt = DateTime.fromMillisecondsSinceEpoch(log.timestamp * 1000).toLocal();
        final timeStr = DateFormat('HH:mm').format(dt);
        waypoints.add('$timeStr (위도: ${log.latitude.toStringAsFixed(4)}, 경도: ${log.longitude.toStringAsFixed(4)})');
      }
      if (waypoints.length < 5 && sourceList.last != sourceList.first) {
        final log = sourceList.last;
        final dt = DateTime.fromMillisecondsSinceEpoch(log.timestamp * 1000).toLocal();
        final timeStr = DateFormat('HH:mm').format(dt);
        waypoints.add('$timeStr (위도: ${log.latitude.toStringAsFixed(4)}, 경도: ${log.longitude.toStringAsFixed(4)})');
      }
    }

    return '''
사용자의 하루 위치 이동 기록과 사진 기록을 바탕으로 감성적인 하루 요약 일기 및 해시태그를 생성해 주세요.
만약 멀티모달 이미지(사진)가 첨부된 경우, 사진의 내용(음식, 장소, 사물, 분위기 등)을 일기에 풍부하게 반영해 주세요.

하루 데이터:
- 날짜: $date
- 위치 수집 범위: $timeRange (총 $totalLogs개 좌표 수집)
- 상태별 수집 비중: 정지 상태 $stationaryCount회, 도보 이동 $walkingCount회, 차량 이동 $vehicleCount회
- 상세 이동 동선 (시간별 경유 좌표):
${waypoints.isEmpty ? '  * 경유지 없음' : waypoints.map((w) => '  * $w').join('\n')}
- 이동 거리 분석: 당일 총 누적 이동 거리는 약 ${totalDistance.toStringAsFixed(1)}km 이며, 수집 시작 지점과 끝 지점 간의 직선거리는 약 ${radius.toStringAsFixed(1)}km 입니다. (거리와 동선 변화를 통해 여행이나 먼 출장 여부를 파악해 일기에 반영해 주세요.)
- 촬영한 사진: 총 $totalPhotos장 (촬영 시각: ${photoTimes.join(', ')} / 그 중 $matchedCount장은 위치 매칭 완료)

조건:
1. title은 오늘 하루를 요약하는 소설이나 에세이 같은 느낌의 감성적이고 자연스러운 한 줄 일기(한국어, 공백 포함 60자 이내)로 작성해 주세요. (예: "노을빛 아래에서 천천히 동네를 산책하며 깊은 숨을 내쉬었던 고즈넉한 하루")
2. hashtags는 일기 내용과 어울리는 핵심 해시태그 3~5개를 스페이스로 구분하여 작성해 주세요. (예: "#산책 #노을 #여유 #일상")
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
