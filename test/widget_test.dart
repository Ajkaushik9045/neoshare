import 'package:flutter_test/flutter_test.dart';
import 'package:neoshare/core/utils/short_code_util.dart';

void main() {
  test('Short code display format is readable', () {
    expect(ShortCodeUtil.formatForDisplay('A4X9K2'), 'A4X-9K2');
  });
}
