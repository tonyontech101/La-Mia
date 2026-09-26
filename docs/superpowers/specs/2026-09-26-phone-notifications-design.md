# Phone Notifications Design Specification

**Date:** 2026-09-26  
**Status:** Approved  
**Scope:** Native Android & Firebase Cloud Notification Pipeline  

---

## 1. Problem Statement & Root Cause

Currently, notifications are only visible inside the app's notification tab and unread badge. They do not appear on the phone (Android status bar, heads-up banner, or lock screen) when the app is minimized, closed, or active.

### Specific Root Causes Identified:
1. **Cloud Function Not Deployed:** While `onNotificationCreate.ts` is implemented in `functions/src/onNotificationCreate.ts`, only `onRecipeCreate` is deployed to Firebase Cloud Functions. Social events (likes, comments, follows) write to Firestore, but no backend push trigger ever executes to dispatch FCM messages.
2. **Missing Android Push & Channel Configuration in FCM Payload:** `onNotificationCreate.ts` does not attach `android.notification.channelId = 'system_updates'`, priority, or default sound. Furthermore, `AndroidManifest.xml` does not define `com.google.firebase.messaging.default_notification_channel_id` or default notification icons. Android 8.0+ silences or drops notifications lacking a valid channel.
3. **FCM Token Lifecycle Gaps:** `syncToken()` in `fcm_service.dart` is only called once during app boot in `main.dart`. If the user is unauthenticated at startup (or logs in later), `currentUser` is null, so the token is never written to Firestore. As a result, `userData.fcmTokens` in Firestore remains empty.
4. **Missing Android Exact Alarm & Boot Persistence:** Local meal planner reminders (`zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle`) require `android.permission.SCHEDULE_EXACT_ALARM` on Android 12+ (API 31+). Additionally, `ScheduledNotificationBootReceiver` is not declared in `AndroidManifest.xml`, meaning device reboots wipe all scheduled meal reminders.

---

## 2. Architecture & Component Design

```
+---------------------------------------------------------------------------------+
|                                1. Social Trigger                                |
|  User A likes/comments/follows -> Client writes to users/{userId}/notifications |
+---------------------------------------------------------------------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                       2. Firebase Cloud Functions (Backend)                     |
|  - onNotificationCreate trigger intercepts Firestore document creation          |
|  - Verifies enableNotifications & granular preferences (likes, comments, etc.)  |
|  - Retrieves recipient fcmTokens array from users/{userId}                      |
|  - Dispatches FCM multicast with Android high priority & channelId              |
+---------------------------------------------------------------------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                           3. Android Operating System                           |
|  - System Tray / Status Bar / Lock Screen handles FCM notification payload       |
|  - Posts to 'system_updates' notification channel with vibration & sound         |
|  - Foreground listener pops heads-up banner via LocalNotificationService        |
+---------------------------------------------------------------------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                       4. User Interaction & Deep Linking                        |
|  - User taps notification in Android notification shade                         |
|  - App launches / resumes -> NotificationRouter routes to recipe/comment/profile|
+---------------------------------------------------------------------------------+
```

### Components:
1. **Firebase Cloud Functions (`onNotificationCreate.ts`):**
   - Updates FCM Multicast message structure to include `android` configuration:
     - `android: { priority: 'high', notification: { channelId: 'system_updates', sound: 'default', clickAction: 'FLUTTER_NOTIFICATION_CLICK' } }`.
     - `apns: { payload: { aps: { sound: 'default', badge: 1 } } }`.
   - Cleans up stale/invalid tokens when FCM returns token errors.
2. **Flutter FCM Client (`fcm_service.dart`):**
   - Listens to `FirebaseAuth.instance.authStateChanges()` to automatically invoke `syncToken()` whenever a user signs in.
   - Listens to `_fcm.onTokenRefresh` to keep Firestore updated.
   - Cleans up tokens on logout via `clearTokenOnLogout()`.
   - On Android 13+, requests notification permissions proactively during onboarding or auth.
3. **Local Notification Service (`local_notification_service.dart`):**
   - Configures 4 Android notification channels: `meal_reminders`, `cooking_timers`, `daily_suggestions`, `system_updates`.
   - Schedules timezone-aware alarms for breakfast (7:30 AM), lunch (11:30 AM), snack (3:00 PM), dinner (6:30 PM), and daily "Ano Pong Ulam?" (11:00 AM).
4. **Android Native Configuration (`AndroidManifest.xml`):**
   - Declares `SCHEDULE_EXACT_ALARM` permission.
   - Declares `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` for boot survival.
   - Adds FCM metadata for default notification channel (`system_updates`) and default notification icon (`@mipmap/ic_launcher`).

---

## 3. Detailed Data & Payload Specifications

### 3.1 FCM Message Structure
```typescript
const message: admin.messaging.MulticastMessage = {
  tokens: fcmTokens,
  notification: {
    title: notifData.title || "La Mia",
    body: notifData.body || "",
    ...(notifData.imageUrl ? { imageUrl: String(notifData.imageUrl) } : {}),
  },
  data: {
    notificationId: notificationId || "",
    type: String(notifData.type || ""),
    targetType: String(notifData.targetType || ""),
    targetId: String(notifData.targetId || ""),
    route: String(notifData.targetRoute || notifData.route || ""),
    senderId: String(notifData.senderId || ""),
    senderName: String(notifData.senderName || ""),
  },
  android: {
    priority: "high",
    notification: {
      channelId: "system_updates",
      sound: "default",
      clickAction: "FLUTTER_NOTIFICATION_CLICK",
      priority: "high",
    },
  },
};
```

### 3.2 AndroidManifest.xml Additions
```xml
<!-- Exact alarm permissions for meal reminders on Android 12+ -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

<!-- FCM Default Channel & Icon Metadata -->
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="system_updates" />
<meta-data
    android:name="com.google.firebase.messaging.default_notification_icon"
    android:resource="@mipmap/ic_launcher" />

<!-- Boot Receivers for flutter_local_notifications -->
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

---

## 4. Error Handling & Edge Cases

1. **User Logs Out:** `clearTokenOnLogout()` removes the current device token from `users/{userId}/fcmTokens` in Firestore so the device stops receiving push notifications for that account.
2. **Invalid or Expired Tokens:** Cloud Function catches `messaging/invalid-registration-token` or `messaging/registration-token-not-registered` and prunes them from the user document using `FieldValue.arrayRemove`.
3. **Do Not Disturb / Notification Channels Muted:** Android OS channel settings give users granular control. App channels are mapped to user preferences so muting in-app or via Android system settings functions consistently.
4. **App Killed / Cold Start Tap:** `NotificationRouter` checks `getInitialMessage()` from FCM and launch details from `flutter_local_notifications` during post-frame callback to ensure routing occurs once the widget tree is ready.
5. **Exact Alarm Denied (Android 14+):** If exact alarm scheduling is restricted by system battery policies, `flutter_local_notifications` falls back gracefully without crashing.

---

## 5. Deployment & Verification Plan

1. **Backend Deployment:**
   - Compile TypeScript Cloud Functions (`npm --prefix functions run build`).
   - Deploy `onNotificationCreate` using `firebase deploy --only functions:onNotificationCreate --project la-mia-e348d`.
   - Verify active status in `firebase functions:list`.
2. **Flutter Codebase Changes:**
   - Update `fcm_service.dart` to listen to auth state changes and sync token immediately on login.
   - Update `AndroidManifest.xml` with channel metadata, exact alarm permissions, and boot receivers.
   - Run `flutter analyze` to ensure zero compilation or lint errors.
3. **End-to-End Verification:**
   - Trigger a notification (e.g. like a recipe from another test account or trigger a meal reminder).
   - Verify phone displays notification banner/status bar item when app is in foreground.
   - Minimize app (background) and lock screen (terminated) to verify phone notification displays in system shade with sound and vibration.
   - Tap notification and verify navigation directly to target screen.
