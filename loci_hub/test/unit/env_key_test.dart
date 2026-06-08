import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Verify GEMINI_API_KEY is loaded correctly from local env file', () {
    const key = String.fromEnvironment('GEMINI_API_KEY');
    expect(key, isNotEmpty);
    expect(key.startsWith('AIzaSy'), isTrue);
    print('✅ Successfully loaded GEMINI_API_KEY: ${key.substring(0, 8)}...');
  });
}
