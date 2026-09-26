# Phone Notifications Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable notifications to appear as system notifications on the phone (Android status bar, heads-up banner, and lock screen) when the app is foregrounded, backgrounded, or closed, covering both Cloud FCM social notifications and local meal reminders.

**Architecture:** 
1. Android OS manifest hardening with required permissions, boot receivers, and FCM channel metadata.
2. Cloud Functions (`onNotificationCreate`) multicast payload configured with high priority and Android channel targeting.
3. Flutter client FCM lifecycle bound to `authStateChanges` so tokens are guaranteed to sync to Firestore upon login.
4. Deployment of `onNotificationCreate` Cloud Function to Firebase project `la-mia-e348d`.

**Tech Stack:** Flutter, Dart, TypeScript, Firebase Cloud Functions (v2), Firebase Cloud Messaging (FCM), flutter_local_notifications, Android Gradle / XML.

**Spec:** [`docs/superpowers/specs/2026-09-26-phone-notifications-design.md`](file:///C:/Users/My%20PC/OneDrive/Documents/LaMia/docs/superpowers/specs/2026-09-26-phone-notifications-design.md)

## Global Constraints
- Target Android API 26+ (notification channels required), API 31+ (SCHEDULE_EXACT_ALARM required), API 33+ (POST_NOTIFICATIONS required).
- Firebase project: `la-mia-e348d`.
- Channel ID for system updates/social: `system_updates`.
- Do not introduce breaking changes to existing Firestore schema or in-app notification routing.

---

### Task 1: Native Android Manifest & Permissions Configuration

**Files:**
- Modify: `lamia_app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: Native Android system contracts (AlarmManager, FirebaseMessagingService, BroadcastReceiver).
- Produces: System-level permission to post notifications and schedule exact alarms, plus automatic reboot recovery.

- [ ] **Step 1: Check existing AndroidManifest.xml permissions and tags**

Verify line numbers and structure in `lamia_app/android/app/src/main/AndroidManifest.xml`.

- [ ] **Step 2: Add exact alarm permission, FCM metadata, and boot receivers**

Update `lamia_app/android/app/src/main/AndroidManifest.xml`:
1. Add `<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>` next to existing permissions.
2. Inside `<application>`, add:
```xml
        <!-- Default notification channel and icon for FCM -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="system_updates" />
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/ic_launcher" />

        <!-- Receivers for flutter_local_notifications boot & exact alarm scheduling -->
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

- [ ] **Step 3: Verify XML syntax**

Run: `cmd /c "cd /d \"C:\Users\My PC\OneDrive\Documents\LaMia\lamia_app\android\" && gradlew.bat :app:processDebugManifest --dry-run"` (or inspect XML format).
Expected: Process completes without XML parsing errors.

- [ ] **Step 4: Commit**

```bash
git add lamia_app/android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): add exact alarm permission, FCM channel metadata, and boot receivers"
```

---

### Task 2: Cloud Function FCM Multicast Payload Configuration

**Files:**
- Modify: `lamia_app/functions/src/onNotificationCreate.ts`
- Modify: `lamia_app/functions/src/index.ts` (verify exports)

**Interfaces:**
- Consumes: Firestore `users/{userId}/notifications/{notificationId}` onCreate events.
- Produces: Firebase Admin `sendEachForMulticast` call with structured `android` and `apns` payloads.

- [ ] **Step 1: Write/Update TypeScript payload in onNotificationCreate.ts**

Update `message` in `lamia_app/functions/src/onNotificationCreate.ts` to include `android` and `apns` blocks:
```typescript
    const message: admin.messaging.MulticastMessage = {
      tokens: fcmTokens,
      notification: {
        title: (notifData.title as string) || "La Mia",
        body: (notifData.body as string) || "",
        ...(notifData.imageUrl ? { imageUrl: String(notifData.imageUrl) } : {}),
      },
      data: dataPayload,
      android: {
        priority: "high",
        notification: {
          channelId: "system_updates",
          sound: "default",
          priority: "high",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };
```

- [ ] **Step 2: Build Cloud Functions to ensure clean TypeScript compilation**

Run: `cmd /c "cd /d \"C:\Users\My PC\OneDrive\Documents\LaMia\lamia_app\functions\" && npm run build"`
Expected: Output exit code 0, files emitted to `functions/lib/`.

- [ ] **Step 3: Commit**

```bash
git add lamia_app/functions/src/onNotificationCreate.ts lamia_app/functions/lib/
git commit -m "feat(functions): configure FCM multicast with high priority and android channelId"
```

---

### Task 3: Flutter FCM Token Lifecycle & Auth State Listener

**Files:**
- Modify: `lamia_app/lib/features/notifications/services/fcm_service.dart`
- Test: `lamia_app/test/features/notifications/fcm_service_test.dart`

**Interfaces:**
- Consumes: `FirebaseAuth.instance.authStateChanges()`, `FirebaseMessaging.instance.onTokenRefresh`.
- Produces: Guaranteed syncing of device token to `users/{userId}/fcmTokens` in Firestore upon login.

- [ ] **Step 1: Write unit test for token sync logic / mock verification**

Create `lamia_app/test/features/notifications/fcm_service_test.dart` testing token saving contract with `NotificationRepository`.

- [ ] **Step 2: Update FCMService to bind token syncing to authStateChanges**

In `lamia_app/lib/features/notifications/services/fcm_service.dart`:
1. In `initialize()`, add:
```dart
      // Listen to auth state changes to sync token immediately when user signs in
      FirebaseAuth.instance.authStateChanges().listen((user) async {
        if (user != null) {
          await syncToken();
        }
      });
```
2. In `syncToken()`, retrieve current user token and register it under the user document in Firestore.
3. In `clearTokenOnLogout()`, remove token from Firestore before logging out.

- [ ] **Step 3: Run Flutter tests**

Run: `cmd /c "cd /d \"C:\Users\My PC\OneDrive\Documents\LaMia\lamia_app\" && flutter test test/features/notifications/fcm_service_test.dart"`
Expected: Tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lamia_app/lib/features/notifications/services/fcm_service.dart lamia_app/test/features/notifications/fcm_service_test.dart
git commit -m "feat(notifications): sync FCM token automatically on auth state changes"
```

---

### Task 4: Deploy Cloud Function to Firebase

**Files:**
- Deploy target: `la-mia-e348d` Firebase project

**Interfaces:**
- Consumes: Compiled `functions/lib/index.js` containing `onNotificationCreate`.
- Produces: Active Cloud Function trigger in Google Cloud Functions v2.

- [ ] **Step 1: Deploy function via Firebase CLI**

Run: `cmd /c "cd /d \"C:\Users\My PC\OneDrive\Documents\LaMia\lamia_app\" && firebase deploy --only functions:onNotificationCreate --project la-mia-e348d"`
Expected: Successful deployment with `Deploy complete!` output.

- [ ] **Step 2: Verify active functions list**

Run: `cmd /c "cd /d \"C:\Users\My PC\OneDrive\Documents\LaMia\lamia_app\" && firebase functions:list --project la-mia-e348d"`
Expected: Both `onRecipeCreate` and `onNotificationCreate` appear in the function table with state active.

- [ ] **Step 3: Commit deployment record if configuration modified**

```bash
git status
```

---

### Task 5: End-to-End Analysis, Verification & Documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-09-26-phone-notifications-design.md` (status to Implemented)

**Interfaces:**
- Consumes: Complete notification pipeline.
- Produces: Verified static analysis, test suite, and operational instructions.

- [ ] **Step 1: Run Flutter static analysis**

Run: `cmd /c "cd /d \"C:\Users\My PC\OneDrive\Documents\LaMia\lamia_app\" && flutter analyze"`
Expected: 0 errors / 0 issues.

- [ ] **Step 2: Run all notification tests**

Run: `cmd /c "cd /d \"C:\Users\My PC\OneDrive\Documents\LaMia\lamia_app\" && flutter test test/features/notifications/"`
Expected: All tests PASS.

- [ ] **Step 3: Commit final plan & docs**

```bash
git add docs/superpowers/
git commit -m "docs: finalize phone notifications implementation documentation"
```
