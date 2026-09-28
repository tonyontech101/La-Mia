# Phone Notifications Design Specification

**Date:** 2026-09-26  
**Status:** Implemented  
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

### 5.1 Completed Implementation Milestones
- **Android Manifest & Permissions:** `SCHEDULE_EXACT_ALARM`, `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`, and default FCM channel metadata (`system_updates`) configured in `AndroidManifest.xml`.
- **Cloud Functions:** `onNotificationCreate` updated with high-priority Android & APNs payload and deployed to Firebase project `la-mia-e348d` (active in Cloud Functions v2).
- **Client Token Lifecycle:** `fcm_service.dart` integrated with `FirebaseAuth.instance.authStateChanges()` to automatically register FCM tokens on login and remove tokens on logout before session revocation.
- **Unit & Static Analysis:** Verified with zero analyzer issues across `lamia_app` and 100% pass rate across test suite.

---

## 6. Operational Manual Device Verification Procedures

This operational test guide provides exact steps for engineers and QA to manually verify push and local notifications on physical Android devices or Google Play emulators.

### 6.1 Prerequisites
1. Physical Android device (or Google Play emulator) running Android 8.0+ (API 26 through Android 14+ / API 34).
2. Google Play Services active and up to date on the device.
3. On Android 13+ (API 33+), ensure runtime notification permission (`POST_NOTIFICATIONS`) is granted in device App Settings -> Notifications.
4. On Android 12+ (API 31+), ensure "Alarms & Reminders" (`SCHEDULE_EXACT_ALARM`) is permitted in device Special App Access settings.

---

### 6.2 Scenario A: Cloud FCM Push Notification (Social Interactions)

#### Test Case A1: Auth State Token Registration
1. Launch `La Mia` on the test device.
2. Sign in with test account (e.g. `User A` / `alice@example.com`).
3. Open Firebase Console -> Firestore -> `users/{userA_Id}`.
4. **Verification:**
   - Confirm that the `fcmTokens` field exists as an array of strings.
   - Confirm that the device's current FCM token is listed in `fcmTokens`.

#### Test Case A2: Foreground Heads-Up Notification
1. Keep the app open and visible on screen (Foreground state).
2. From a second device (or Firebase Console / test script), trigger a new notification under `users/{userA_Id}/notifications/{docId}`:
   ```json
   {
     "title": "New Comment",
     "body": "User B commented on your Pork Adobo recipe!",
     "type": "comment",
     "targetType": "recipe",
     "targetId": "sample_recipe_123",
     "targetRoute": "/recipe/sample_recipe_123",
     "senderId": "user_b_id",
     "senderName": "User B",
     "createdAt": "2026-09-26T12:00:00Z"
   }
   ```
3. **Verification:**
   - The Cloud Function `onNotificationCreate` triggers in `us-central1`.
   - A heads-up banner notification immediately appears at the top of the device screen.
   - Default sound and vibration trigger.
   - Tapping the notification heads-up banner navigates directly to `/recipe/sample_recipe_123`.

#### Test Case A3: Background System Notification Shade
1. Press the **Home** button on the device (app minimized to Background).
2. Trigger another notification document in `users/{userA_Id}/notifications`.
3. **Verification:**
   - An app notification icon appears in the Android Status Bar.
   - Pulling down the Android notification shade reveals the notification card under the `system_updates` category.
   - Tapping the notification resumes the app and opens the target destination.

#### Test Case A4: Terminated / Cold-Start Push Delivery
1. Open the device's Recent Apps carousel and **swipe away** `La Mia` to completely terminate the process.
2. Lock the device screen (optional) or leave on home screen.
3. Create a notification document in `users/{userA_Id}/notifications`.
4. **Verification:**
   - The system displays the push notification on the Lock Screen / Status Bar without requiring the app process to be running beforehand.
   - Tapping the notification launches the app cold and executes post-frame routing to the target screen.

#### Test Case A5: Sign-Out Token Cleanup
1. Open `La Mia` and sign out of `User A`.
2. Inspect `users/{userA_Id}` in Firebase Firestore Console.
3. **Verification:**
   - The device FCM registration token is pruned from the `fcmTokens` array.
   - Subsequent notifications created under `users/{userA_Id}/notifications` do not deliver push notifications to this device.

---

### 6.3 Scenario B: Scheduled Local Meal Reminders

#### Test Case B1: Schedule Meal Planner Reminder
1. Open the app and navigate to **Meal Planner** or **Settings -> Notifications**.
2. Ensure meal reminder switches are toggled **ON** (Breakfast: 7:30 AM, Lunch: 11:30 AM, Snack: 3:00 PM, Dinner: 6:30 PM, Ano Pong Ulam: 11:00 AM).
3. To test immediately, adjust the device clock or schedule a reminder 2 minutes in the future.
4. Put the device to sleep / lock screen.
5. **Verification:**
   - At the exact scheduled time, the device vibrates and displays the meal reminder notification banner from the `meal_reminders` channel (`AndroidScheduleMode.exactAllowWhileIdle`).

#### Test Case B2: Device Reboot Persistence
1. With meal reminders scheduled, completely restart/reboot the Android device.
2. Once booted and unlocked, do NOT open `La Mia`.
3. **Verification:**
   - The `ScheduledNotificationBootReceiver` receives `android.intent.action.BOOT_COMPLETED` and `flutter_local_notifications` restores all exact alarms in the Android `AlarmManager`.
   - When the next reminder time arrives, the notification fires as expected without needing manual app launch.

