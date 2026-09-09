// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lamia_app/core/providers/current_user_provider.dart';
import 'package:lamia_app/core/providers/firebase_providers.dart';
import 'package:lamia_app/core/providers/repository_providers.dart';
import 'package:lamia_app/features/auth/data/user_model.dart';
import 'package:lamia_app/features/auth/data/user_repository.dart';
import 'package:lamia_app/features/recipes/data/recipe_model.dart';
import 'package:lamia_app/features/recipes/presentation/recipe_detail_screen.dart';
import 'package:lamia_app/features/social/data/follow_repository.dart';

class FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserRepository extends UserRepository {
  FakeUserRepository({required this.fakeUser}) : super(firestore: FakeFirestore());

  final UserModel? fakeUser;

  @override
  Future<UserModel?> getUser(String uid) async {
    return fakeUser;
  }

  @override
  Stream<UserModel?> getUserStream(String uid) {
    return Stream.value(fakeUser);
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final staleRecipe = RecipeModel(
    id: 'ramen-123',
    name: 'Ramen',
    description: 'Hot broth and noodles.',
    category: 'Sabaw',
    region: 'Tagalog',
    prepTime: '40 mins',
    cookTime: '45 mins',
    servings: 2,
    difficulty: 'Hard',
    ingredients: ['1 pc egg', '1 pc noodle'],
    instructions: ['Step 1: Boil noodles', 'Step 2: Serve hot'],
    tags: ['Sabaw', 'Hard'],
    coverPhotoUrl: '',
    source: 'user',
    authorId: 'author-uid-1',
    authorName: 'venus relator',
    authorPhotoUrl: null,
    isSystemRecipe: false,
  );

  testWidgets('RecipeDetailScreen updates authorName to live profile name and syncs follow status', (tester) async {
    final liveUser = UserModel(
      uid: 'author-uid-1',
      displayName: 'Jayzer Relator',
      bio: 'MEOWWWW',
      photoUrl: null,
      recipeCount: 1,
      totalLikesReceived: 5,
      followerCount: 2,
      followingCount: 2,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseFirestoreProvider.overrideWithValue(FakeFirestore()),
          currentUserIdProvider.overrideWith((ref) => 'current-viewer-uid'),
          userRepositoryProvider.overrideWithValue(
            FakeUserRepository(fakeUser: liveUser),
          ),
          currentUserFollowingIdsProvider.overrideWith(
            (ref) => Stream.value({'author-uid-1'}),
          ),
          currentUserFollowerIdsProvider.overrideWith(
            (ref) => Stream.value(<String>{}),
          ),
        ],
        child: MaterialApp(
          home: RecipeDetailScreen(
            recipe: staleRecipe,
            screenTitle: 'Featured Recipe',
          ),
        ),
      ),
    );

    // First frame
    await tester.pump();
    // Allow loadSocialState post-frame callback to complete without pumpAndSettle timeout
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // The author name should be live updated to "jayzer relator" (displayed in lowercase)
    expect(find.text('jayzer relator'), findsOneWidget);
    expect(find.text('venus relator'), findsNothing);

    // Follow status should reactively read 'following' from currentUserFollowingIdsProvider
    expect(find.text('following'), findsOneWidget);
  });
}
