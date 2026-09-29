import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

/**
 * Automatically cleans up the user document in Firestore when a user is deleted
 * from Firebase Authentication (e.g. via Firebase Console or Admin SDK).
 * This prevents ghost/orphaned user profiles from lingering and causing duplicate
 * search results or broken profile links.
 */
export const onUserDelete = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const db = admin.firestore();

  try {
    const userDocRef = db.collection("users").doc(uid);
    await db.recursiveDelete(userDocRef);
    console.log(`[onUserDelete] Successfully deleted Firestore profile for user ${uid}`);
  } catch (error) {
    console.error(`[onUserDelete] Failed to clean up Firestore profile for user ${uid}:`, error);
  }
});
