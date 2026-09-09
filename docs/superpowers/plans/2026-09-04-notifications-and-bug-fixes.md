# Notifications System & Full-App Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the end-to-end notification system (push triggers, click navigation, settings wire-up, local reminder lifecycle) and resolve all identified critical bugs and static analysis warnings across the application.

**Architecture:** 
A hybrid notification model combining client-side local notification scheduling and routing with server-side Firebase Cloud Functions and Firestore rules. Tapping local or push notifications triggers deep linking through a top-level `GlobalKey<NavigatorState>` into `NotificationRouter`. `SettingsScreen` directly controls OS permissions and notification alarms. `firestore.rules` is updated to allow external counter updates for notification badge counts and recipe comments.

**Tech Stack:** Flutter, Dart, Riverpod, Firebase Cloud Messaging (FCM), flutter_local_notifications, Cloud Firestore, Firebase Cloud Functions (TypeScript / Node 20).

**Spec:** [docs/superpowers/specs/2026-09-04-notifications-and-bug-fixes-design.md](file:///C:/Users/My%20PC/OneDrive/Documents/LaMia/docs/superpowers/specs/2026-09-04-notifications-and-bug-fixes-design.md)

## Global Constraints
- Target Flutter app path: `lamia_app/`
- Target Functions path: `lamia_app/functions/`
- Must maintain 0 compiler warnings/errors in `flutter analyze`.
- All 85 existing tests in `flutter test` must continue to pass without regression.
- Shell commands in Windows PowerShell must use `;` for command chaining instead of `&&`.

---

### Task 1: Fix Critical Security Rules & Static Analysis Warnings

**Files:**
- Modify: `lamia_app/firestore.rules:140-150` and `lamia_app/firestore.rules:200-220`
- Modify: `lamia_app/lib/features/auth/data/auth_error_messages.dart:35-43`
- Modify: `lamia_app/lib/features/auth/data/user_repository.dart:9-13`
- Modify: `lamia_app/lib/features/notifications/data/notification_repository.dart:103-115`

**Interfaces:**
- Produces: Permissive Firestore security rules for `commentCount` and `unreadNotificationCount` increments/decrements; clean `flutter analyze` without unreachable cases or constructor formal warnings.

- [ ] **Step 1: Update `firestore.rules` to permit recipe comment counter & user unread notification counter updates**

In `lamia_app/firestore.rules`:
1. In `match /recipes/{id}`, add `counterIncremented('commentCount')` and `counterDecremented('commentCount')` under `allow update: if ( ... || (isSignedIn() && (...)))`:
```firestore
          && (
            counterIncremented('likeCount')
            || counterDecremented('likeCount')
            || counterIncremented('favoriteCount')
            || counterDecremented('favoriteCount')
            || counterIncremented('commentCount')
            || counterDecremented('commentCount')
          )
```
Also remove `'commentCount'` from `notSettingServerFieldsOnUpdate()` so counter increments are not blocked by the server-fields check.

2. In `match /users/{uid}`, add `counterIncremented('unreadNotificationCount')` and `counterDecremented('unreadNotificationCount')` under `allow update: if ( ... || (isSignedIn() && (...)))`:
```firestore
            || counterIncremented('totalLikesReceived')
            || counterDecremented('totalLikesReceived')
            || counterIncremented('savedCount')
            || counterDecremented('savedCount')
            || counterIncremented('unreadNotificationCount')
            || counterDecremented('unreadNotificationCount')
```

- [ ] **Step 2: Decouple counter update in `NotificationRepository.sendNotification`**

In `lamia_app/lib/features/notifications/data/notification_repository.dart`:
Write the notification document first. If updating the user document `unreadNotificationCount` fails, catch and log rather than aborting the entire notification write:
```dart
    // Write the notification doc first
    await docRef.set(notif.toFirestore());

    // Update denormalized counter on user profile defensively
    try {
      final userRef = _firestore.collection('users').doc(recipientId);
      await userRef.set(
        {'unreadNotificationCount': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    } catch (e) {
      // Counter update non-fatal; notification is already stored
    }
```

- [ ] **Step 3: Fix duplicate case in `auth_error_messages.dart` and constructor lint in `user_repository.dart`**

In `lamia_app/lib/features/auth/data/auth_error_messages.dart`:
Remove lines 38-39 (`'user-not-found' => ...`).

In `lamia_app/lib/features/auth/data/user_repository.dart`:
Change line 10 to:
```dart
  UserRepository({FirebaseFirestore? firestore}) : _firestore = firestore;
```
to use initializing formal:
```dart
  UserRepository({this.firestore}) : _firestore = firestore;
```
or keep `UserRepository({FirebaseFirestore? firestore})` properly formatted.

- [ ] **Step 4: Run `flutter analyze` to verify warnings are cleared**

Run in `lamia_app/`: `flutter analyze`
Expected: 0 warnings, unreachable_switch_case eliminated.

- [ ] **Step 5: Commit changes**

```bash
git add lamia_app/firestore.rules lamia_app/lib/features/auth/data/auth_error_messages.dart lamia_app/lib/features/auth/data/user_repository.dart lamia_app/lib/features/notifications/data/notification_repository.dart
git commit -m "fix: resolve firestore counter rules and static analysis warnings"
```

---

### Task 2: Implement Global Navigation Key & Deep Link Routing

**Files:**
- Modify: `lamia_app/lib/app/app.dart`
- Modify: `lamia_app/lib/features/notifications/services/notification_router.dart`
- Modify: `lamia_app/lib/features/notifications/services/local_notification_service.dart`
- Modify: `lamia_app/lib/features/notifications/services/fcm_service.dart`
- Create: `lamia_app/test/notification_router_test.dart`

**Interfaces:**
- Produces: `rootNavigatorKey` in `app.dart`, `NotificationRouter.navigateWithPayload(String rawPayload)`, and registered handlers for `onDidReceiveNotificationResponse`, `onMessageOpenedApp`, and `getInitialMessage`.

- [ ] **Step 1: Write unit test for payload parsing in `test/notification_router_test.dart`**

Create `lamia_app/test/notification_router_test.dart`:
Verify that JSON strings representing recipe, planner, profile, and achievement notifications are correctly parsed into `NotificationModel` or routing actions.

- [ ] **Step 2: Add `rootNavigatorKey` to `lib/app/app.dart`**

In `lamia_app/lib/app/app.dart`:
```dart
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
```
In `MaterialApp`:
```dart
navigatorKey: rootNavigatorKey,
```

- [ ] **Step 3: Update `NotificationRouter` to support navigation via `rootNavigatorKey`**

In `lamia_app/lib/features/notifications/services/notification_router.dart`:
Add:
```dart
static Future<void> navigateWithPayload(String rawPayload) async {
  try {
    final data = jsonDecode(rawPayload) as Map<String, dynamic>;
    final targetTypeStr = data['targetType'] as String? ?? data['route'] as String?;
    final targetId = data['targetId'] as String?;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    if (targetTypeStr == 'recipe' || targetTypeStr == '/recipe') {
      if (targetId != null && targetId.isNotEmpty) {
        _navigateToRecipe(context, targetId);
      }
    } else if (targetTypeStr == 'planner' || targetTypeStr == '/planner') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WeeklyMealPlannerScreen()),
      );
    } else if (targetTypeStr == 'user' || targetTypeStr == '/user') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(targetUserId: targetId)),
      );
    } else if (targetTypeStr == 'achievement' || targetTypeStr == '/achievement') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AchievementsScreen()),
      );
    }
  } catch (e) {
    debugPrint('Error navigating with payload: $e');
  }
}
```

- [ ] **Step 4: Wire click handlers in `LocalNotificationService` and `FCMService`**

In `lamia_app/lib/features/notifications/services/local_notification_service.dart`:
Update `_onDidReceiveNotificationResponse`:
```dart
  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null && response.payload!.isNotEmpty) {
      NotificationRouter.navigateWithPayload(response.payload!);
    }
  }
```
In `lamia_app/lib/features/notifications/services/fcm_service.dart`:
Add listeners for `FirebaseMessaging.onMessageOpenedApp` and cold-start `FirebaseMessaging.instance.getInitialMessage()`.

- [ ] **Step 5: Run tests to verify pass**

Run: `flutter test test/notification_router_test.dart`
Expected: PASS

- [ ] **Step 6: Commit changes**

```bash
git add lamia_app/lib/app/app.dart lamia_app/lib/features/notifications/services/ lamia_app/test/notification_router_test.dart
git commit -m "feat: wire global navigation key and notification click routing"
```

---

### Task 3: Wire Settings Screen to Local Notification Alarms & Preferences

**Files:**
- Modify: `lamia_app/lib/features/profile/presentation/settings_screen.dart`
- Modify: `lamia_app/lib/features/planner/data/meal_plan_repository.dart`
- Modify: `lamia_app/lib/features/notifications/services/local_notification_service.dart`

**Interfaces:**
- Consumes: `LocalNotificationService.requestPermissions()`, `cancelAllNotifications()`, `cancelNotification()`, `scheduleDailyRepeatingNotification()`
- Produces: Functional master switch, meal reminder alarms toggle, and daily "Ano Pong Ulam?" recurring notifications.

- [ ] **Step 1: Add daily suggestion scheduler to `LocalNotificationService`**

In `LocalNotificationService`:
Add helper method:
```dart
static const int dailySuggestionNotificationId = 99901;

Future<void> scheduleDailySuggestion() async {
  await scheduleDailyRepeatingNotification(
    id: dailySuggestionNotificationId,
    title: 'Ano Pong Ulam? 🍲',
    body: 'Time to plan or discover today\'s delicious Filipino dishes!',
    time: const TimeOfDay(hour: 11, minute: 0),
    channelId: 'daily_suggestions',
    channelName: 'Daily Meal Suggestions',
    payload: jsonEncode({'targetType': 'planner', 'route': '/planner'}),
  );
}

Future<void> cancelDailySuggestion() async {
  await cancelNotification(dailySuggestionNotificationId);
}
```

- [ ] **Step 2: Connect Settings Screen master toggle & granular toggles**

In `lamia_app/lib/features/profile/presentation/settings_screen.dart`:
1. In `_onToggleNotifications(bool value)`:
   - If `value == true`:
     Call `await LocalNotificationService.instance.requestPermissions()`.
     If permission denied, show `AppSnackbar` warning: "Notification permission was not granted by your device." and keep switch false.
     If granted, save `enableNotifications: true` to Firestore and reschedule active alarms.
   - If `value == false`:
     Save `enableNotifications: false` to Firestore.
     Call `await LocalNotificationService.instance.cancelAllNotifications()`.
2. In `_onUpdateGranularPreference(String key, bool value)`:
   - When `key == 'dailySuggestions'`:
     If `value == true`, call `LocalNotificationService.instance.scheduleDailySuggestion()`.
     If `value == false`, call `LocalNotificationService.instance.cancelDailySuggestion()`.
   - When `key == 'mealReminders'`:
     If `value == false`, cancel meal reminder notification IDs.
     If `value == true`, trigger `scheduleMealPlanReminders()` on the active plan.

- [ ] **Step 3: Guard `scheduleMealPlanReminders` in `meal_plan_repository.dart`**

In `lamia_app/lib/features/planner/data/meal_plan_repository.dart`:
Before scheduling alarms, check:
```dart
final userDoc = await _firestore.collection('users').doc(userId).get();
final enableNotifications = userDoc.data()?['enableNotifications'] as bool? ?? true;
final prefs = NotificationPreferenceModel.fromMap(userDoc.data()?['notificationPreferences'] as Map<String, dynamic>?);
if (!enableNotifications || !prefs.mealReminders) {
  // Cancel all meal reminder notifications and return
  ...
}
```

- [ ] **Step 4: Run flutter tests to verify no breakage**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 5: Commit changes**

```bash
git add lamia_app/lib/features/profile/presentation/settings_screen.dart lamia_app/lib/features/planner/data/meal_plan_repository.dart lamia_app/lib/features/notifications/services/local_notification_service.dart
git commit -m "feat: wire settings notification switches to local alarms and permissions"
```

---

### Task 4: Create Cloud Function Push Notification Trigger (`onNotificationCreate`)

**Files:**
- Create: `lamia_app/functions/src/onNotificationCreate.ts`
- Modify: `lamia_app/functions/src/index.ts`

**Interfaces:**
- Consumes: Firestore `onDocumentCreated("users/{userId}/notifications/{notificationId}")`
- Produces: Push notification sent via Firebase Admin SDK to `fcmTokens` filtered by user preferences.

- [ ] **Step 1: Write `onNotificationCreate.ts` Cloud Function**

Create `lamia_app/functions/src/onNotificationCreate.ts`:
- Trigger on `users/{userId}/notifications/{notificationId}` document creation.
- Check recipient `enableNotifications` and notification preference.
- Retrieve `fcmTokens` from recipient's user document.
- Send FCM multicast payload with `title`, `body`, and data payload (`targetType`, `targetId`, `route`).
- Remove invalid/stale tokens from the user document.

- [ ] **Step 2: Export `onNotificationCreate` in `functions/src/index.ts`**

Export the new function in `lamia_app/functions/src/index.ts`.

- [ ] **Step 3: Compile Cloud Functions**

Run in `lamia_app/functions`: `cmd /c npm run build`
Expected: TypeScript compiles cleanly without error.

- [ ] **Step 4: Commit changes**

```bash
git add lamia_app/functions/src/onNotificationCreate.ts lamia_app/functions/src/index.ts
git commit -m "feat: add onNotificationCreate cloud function for FCM push dispatch"
```

---

### Task 5: Full App Verification & Final Audit

**Files:**
- Entire codebase

- [ ] **Step 1: Run static analysis on Flutter project**
Run: `flutter analyze` inside `lamia_app/`
Expected: 0 errors, 0 warnings.

- [ ] **Step 2: Run complete test suite**
Run: `flutter test` inside `lamia_app/`
Expected: All tests pass.

- [ ] **Step 3: Verify Cloud Functions compilation**
Run: `cmd /c npm run build` inside `lamia_app/functions/`
Expected: Exit code 0.

- [ ] **Step 4: Final Git Status Verification**
Run: `git status`
Expected: Clean working directory with all tasks committed.
