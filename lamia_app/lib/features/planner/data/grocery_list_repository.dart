import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/app_logger.dart';
import '../../recipes/data/recipe_model.dart';

class GroceryItem {
  GroceryItem({
    required this.id,
    required this.name,
    this.recipeId,
    this.recipeName,
    required this.checked,
    this.addedAt,
  });

  final String id;
  final String name;
  final String? recipeId;
  final String? recipeName;
  final bool checked;
  final DateTime? addedAt;

  factory GroceryItem.fromFirestore(Map<String, dynamic> data, String id) {
    return GroceryItem(
      id: id,
      name: data['name'] as String? ?? '',
      recipeId: data['recipeId'] as String?,
      recipeName: data['recipeName'] as String?,
      checked: data['checked'] as bool? ?? false,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (recipeId != null) 'recipeId': recipeId,
      if (recipeName != null) 'recipeName': recipeName,
      'checked': checked,
      'addedAt': addedAt ?? FieldValue.serverTimestamp(),
    };
  }
}

class GroceryListRepository {
  GroceryListRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _groceryCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('grocery_items');
  }

  /// Adds ingredients from a recipe to the user's persistent grocery list.
  Future<void> addIngredientsFromRecipe({
    required String userId,
    required RecipeModel recipe,
  }) async {
    try {
      await addIngredients(
        userId: userId,
        ingredients: recipe.ingredients,
        recipeId: recipe.id,
        recipeName: recipe.name,
      );
    } catch (e, stack) {
      AppLogger.error(
        'Failed to add recipe ingredients to grocery list',
        error: e,
        stackTrace: stack,
        category: 'GROCERY_LIST',
      );
      rethrow;
    }
  }

  /// Batch adds a list of ingredient names directly to the user's grocery list.
  Future<void> addIngredients({
    required String userId,
    required List<String> ingredients,
    String? recipeId,
    String? recipeName,
  }) async {
    try {
      final batch = _firestore.batch();
      final col = _groceryCollection(userId);

      for (final ingredient in ingredients) {
        if (ingredient.trim().isEmpty) continue;
        final docRef = col.doc();
        batch.set(docRef, {
          'name': ingredient.trim(),
          if (recipeId != null) 'recipeId': recipeId,
          if (recipeName != null) 'recipeName': recipeName,
          'checked': false,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e, stack) {
      AppLogger.error(
        'Failed to batch add ingredients',
        error: e,
        stackTrace: stack,
        category: 'GROCERY_LIST',
      );
      rethrow;
    }
  }

  /// Stream of user's grocery items ordered by addedAt.
  Stream<List<GroceryItem>> watchGroceryItems(String userId) {
    return _groceryCollection(userId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroceryItem.fromFirestore(doc.data(), doc.id))
            .toList())
        .handleError((e, stack) {
      AppLogger.error(
        'Error streaming grocery items',
        error: e,
        stackTrace: stack is StackTrace ? stack : null,
        category: 'GROCERY_LIST',
      );
    });
  }

  /// Toggles the checked status of a grocery item.
  Future<void> toggleItemChecked({
    required String userId,
    required String itemId,
    required bool checked,
  }) async {
    try {
      await _groceryCollection(userId).doc(itemId).update({'checked': checked});
    } catch (e, stack) {
      AppLogger.error(
        'Failed to toggle grocery item checked status',
        error: e,
        stackTrace: stack,
        category: 'GROCERY_LIST',
      );
      rethrow;
    }
  }

  /// Deletes a specific grocery item.
  Future<void> deleteItem({
    required String userId,
    required String itemId,
  }) async {
    try {
      await _groceryCollection(userId).doc(itemId).delete();
    } catch (e, stack) {
      AppLogger.error(
        'Failed to delete grocery item',
        error: e,
        stackTrace: stack,
        category: 'GROCERY_LIST',
      );
      rethrow;
    }
  }

  /// Clears all checked grocery items.
  Future<void> clearCheckedItems(String userId) async {
    try {
      final snap = await _groceryCollection(userId)
          .where('checked', isEqualTo: true)
          .get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear checked grocery items',
        error: e,
        stackTrace: stack,
        category: 'GROCERY_LIST',
      );
      rethrow;
    }
  }

  /// Clears the entire grocery list.
  Future<void> clearAllItems(String userId) async {
    try {
      final snap = await _groceryCollection(userId).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e, stack) {
      AppLogger.error(
        'Failed to clear all grocery items',
        error: e,
        stackTrace: stack,
        category: 'GROCERY_LIST',
      );
      rethrow;
    }
  }
}
