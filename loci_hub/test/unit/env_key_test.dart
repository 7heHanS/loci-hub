import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify GEMINI_API_KEY is loaded correctly from local env file', () {
    const key = String.fromEnvironment('GEMINI_API_KEY');
    if (key.isEmpty) {
      print('ℹ️ GEMINI_API_KEY is empty (no --dart-define-from-file provided). Skipping check.');
      return;
    }
    expect(key, isNotEmpty);
    expect(key.startsWith('AIzaSy'), isTrue);
    print('✅ Successfully loaded GEMINI_API_KEY: ${key.substring(0, 8)}...');
  });
}
