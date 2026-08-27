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
    const newLikeCount = likes.data().count;
    await recipeRef.update({ likeCount: newLikeCount });

    // Recount and sync author's total likes received across all their recipe posts
    const authorId = recipe.data()?.authorId;
    if (authorId) {
      const authorRecipes = await db
        .collection("recipes")
        .where("authorId", "==", authorId)
        .get();
      let totalLikes = 0;
      authorRecipes.forEach((doc) => {
        if (doc.id === recipeId) {
          totalLikes += newLikeCount;
        } else {
          totalLikes += ((doc.data().likeCount as number) || 0);
        }
      });
      await db.collection("users").doc(authorId).set(
        { totalLikesReceived: totalLikes },
        { merge: true },
      );
    }
  },
);
