/**
 * Keeps a recipe's public like counter authoritative and in sync with its
 * likes subcollection. Recounting is idempotent, so retries cannot inflate
 * the value shown by live recipe listeners.
 */
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

export const onRecipeLikeWrite = onDocumentWritten(
  "likes/{recipeId}/users/{userId}",
  async (event) => {
    const recipeId = event.params.recipeId;
    const db = admin.firestore();
    const recipeRef = db.collection("recipes").doc(recipeId);
    const recipe = await recipeRef.get();
    if (!recipe.exists) return;

    const likes = await db
      .collection("likes")
      .doc(recipeId)
      .collection("users")
      .count()
      .get();
    await recipeRef.update({ likeCount: likes.data().count });
  },
);
