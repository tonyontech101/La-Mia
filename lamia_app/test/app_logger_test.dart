import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/core/utils/app_logger.dart';

void main() {
  test('AppLogger methods complete without throwing exceptions', () {
    expect(() => AppLogger.debug('Debug message', 'TEST'), returnsNormally);
    expect(() => AppLogger.info('Info message', 'TEST'), returnsNormally);
    expect(() => AppLogger.warning('Warning message', 'TEST'), returnsNormally);
    expect(
      () => AppLogger.error(
        'Error message',
        error: Exception('Test exception'),
        stackTrace: StackTrace.current,
        category: 'TEST',
      ),
      returnsNormally,
    );
  });
}
