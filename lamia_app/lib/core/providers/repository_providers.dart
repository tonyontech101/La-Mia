import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/user_repository.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/planner/data/grocery_list_repository.dart';
import '../../features/planner/data/meal_plan_repository.dart';
import '../../features/recipes/data/recipe_repository.dart';
import '../../features/social/data/comment_repository.dart';
import '../../features/social/data/favorites_repository.dart';
import '../../features/social/data/follow_repository.dart';
import '../../features/social/data/like_repository.dart';
import '../../features/social/data/rating_repository.dart';
import 'firebase_providers.dart';

part 'repository_providers.g.dart';

@Riverpod(keepAlive: true)
RecipeRepository recipeRepository(RecipeRepositoryRef ref) =>
    RecipeRepository(firestore: ref.watch(firebaseFirestoreProvider));

@Riverpod(keepAlive: true)
NotificationRepository notificationRepository(
        NotificationRepositoryRef ref) =>
    NotificationRepository(firestore: ref.watch(firebaseFirestoreProvider));

@Riverpod(keepAlive: true)
UserRepository userRepository(UserRepositoryRef ref) =>
    UserRepository(firestore: ref.watch(firebaseFirestoreProvider));

@Riverpod(keepAlive: true)
RatingRepository ratingRepository(RatingRepositoryRef ref) =>
    RatingRepository(firestore: ref.watch(firebaseFirestoreProvider));

@Riverpod(keepAlive: true)
GroceryListRepository groceryListRepository(GroceryListRepositoryRef ref) =>
    GroceryListRepository(firestore: ref.watch(firebaseFirestoreProvider));

@Riverpod(keepAlive: true)
CommentRepository commentRepository(CommentRepositoryRef ref) =>
    CommentRepository(
      firestore: ref.watch(firebaseFirestoreProvider),
      notificationRepository: ref.watch(notificationRepositoryProvider),
    );

@Riverpod(keepAlive: true)
LikeRepository likeRepository(LikeRepositoryRef ref) => LikeRepository(
      firestore: ref.watch(firebaseFirestoreProvider),
      recipeRepository: ref.watch(recipeRepositoryProvider),
      notificationRepository: ref.watch(notificationRepositoryProvider),
    );

@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(FavoritesRepositoryRef ref) =>
    FavoritesRepository(
      firestore: ref.watch(firebaseFirestoreProvider),
      recipeRepository: ref.watch(recipeRepositoryProvider),
    );

@Riverpod(keepAlive: true)
FollowRepository followRepository(FollowRepositoryRef ref) => FollowRepository(
      firestore: ref.watch(firebaseFirestoreProvider),
      notificationRepository: ref.watch(notificationRepositoryProvider),
    );

@Riverpod(keepAlive: true)
MealPlanRepository mealPlanRepository(MealPlanRepositoryRef ref) =>
    MealPlanRepository(
      firestore: ref.watch(firebaseFirestoreProvider),
      auth: ref.watch(firebaseAuthProvider),
      recipeRepo: ref.watch(recipeRepositoryProvider),
    );
