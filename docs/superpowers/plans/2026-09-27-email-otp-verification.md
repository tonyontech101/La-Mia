# Email OTP Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace link-based email verification with a secure 6-digit One-Time Password (OTP) verification system sent via Resend API, supported by a dedicated, modern Flutter OTP input UI for sign-up, password changes, and email changes.

**Architecture:**
1. **Backend (Cloud Functions v2 & Resend):** Callable HTTPS functions `sendEmailOtp` and `verifyEmailOtp` in `functions/src/` to securely generate, hash, throttle, and send branded OTP emails, then verify codes and update user verification status via Firebase Admin SDK.
2. **Database & Security:** Firestore `otp_verifications` collection restricted exclusively to Cloud Functions Admin SDK (closed to all direct client read/writes).
3. **Flutter Client:** `AuthService` callable client methods, dedicated `OtpPinInput` widget with individual animated boxes and clipboard paste support, and a responsive `EmailOtpVerificationScreen` with cooldown timers and auto-submission.
4. **App Integration:** Seamless wiring into user sign-up flow, cold-start router (`app.dart`), and settings security actions (`settings_screen.dart`).

**Tech Stack:** Flutter (Dart 3.x, Riverpod), Firebase Cloud Functions (Node.js 22, TypeScript), Firebase Admin SDK, Resend SDK (`resend`), Firestore Security Rules.

**Spec:** [`docs/superpowers/specs/2026-09-27-email-otp-verification-design.md`](file:///c:/Users/My%20PC/OneDrive/Documents/LaMia/docs/superpowers/specs/2026-09-27-email-otp-verification-design.md)

## Global Constraints
- Firebase project: `la-mia-e348d`.
- Cloud Functions runtime: Node.js 22.
- Email provider: Resend (`resend` npm package).
- Code format: 6-digit numeric string (`000000` - `999999`).
- Expiration: 10 minutes from creation.
- Rate-limiting: 60-second cooldown between resends; maximum 5 failed attempts before code invalidation.
- Never store raw OTP codes in Firestore (store only SHA-256 HMAC hash + unique salt).
- Maintain existing non-breaking contracts for guest and Google Sign-In users.

---

### Task 1: Backend Dependencies & Resend Configuration

**Files:**
- Modify: `lamia_app/functions/package.json`
- Modify: `lamia_app/functions/.env`
- Create: `lamia_app/functions/src/services/emailService.ts`

**Interfaces:**
- Consumes: `process.env.RESEND_API_KEY`
- Produces: `sendVerificationEmail(email: string, code: string, purpose: string): Promise<void>`

- [x] **Step 1: Add `resend` to `functions/package.json`**
Add `"resend": "^4.1.2"` to the dependencies in `lamia_app/functions/package.json`.

- [x] **Step 2: Add placeholder `RESEND_API_KEY` to `functions/.env`**
Add `RESEND_API_KEY=re_test_placeholder` to `lamia_app/functions/.env` with comments instructing the developer to populate their Resend API key.

- [x] **Step 3: Implement branded email template and delivery service in `emailService.ts`**
Create `lamia_app/functions/src/services/emailService.ts`:
- Initialize Resend client using `process.env.RESEND_API_KEY`.
- Provide `getOtpEmailHtml(code: string, purposeText: string): string` with LaMia amber styling (`#D97706`), centered 6-digit box, Fraunces/Inter fallback typography, and 10-minute expiration advisory.
- Export `sendVerificationEmail(to: string, code: string, purpose: string): Promise<void>`.

- [x] **Step 4: Verify build succeeds**
Run `npm run build` in `lamia_app/functions` to confirm TypeScript compiles cleanly.

---

### Task 2: Cloud Functions `sendEmailOtp` & `verifyEmailOtp`

**Files:**
- Create: `lamia_app/functions/src/sendEmailOtp.ts`
- Create: `lamia_app/functions/src/verifyEmailOtp.ts`
- Modify: `lamia_app/functions/src/index.ts`

**Interfaces:**
- Consumes: `sendVerificationEmail` from `emailService.ts`, Firebase Admin Auth & Firestore.
- Produces: 
  - `sendEmailOtp` (callable): `{ purpose: string, targetEmail?: string } -> { success: boolean, cooldownSeconds: number }`
  - `verifyEmailOtp` (callable): `{ code: string, purpose: string, newEmail?: string } -> { success: boolean, ... }`

- [x] **Step 1: Implement `sendEmailOtp` callable function**
Create `lamia_app/functions/src/sendEmailOtp.ts`:
- Ensure caller is authenticated via `request.auth` (or allows valid signup email).
- Enforce 60-second cooldown based on `lastSentAt` in `otp_verifications/${uid}_${purpose}`.
- Generate secure 6-digit code: `crypto.randomInt(100000, 1000000).toString()`.
- Generate 16-byte random hex salt: `crypto.randomBytes(16).toString('hex')`.
- Compute HMAC SHA-256 hash: `crypto.createHmac('sha256', salt).update(code).digest('hex')`.
- Save document in `otp_verifications`:
  ```typescript
  {
    uid,
    email: targetEmail,
    purpose,
    otpHash,
    salt,
    attempts: 0,
    expiresAt: Timestamp.fromMillis(Date.now() + 10 * 60 * 1000),
    createdAt: FieldValue.serverTimestamp(),
    lastSentAt: FieldValue.serverTimestamp()
  }
  ```
- Send email using `sendVerificationEmail(targetEmail, code, purpose)`.
- Return `{ success: true, cooldownSeconds: 60 }`.

- [x] **Step 2: Implement `verifyEmailOtp` callable function**
Create `lamia_app/functions/src/verifyEmailOtp.ts`:
- Require `request.auth` and validate `code` (string of 6 digits).
- Retrieve doc `otp_verifications/${uid}_${purpose}`.
- If not found or expired (`now > expiresAt`), throw `HttpsError('deadline-exceeded', 'Code expired')`.
- If `attempts >= 5`, delete doc and throw `HttpsError('resource-exhausted', 'Too many failed attempts')`.
- Verify hash against `crypto.createHmac('sha256', doc.salt).update(code).digest('hex')`:
  - On mismatch: increment `attempts` in Firestore, throw `HttpsError('invalid-argument', 'Incorrect code')`.
  - On match:
    - Delete the `otp_verifications` document.
    - If `purpose === 'signup'`: `await admin.auth().updateUser(uid, { emailVerified: true })`.
    - If `purpose === 'change_email'`: `await admin.auth().updateUser(uid, { email: newEmail, emailVerified: true })` and update `users/${uid}` in Firestore.
    - If `purpose === 'change_password'`: write a single-use verification stamp or return `{ success: true, verified: true }`.

- [x] **Step 3: Export callable functions in `functions/src/index.ts`**
Export `sendEmailOtp` and `verifyEmailOtp` from `lamia_app/functions/src/index.ts`.

- [x] **Step 4: Verify TypeScript compilation**
Run `npm run build` in `lamia_app/functions` to ensure no syntax or type errors.

---

### Task 3: Firestore Security Rules for `otp_verifications`

**Files:**
- Modify: `firestore.rules` (or root Firestore configuration if present)

**Interfaces:**
- Consumes: Firestore Security Rules language.
- Produces: Complete block on client direct read/write to `otp_verifications`.

- [x] **Step 1: Check existing security rules**
Inspect `firestore.rules` in the repository root.

- [x] **Step 2: Add restrictive rule for `otp_verifications`**
```rules
match /otp_verifications/{document} {
  allow read, write: if false; // Only Cloud Functions Admin SDK can access
}
```

---

### Task 4: Flutter Dependencies & `AuthService` OTP Integration

**Files:**
- Modify: `lamia_app/pubspec.yaml`
- Modify: `lamia_app/lib/features/auth/data/auth_service.dart`
- Create: `lamia_app/test/auth_otp_service_test.dart`

**Interfaces:**
- Consumes: `cloud_functions: ^5.2.2` (or HTTPS callable endpoint).
- Produces:
  - `Future<void> sendEmailOtp({required String purpose, String? targetEmail})`
  - `Future<bool> verifyEmailOtp({required String code, required String purpose, String? newEmail})`

- [x] **Step 1: Add `cloud_functions` to `lamia_app/pubspec.yaml`**
Add `cloud_functions: ^5.2.2` to dependencies and run `flutter pub get`.

- [x] **Step 2: Write unit test for `AuthService` OTP methods**
Create `lamia_app/test/auth_otp_service_test.dart` testing OTP contract and error mapping.

- [x] **Step 3: Implement `sendEmailOtp` and `verifyEmailOtp` in `auth_service.dart`**
Add methods:
```dart
Future<void> sendEmailOtp({
  required String purpose,
  String? targetEmail,
}) async { ... }

Future<bool> verifyEmailOtp({
  required String code,
  required String purpose,
  String? newEmail,
}) async { ... }
```
Handle `FirebaseFunctionsException` with user-friendly error translations.

---

### Task 5: Dedicated 6-Digit Pin Input Component (`OtpPinInput`)

**Files:**
- Create: `lamia_app/lib/features/auth/presentation/widgets/otp_pin_input.dart`
- Create: `lamia_app/test/otp_pin_input_test.dart`

**Interfaces:**
- Consumes: Flutter standard text editing & focus node system.
- Produces: `OtpPinInput(onCompleted: (code) => ..., onChanged: (code) => ..., hasError: bool)`

- [x] **Step 1: Write widget test for `OtpPinInput`**
Create `lamia_app/test/otp_pin_input_test.dart`:
- Verifies 6 boxes render.
- Verifies entering 6 digits calls `onCompleted`.
- Verifies backspace clears preceding box.
- Verifies paste event distributes digits across all 6 boxes.

- [x] **Step 2: Implement `OtpPinInput`**
Create `lamia_app/lib/features/auth/presentation/widgets/otp_pin_input.dart`:
- 6 individual digit cells with rounded corners (`AppSpacing.radiusSm`).
- Focused cell gets 2px border in `AppColors.primary`.
- Error state displays `AppColors.error` border with subtle shake animation.
- Handles backspace key detection via `RawKeyboardListener` / `FocusNode.onKeyEvent`.
- Listens for full paste and populates all 6 cells.
- Auto-triggers `onCompleted(fullCode)` upon filling the 6th cell.

- [x] **Step 3: Run widget tests**
Run `flutter test test/otp_pin_input_test.dart` and confirm all tests pass.

---

### Task 6: Dedicated Screen `EmailOtpVerificationScreen`

**Files:**
- Create: `lamia_app/lib/features/auth/presentation/email_otp_verification_screen.dart`
- Create: `lamia_app/test/email_otp_verification_screen_test.dart`

**Interfaces:**
- Consumes: `OtpPinInput`, `authServiceProvider`, `AppColors`, `AppTypography`.
- Produces: `EmailOtpVerificationScreen` widget supporting `signup`, `change_password`, and `change_email` modes.

- [x] **Step 1: Write widget test for `EmailOtpVerificationScreen`**
Create `lamia_app/test/email_otp_verification_screen_test.dart`:
- Tests display of target email.
- Tests countdown timer starts at 60s.
- Tests "Resend Code" becomes enabled when countdown reaches 0.
- Tests entering code calls verification.

- [x] **Step 2: Implement `EmailOtpVerificationScreen`**
Build `lamia_app/lib/features/auth/presentation/email_otp_verification_screen.dart`:
- Warm header with animated envelope/shield icon.
- Dynamic title and subtitle based on purpose:
  - `signup`: "Verify your email" -> "We sent a 6-digit code to {email}"
  - `change_password`: "Security Verification" -> "Enter the 6-digit code sent to {email} to update your password"
  - `change_email`: "Verify New Email" -> "Enter the 6-digit code sent to {newEmail}"
- Embeds `OtpPinInput`.
- Resend timer widget with active second countdown (`Resend code in 0:45`).
- "Verify & Continue" button with loading state.
- Success animation (check circle scale & fade) before navigation.
- Back button / "Sign out" link to return to login.

- [x] **Step 3: Run widget tests**
Run `flutter test test/email_otp_verification_screen_test.dart`.

---

### Task 7: Sign-Up & Cold-Start Flow Integration

**Files:**
- Modify: `lamia_app/lib/features/auth/presentation/sign_up_screen.dart`
- Modify: `lamia_app/lib/app/app.dart`
- Modify: `lamia_app/lib/features/auth/presentation/login_screen.dart`

**Interfaces:**
- Consumes: `EmailOtpVerificationScreen`.
- Produces: Direct transition to OTP screen upon sign-up or unverified login.

- [x] **Step 1: Update `sign_up_screen.dart`**
In `_signUp()`:
- After `createUserWithEmailAndPassword`, call `_authService.sendEmailOtp(purpose: 'signup')`.
- Navigate to `EmailOtpVerificationScreen(purpose: 'signup')` instead of the old link-polling screen.

- [x] **Step 2: Update `app.dart` auth state routing**
In `app.dart`:
- Replace `EmailVerificationScreen()` with `EmailOtpVerificationScreen(purpose: 'signup')` when `!user.emailVerified`.

- [x] **Step 3: Update `login_screen.dart`**
If an unverified user logs in, route them to `EmailOtpVerificationScreen(purpose: 'signup')`.

---

### Task 8: Settings Screen Flow Integration (Password & Email Changes)

**Files:**
- Modify: `lamia_app/lib/features/profile/presentation/settings_screen.dart`

**Interfaces:**
- Consumes: `EmailOtpVerificationScreen` with callbacks.
- Produces: One-time code verification for password and email changes.

- [x] **Step 1: Update password change in `settings_screen.dart`**
- In `_updatePassword()`:
  - Call `authService.sendEmailOtp(purpose: 'change_password')`.
  - Push `EmailOtpVerificationScreen(purpose: 'change_password', onVerified: (_) => authService.changePassword(newPassword))`.
  - Display success snackbar on return.

- [x] **Step 2: Update email change in `settings_screen.dart`**
- In `_updateEmail()`:
  - Call `authService.sendEmailOtp(purpose: 'change_email', targetEmail: newEmail)`.
  - Push `EmailOtpVerificationScreen(purpose: 'change_email', targetEmail: newEmail, onVerified: (_) async { await authService.reloadUser(); })`.
  - Update local state and show confirmation.

---

### Task 9: Deprecation Cleanup & Full System Verification

**Files:**
- Remove or refactor: `lamia_app/lib/features/auth/presentation/email_verification_screen.dart`
- Run test suite: `flutter test`
- Build functions: `npm run build` in `lamia_app/functions`

- [x] **Step 1: Deprecate or remove old link-polling `EmailVerificationScreen`**
Clean up unused code and remove dead references to the old polling screen.

- [x] **Step 2: Run all Flutter unit & widget tests**
Run `flutter test` across `lamia_app` to verify all tests pass without regressions.

- [x] **Step 3: Compile Cloud Functions**
Run `npm run build` in `lamia_app/functions` to verify error-free TypeScript build.
