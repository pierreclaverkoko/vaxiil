import 'package:flutter_test/flutter_test.dart';
import 'package:vaxiil_mobile/core/errors/display_error.dart';
import 'package:vaxiil_mobile/core/errors/failures.dart';

void main() {
  group('sanitizeErrorMessage', () {
    test('leaves plain text alone', () {
      expect(sanitizeErrorMessage('  Hello world  '), 'Hello world');
    });

    test('strips multi-tag HTML', () {
      expect(
        sanitizeErrorMessage('<p>Bad <b>gateway</b></p>'),
        'Bad gateway',
      );
    });
  });

  group('truncateErrorMessage', () {
    test('truncates with ellipsis', () {
      final result = truncateErrorMessage('a' * 250, max: 50);
      expect(result.display.length, lessThanOrEqualTo(50));
      expect(result.display.endsWith('…'), isTrue);
      expect(result.full.length, 250);
    });
  });

  group('displayErrorMessage', () {
    test('uses Failure.message and truncates HTML', () {
      final html =
          '<!DOCTYPE html><html><body><h1>Server Error</h1><p>${'x' * 300}</p></body></html>';
      final msg = displayErrorMessage(NetworkFailure.serverError(message: html));
      expect(msg.contains('<'), isFalse);
      expect(msg.endsWith('…'), isTrue);
      expect(msg.length, lessThanOrEqualTo(kDisplayErrorMaxLength));
    });
  });
}
