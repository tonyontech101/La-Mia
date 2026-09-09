import 'package:flutter_test/flutter_test.dart';
import 'package:lamia_app/features/notifications/data/notification_preference_model.dart';

void main() {
  group('NotificationPreferenceModel Tests', () {
    test('defaults() initializes all preferences to true', () {
      final prefs = NotificationPreferenceModel.defaults();

      expect(prefs.likes, isTrue);
      expect(prefs.comments, isTrue);
      expect(prefs.followers, isTrue);
      expect(prefs.followingNewRecipes, isTrue);
      expect(prefs.mealReminders, isTrue);
      expect(prefs.dailySuggestions, isTrue);
    });

    test('toMap() and fromMap() correctly round-trip serialize and deserialize', () {
      const original = NotificationPreferenceModel(
        likes: true,
        comments: false,
        followers: true,
        followingNewRecipes: false,
        mealReminders: true,
        dailySuggestions: false,
      );

      final map = original.toMap();

      expect(map, {
        'likes': true,
        'comments': false,
        'followers': true,
        'followingNewRecipes': false,
        'mealReminders': true,
        'dailySuggestions': false,
      });

      final reconstructed = NotificationPreferenceModel.fromMap(map);

      expect(reconstructed.likes, isTrue);
      expect(reconstructed.comments, isFalse);
      expect(reconstructed.followers, isTrue);
      expect(reconstructed.followingNewRecipes, isFalse);
      expect(reconstructed.mealReminders, isTrue);
      expect(reconstructed.dailySuggestions, isFalse);
    });

    test('fromMap(null) returns defaults with all true', () {
      final prefs = NotificationPreferenceModel.fromMap(null);

      expect(prefs.likes, isTrue);
      expect(prefs.comments, isTrue);
      expect(prefs.followers, isTrue);
      expect(prefs.followingNewRecipes, isTrue);
      expect(prefs.mealReminders, isTrue);
      expect(prefs.dailySuggestions, isTrue);
    });

    test('fromMap() falls back to true for omitted keys', () {
      final partial = {
        'mealReminders': false,
      };

      final prefs = NotificationPreferenceModel.fromMap(partial);

      expect(prefs.likes, isTrue);
      expect(prefs.comments, isTrue);
      expect(prefs.followers, isTrue);
      expect(prefs.followingNewRecipes, isTrue);
      expect(prefs.mealReminders, isFalse);
      expect(prefs.dailySuggestions, isTrue);
    });

    test('copyWith() updates individual fields while preserving others', () {
      final initial = NotificationPreferenceModel.defaults();

      final updatedDaily = initial.copyWith(dailySuggestions: false);
      expect(updatedDaily.dailySuggestions, isFalse);
      expect(updatedDaily.likes, isTrue);
      expect(updatedDaily.comments, isTrue);
      expect(updatedDaily.followers, isTrue);
      expect(updatedDaily.followingNewRecipes, isTrue);
      expect(updatedDaily.mealReminders, isTrue);

      final updatedMeal = updatedDaily.copyWith(mealReminders: false);
      expect(updatedMeal.mealReminders, isFalse);
      expect(updatedMeal.dailySuggestions, isFalse);
      expect(updatedMeal.likes, isTrue);

      final updatedLikes = initial.copyWith(likes: false);
      expect(updatedLikes.likes, isFalse);
      expect(updatedLikes.comments, isTrue);
      expect(updatedLikes.mealReminders, isTrue);

      final updatedComments = initial.copyWith(comments: false);
      expect(updatedComments.comments, isFalse);
      expect(updatedComments.likes, isTrue);

      final updatedFollowers = initial.copyWith(followers: false);
      expect(updatedFollowers.followers, isFalse);
      expect(updatedFollowers.followingNewRecipes, isTrue);

      final updatedNewRecipes = initial.copyWith(followingNewRecipes: false);
      expect(updatedNewRecipes.followingNewRecipes, isFalse);
      expect(updatedNewRecipes.followers, isTrue);

      // No change copyWith returns same values
      final noChange = initial.copyWith();
      expect(noChange.likes, isTrue);
      expect(noChange.comments, isTrue);
      expect(noChange.followers, isTrue);
      expect(noChange.followingNewRecipes, isTrue);
      expect(noChange.mealReminders, isTrue);
      expect(noChange.dailySuggestions, isTrue);
    });
  });
}
