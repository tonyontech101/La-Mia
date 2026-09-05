import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/app/app.dart';
import 'package:lamia_app/features/notifications/services/notification_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationRouter.parsePayload', () {
    test('successfully parses recipe payload', () {
      const raw = '{"targetType": "recipe", "targetId": "rec_adobo_001"}';
      final payload = NotificationRouter.parsePayload(raw);

      expect(payload, isNotNull);
      expect(payload!['targetType'], 'recipe');
      expect(payload['targetId'], 'rec_adobo_001');
    });

    test('successfully parses planner payload', () {
      const raw = '{"targetType": "planner"}';
      final payload = NotificationRouter.parsePayload(raw);

      expect(payload, isNotNull);
      expect(payload!['targetType'], 'planner');
    });

    test('successfully parses user profile payload', () {
      const raw = '{"targetType": "user", "targetId": "chef_maria"}';
      final payload = NotificationRouter.parsePayload(raw);

      expect(payload, isNotNull);
      expect(payload!['targetType'], 'user');
      expect(payload['targetId'], 'chef_maria');
    });

    test('successfully parses achievement payload', () {
      const raw = '{"targetType": "achievement"}';
      final payload = NotificationRouter.parsePayload(raw);

      expect(payload, isNotNull);
      expect(payload!['targetType'], 'achievement');
    });

    test('successfully parses legacy route format payload', () {
      const raw = '{"route": "/planner"}';
      final payload = NotificationRouter.parsePayload(raw);

      expect(payload, isNotNull);
      expect(payload!['route'], '/planner');
    });

    test('returns null for empty string', () {
      final payload = NotificationRouter.parsePayload('');
      expect(payload, isNull);
    });

    test('returns null for invalid JSON string', () {
      final payload = NotificationRouter.parsePayload('{not_valid_json: 123}');
      expect(payload, isNull);
    });

    test('returns null when JSON is a primitive or array rather than a Map', () {
      expect(NotificationRouter.parsePayload('["item1", "item2"]'), isNull);
      expect(NotificationRouter.parsePayload('12345'), isNull);
      expect(NotificationRouter.parsePayload('"string_value"'), isNull);
      expect(NotificationRouter.parsePayload('true'), isNull);
      expect(NotificationRouter.parsePayload('null'), isNull);
    });
  });

  group('NotificationRouter.navigateWithPayload', () {
    test('completes without error on invalid payload', () async {
      await expectLater(
        NotificationRouter.navigateWithPayload('invalid json'),
        completes,
      );
    });

    test('completes without error when navigator context is null', () async {
      expect(rootNavigatorKey.currentContext, isNull);
      await expectLater(
        NotificationRouter.navigateWithPayload('{"targetType": "planner"}'),
        completes,
      );
    });
  });
}
