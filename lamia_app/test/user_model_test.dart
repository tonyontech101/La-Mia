import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/auth/data/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('UserModel Serialization & Deserialization', () {
    test('handles default / missing fields gracefully', () {
      // Mock DocumentSnapshot behavior with toFirestore
      final model = UserModel(
        uid: 'user123',
        displayName: 'Chef Maria',
        bio: 'Cooking with love',
        photoUrl: 'https://example.com/avatar.jpg',
      );

      expect(model.uid, 'user123');
      expect(model.displayName, 'Chef Maria');
      expect(model.recipeCount, 0);
      expect(model.totalLikesReceived, 0);
      expect(model.role, 'user');
    });

    test('toFirestore includes all expected fields', () {
      final now = DateTime(2026, 1, 1);
      final model = UserModel(
        uid: 'user456',
        displayName: 'Chef Juan',
        bio: 'Filipino home cook',
        photoUrl: null,
        recipeCount: 5,
        totalLikesReceived: 20,
        followerCount: 10,
        followingCount: 3,
        savedCount: 2,
        role: 'user',
        createdAt: now,
      );

      final map = model.toFirestore();
      expect(map['displayName'], 'Chef Juan');
      expect(map['bio'], 'Filipino home cook');
      expect(map['photoUrl'], isNull);
      expect(map['recipeCount'], 5);
      expect(map['totalLikesReceived'], 20);
      expect(map['followerCount'], 10);
      expect(map['followingCount'], 3);
      expect(map['savedCount'], 2);
      expect(map['role'], 'user');
      expect(map['createdAt'], isA<Timestamp>());
    });
  });
}
