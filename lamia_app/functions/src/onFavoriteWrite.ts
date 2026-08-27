/**
 * Keeps a recipe's favorite counter authoritative and in sync with its
 * favorites subcollection. Recounting is idempotent, so retries cannot
 * inflate the value shown by live recipe listeners.
 */
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

export const onFavoriteWrite = onDocumentWritten(
  "favorites/{userId}/items/{recipeId}",
  async (event) => {
    const recipeId = event.params.recipeId;
    const db = admin.firestore();
    const recipeRef = db.collection("recipes").doc(recipeId);
    const recipe = await recipeRef.get();
    if (!recipe.exists) return;

    const favorites = await db
      .collectionGroup("items")
      .where("recipeId", "==", recipeId)
      .count()
      .get();
    await recipeRef.update({ favoriteCount: favorites.data().count });
  },
);
