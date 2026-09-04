# Notifications System & Full-App Bug Fixes Design Specification

**Date:** 2026-09-04  
**Status:** Approved  
**Scope:** Architectural & Diagnostic Refactoring  

---

## 1. Overview & Objectives

This specification covers two tightly coupled goals:
1. **Part 1: End-to-End Notification System & Settings Integration**:
   - Establish reliable notification routing so clicking local or FCM push notifications navigates to the target recipe, profile, or meal planner across foreground, background, and cold-start/terminated states.
   - Wire the existing switches in `SettingsScreen` to system notification permissions, local recurring alarms, and user preferences.
   - Deploy a Firebase Cloud Function (`onNotificationCreate`) that sends push notifications to registered device FCM tokens whenever an in-app notification document is created.
2. **Part 2: Full-App Bug Scan Resolution**:
   - Fix critical Firestore Security Rules that block social notification batch writes (`unreadNotificationCount`) and recipe comments (`commentCount`) from non-authors.
   - Resolve compiler warning (unreachable switch case in `auth_error_messages.dart`) and static analysis lints.
   - Ensure meal reminder scheduling respects user preferences.

---

## 2. Notification Architecture & Click Routing

### 2.1 Global Navigation Context
To allow notifications received or tapped outside of active widget build contexts to navigate:
- Define `final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();` in `lib/app/app.dart`.
- Pass `navigatorKey: rootNavigatorKey` to `MaterialApp` in `LaMiaApp`.
- Expose a safe navigation helper: `NotificationRouter.navigateWithPayload(String payload)` that parses payload JSON and performs navigation using `rootNavigatorKey.currentState`.

### 2.2 Standardized Notification Payload
All notifications (Local and FCM Remote) will carry a JSON-encoded payload:
```json
{
  "targetType": "recipe",
  "targetId": "recipe_abc123",
  "targetRoute": "/recipe",
  "notificationId": "notif_xyz"
}
```

### 2.3 Lifecycle Handling
1. **Foreground (`onMessage`)**:
   - `FCMService` receives message and calls `LocalNotificationService.instance.showNotification` with the payload.
   - User tap triggers `onDidReceiveNotificationResponse`, which invokes `NotificationRouter.navigateWithPayload`.
2. **Background (`onMessageOpenedApp`)**:
   - User taps push notification while app is running in background.
   - `FirebaseMessaging.onMessageOpenedApp.listen` triggers and delegates payload to `NotificationRouter.navigateWithPayload`.
3. **Terminated / Cold Start (`getInitialMessage`)**:
   - User taps push notification when app is killed.
   - On startup, `FCMService` checks `FirebaseMessaging.instance.getInitialMessage()`.
   - If present, stores pending payload and dispatches navigation once the root navigator is initialized.

---

## 3. Settings Screen Integration & Local Alarms

### 3.1 Master Toggle (`enableNotifications`)
- **Toggled ON**:
  - Prompts OS permissions via `LocalNotificationService.instance.requestPermissions()`.
  - If granted, saves `enableNotifications: true` to `users/{uid}` in Firestore.
  - If denied by OS, notifies user with `AppSnackbar`, keeps toggle off.
- **Toggled OFF**:
  - Saves `enableNotifications: false` to Firestore.
  - Calls `LocalNotificationService.instance.cancelAllNotifications()` to clear all scheduled alarms.

### 3.2 Granular Toggles
- **`mealReminders`**:
  - **Toggled ON**: Calls `MealPlanRepository.scheduleMealPlanReminders` for current weekly plan.
  - **Toggled OFF**: Cancels scheduled breakfast, lunch, snack, and dinner notification IDs.
- **`dailySuggestions` ("Ano Pong Ulam?")**:
  - **Toggled ON**: Calls `LocalNotificationService.instance.scheduleDailyRepeatingNotification` at 11:00 AM (ID: `99901`, Channel: `daily_suggestions`, Title: `"Ano Pong Ulam? 🍲"`, Body: `"Explore today's featured dish and plan your meal!"`).
  - **Toggled OFF**: Cancels notification ID `99901`.
- **`likes`, `comments`, `followers`, `followingNewRecipes`**:
  - Updated in `users/{uid}.notificationPreferences`. Checked both client-side and server-side before sending push notifications.

---

## 4. Backend Cloud Function (`onNotificationCreate`)

### 4.1 Trigger & Logic
- **File**: `functions/src/onNotificationCreate.ts`
- **Trigger**: `onDocumentCreated("users/{userId}/notifications/{notificationId}")`
- **Execution Flow**:
  1. Fetch recipient document: `users/{userId}`.
  2. Check `enableNotifications == true`. If `false`, exit early.
  3. Verify granular preferences:
     - `recipe_like` / `comment_like` -> `notificationPreferences.likes != false`
     - `recipe_comment` / `comment_reply` -> `notificationPreferences.comments != false`
     - `new_follower` -> `notificationPreferences.followers != false`
     - `following_new_recipe` -> `notificationPreferences.followingNewRecipes != false`
  4. Fetch `fcmTokens: string[]` on user doc. If empty, exit early.
  5. Build `MulticastMessage` with notification title, body, and data payload.
  6. Send via `admin.messaging().sendEachForMulticast(message)`.
  7. Filter responses for unregistered tokens and remove stale tokens using `FieldValue.arrayRemove`.

---

## 5. Security Rules & Full-App Bug Fixes

### 5.1 Firestore Security Rules (`firestore.rules`)
1. **Unread Notification Counter**:
   - In `/users/{uid}`, update `allow update: if ...` to include:
     ```firestore
     || counterIncremented('unreadNotificationCount')
     || counterDecremented('unreadNotificationCount')
     ```
2. **Recipe Comment Counter**:
   - In `/recipes/{id}`, update `allow update: if ...` for signed-in users to include:
     ```firestore
     || counterIncremented('commentCount')
     || counterDecremented('commentCount')
     ```
3. **Decouple Counter Update in Client**:
   - In `NotificationRepository.sendNotification`, write the notification document first or handle counter increment independently so an external profile update cannot prevent notification creation.

### 5.2 Compiler & Lint Fixes
1. **`lib/features/auth/data/auth_error_messages.dart`**:
   - Remove duplicate case `'user-not-found'` on line 38.
2. **`lib/features/auth/data/user_repository.dart`**:
   - Refactor constructor to use `this._firestore` to satisfy `prefer_initializing_formals`.
3. **`lib/features/notifications/services/`**:
   - Resolve double-quote string styling lints in `fcm_service.dart` and `local_notification_service.dart`.

---

## 6. Testing & Verification

1. **Static Analysis**: `flutter analyze` must pass with 0 errors and 0 warnings.
2. **Unit Tests**: `flutter test` must pass all existing 85 tests plus new tests for notification routing and preferences.
3. **TypeScript Build**: `cmd /c npm run build` in `lamia_app/functions` must compile cleanly without errors.
4. **Security Rules Validation**: Firestore emulator or rules check ensuring comment writes and notification creation pass.
