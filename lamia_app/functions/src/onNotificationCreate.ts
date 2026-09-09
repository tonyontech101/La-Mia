/**
 * onNotificationCreate — Firestore onCreate trigger for push notifications.
 *
 * Triggered when a new document is written to `users/{userId}/notifications/{notificationId}`.
 * This function:
 * 1. Checks if the recipient exists and has notifications enabled.
 * 2. Checks granular notification preferences based on notification type.
 * 3. Retrieves registered FCM device tokens.
 * 4. Dispatches push notification via Firebase Admin FCM multicast.
 * 5. Cleans up any invalid or expired FCM tokens.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

// Ensure Firebase Admin SDK is initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

export const onNotificationCreate = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data in notification snapshot, skipping.");
      return;
    }

    const notifData = snapshot.data();
    if (!notifData) {
      console.log("Empty notification data, skipping.");
      return;
    }

    const userId = event.params.userId;
    const notificationId = event.params.notificationId;

    const db = admin.firestore();
    const userRef = db.collection("users").doc(userId);
    const userSnap = await userRef.get();

    // 1. Check recipient user doc exists
    if (!userSnap.exists) {
      console.log(`Recipient user ${userId} does not exist, skipping.`);
      return;
    }

    const userData = userSnap.data();
    if (!userData) {
      return;
    }

    // 2. Check global notification preference
    if (userData.enableNotifications === false) {
      console.log(`User ${userId} has disabled all notifications.`);
      return;
    }

    // 3. Check granular preferences matching notification type
    const prefs = userData.notificationPreferences;
    const type = notifData.type as string | undefined;

    if (type === "recipe_like" || type === "comment_like") {
      if (prefs?.likes === false) {
        console.log(`User ${userId} has disabled like notifications.`);
        return;
      }
    } else if (type === "recipe_comment" || type === "comment_reply") {
      if (prefs?.comments === false) {
        console.log(`User ${userId} has disabled comment notifications.`);
        return;
      }
    } else if (type === "new_follower") {
      if (prefs?.followers === false) {
        console.log(`User ${userId} has disabled follower notifications.`);
        return;
      }
    } else if (type === "following_new_recipe") {
      if (prefs?.followingNewRecipes === false) {
        console.log(`User ${userId} has disabled following new recipe notifications.`);
        return;
      }
    } else if (type === "meal_reminder") {
      if (prefs?.mealReminders === false) {
        console.log(`User ${userId} has disabled meal reminder notifications.`);
        return;
      }
    } else if (type === "daily_suggestion") {
      if (prefs?.dailySuggestions === false) {
        console.log(`User ${userId} has disabled daily suggestion notifications.`);
        return;
      }
    }

    // 4. Retrieve FCM tokens
    const rawTokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];
    const fcmTokens: string[] = rawTokens.filter(
      (token: unknown): token is string =>
        typeof token === "string" && token.trim().length > 0
    );

    if (fcmTokens.length === 0) {
      console.log(`User ${userId} has no registered FCM tokens.`);
      return;
    }

    // 5. Construct multicast message
    const dataPayload: Record<string, string> = {
      notificationId: notificationId || "",
      type: notifData.type ? String(notifData.type) : "",
      targetType: notifData.targetType ? String(notifData.targetType) : "",
      targetId: notifData.targetId ? String(notifData.targetId) : "",
      route: notifData.targetRoute
        ? String(notifData.targetRoute)
        : notifData.route
        ? String(notifData.route)
        : "",
    };

    if (notifData.senderId) {
      dataPayload.senderId = String(notifData.senderId);
    }
    if (notifData.senderName) {
      dataPayload.senderName = String(notifData.senderName);
    }

    const message: admin.messaging.MulticastMessage = {
      tokens: fcmTokens,
      notification: {
        title: (notifData.title as string) || "La Mia",
        body: (notifData.body as string) || "",
        ...(notifData.imageUrl ? { imageUrl: String(notifData.imageUrl) } : {}),
      },
      data: dataPayload,
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        `FCM multicast sent for user ${userId} (${notificationId}): ` +
          `${response.successCount} succeeded, ${response.failureCount} failed.`
      );

      // 6. Clean up invalid / expired tokens
      if (response.failureCount > 0) {
        const staleTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered" ||
              errorCode === "messaging/invalid-argument"
            ) {
              staleTokens.push(fcmTokens[idx]);
            }
          }
        });

        if (staleTokens.length > 0) {
          console.log(
            `Pruning ${staleTokens.length} invalid/stale FCM token(s) for user ${userId}`
          );
          await userRef.update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
          });
        }
      }
    } catch (error) {
      console.error(`Error sending push notification to user ${userId}:`, error);
    }
  }
);
