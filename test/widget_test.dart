import 'package:flutter_test/flutter_test.dart';
import 'package:punchcardqr/core/errors/app_exception.dart';
import 'package:punchcardqr/core/theme/app_theme.dart';

void main() {
  test('AppException maps known codes to friendly messages', () {
    expect(AppException('cooldown_active').message, 'Punch recently added.');
    expect(AppException('whatever').message, contains('Something went wrong'));
  });

  test('parseHex falls back on invalid input', () {
    expect(parseHex('#FF0000', AppTheme.seed).toARGB32(), 0xFFFF0000);
    expect(parseHex('nope', AppTheme.seed), AppTheme.seed);
    expect(parseHex(null, AppTheme.seed), AppTheme.seed);
  });
}
