import 'package:flutter_test/flutter_test.dart';
import 'package:sakrylle_chat/utils/display_amount.dart';

void main() {
  group('formatDisplayAmount', () {
    test('prefixes full-width yen (U+FFE5) for display-only amounts', () {
      expect(formatDisplayAmount(12.5), '￥12.50');
      expect('￥'.codeUnitAt(0), 0xFFE5); // full-width, not half-width ¥
    });
    test('respects fraction digits', () {
      expect(formatDisplayAmount(3, fractionDigits: 0), '￥3');
    });
  });
}
