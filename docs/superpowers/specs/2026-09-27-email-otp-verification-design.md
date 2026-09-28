# Email OTP Verification Design Specification

**Date:** 2026-09-27  
**Status:** Approved  
**Scope:** Firebase Cloud Functions (v2), Resend Email API, and Flutter Frontend  

---

## 1. Problem Statement & Motivation

### Current State
Currently, email verification in LaMia relies on Firebase Authentication's default action links:
- When a user signs up, `user.sendEmailVerification()` is called with an `ActionCodeSettings` URL.
- The app displays `EmailVerificationScreen`, which polls `user.reload()` every 3 seconds while waiting for the user to switch apps, open their inbox, click the web link, and return.
- In `SettingsScreen`, updating passwords or email addresses similarly relies on sending action links and manual confirmation.

### Pain Points & Limitations
1. **High Friction & Drop-Off:** Users must leave the app, open an external email client, click a link that opens a browser window, and manually switch back to LaMia.
2. **Deep-Link / Browser Issues:** Link handlers can open in in-app browsers, private tabs, or external browsers where the session is disconnected.
3. **Inconsistent UX:** The user cannot simply glance at a notification preview or copy-paste a quick 6-digit code into the screen they are already on.
4. **Firebase Auth Limitation:** Standard Firebase Auth does not offer native 6-digit email OTPs on the free tier without Google Cloud Identity Platform enterprise add-ons.

### Objective
Replace email verification links with a fast, modern **6-digit One-Time Password (OTP)** sent to the user's inbox via **Resend**, with a dedicated, delightful Flutter OTP UI for:
1. **Sign-up Email Verification**
2. **Password Change Verification** (in Settings)
3. **Email Address Change Verification** (in Settings)

---

## 2. Architecture Overview

```
+-----------------------------------------------------------------------------------------+
|                                1. User Action in App                                    |
|  - Sign up with email/password                                                          |
|  - Request Password Change or Email Change in Settings                                  |
+-----------------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------------+
|                          2. Flutter Auth Service -> Cloud Function                      |
|  - Calls HttpsCallable('sendEmailOtp') with { purpose: 'signup' | 'change_password' |   |
|    'change_email', newEmail?: '...' }                                                   |
+-----------------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------------+
|                       3. Cloud Function: sendEmailOtp (Node.js)                         |
|  - Enforces 60-second cooldown per target/user                                          |
|  - Generates cryptographically secure 6-digit OTP (crypto.randomInt)                    |
|  - Computes SHA-256 hash of (OTP + salt)                                                |
|  - Writes hash, expiresAt (+10m), attempts (0), purpose to Firestore `otp_verifications`|
|  - Dispatches branded HTML email via Resend API (`resend` SDK)                          |
+-----------------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------------+
|                          4. Dedicated Flutter OTP Screen                                |
|  - Navigates to EmailOtpVerificationScreen                                              |
|  - 6 individual digit cells with smooth focus animation and paste support               |
|  - 60s cooldown resend timer with active countdown                                      |
|  - Auto-submits on 6th digit                                                            |
+-----------------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------------+
|                      5. Cloud Function: verifyEmailOtp (Node.js)                        |
|  - Validates code hash, expiration, and attempts (< 5)                                  |
|  - On failure: increments attempts, returns remaining attempts                          |
|  - On success:                                                                          |
|      * 'signup': Calls admin.auth().updateUser(uid, { emailVerified: true })            |
|      * 'change_email': Calls admin.auth().updateUser(uid, { email: newEmail,            |
|                        emailVerified: true }) & updates Firestore users/{uid}           |
|      * 'change_password': Returns single-use verificationToken for changePassword       |
|      * Deletes/invalidates the OTP record                                               |
+-----------------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------------+
|                                6. Completion & Feedback                                 |
|  - Plays success micro-animation (AppColors.success)                                    |
|  - Reloads Firebase user session (`user.reload()`)                                     |
|  - Navigates smoothly to Home (signup) or pops with success snackbar (settings)         |
+-----------------------------------------------------------------------------------------+
```

---

## 3. Backend Design (Cloud Functions + Resend)

### Dependencies
In `lamia_app/functions/package.json`:
- `resend: ^4.1.2`
- `firebase-admin: ^13.0.0`
- `firebase-functions: ^6.3.2`

### Environment Configuration
- `RESEND_API_KEY`: Set in `functions/.env` and Firebase Functions secrets.
- Sender Address: e.g. `La Mia <onboarding@resend.dev>` (default Resend testing domain) or custom domain when verified in Resend.

### Firestore Collection: `otp_verifications`
Security: **Locked down via Firestore Security Rules** (no client read/write allowed; only Firebase Admin SDK in Cloud Functions).

Document ID schema:
- `signup` / `change_password`: `${uid}_${purpose}`
- `change_email`: `${uid}_change_email`

Document Fields:
```typescript
interface OtpVerificationDoc {
  uid: string;
  email: string;
  purpose: 'signup' | 'change_password' | 'change_email';
  otpHash: string; // SHA-256(code + salt)
  salt: string;
  attempts: number; // Max 5
  expiresAt: FirebaseFirestore.Timestamp; // Now + 10 mins
  createdAt: FirebaseFirestore.Timestamp;
  lastSentAt: FirebaseFirestore.Timestamp; // Cooldown tracking
}
```

### Callable Cloud Functions
1. `sendEmailOtp(data: { purpose: string, targetEmail?: string })`
   - Validates user authentication (`request.auth`).
   - Checks cooldown: if `Date.now() - lastSentAt < 60000`, throw `resource-exhausted`.
   - Generates 6-digit random code: `Math.floor(100000 + Math.random() * 900000).toString()`.
   - Hashes code using `crypto.createHmac('sha256', salt).update(code).digest('hex')`.
   - Saves record in `otp_verifications`.
   - Sends email via Resend with responsive HTML template.
   - Returns `{ success: true, cooldownSeconds: 60 }`.

2. `verifyEmailOtp(data: { code: string, purpose: string, newEmail?: string })`
   - Validates `code` format (exactly 6 digits).
   - Reads `otp_verifications/${uid}_${purpose}`.
   - If document does not exist or `Date.now() > expiresAt.toMillis()`, throws `deadline-exceeded` ("Verification code has expired. Please request a new one.").
   - If `attempts >= 5`, deletes document and throws `permission-denied` ("Too many incorrect attempts. Please request a new code.").
   - Computes HMAC hash with stored salt:
     - If mismatch: increments `attempts` by 1, throws `invalid-argument` ("Invalid code. X attempts remaining.").
     - If match:
       - Deletes document.
       - If `purpose === 'signup'`:
         - `admin.auth().updateUser(uid, { emailVerified: true })`.
         - Returns `{ success: true, emailVerified: true }`.
       - If `purpose === 'change_email'`:
         - `admin.auth().updateUser(uid, { email: newEmail, emailVerified: true })`.
         - Updates Firestore `users/${uid}` email field.
         - Returns `{ success: true, newEmail }`.
       - If `purpose === 'change_password'`:
         - Issues a signed single-use verification token (or writes a 5-minute approval flag in a secure internal doc) that allows `changePasswordWithToken`.
         - Returns `{ success: true, verified: true }`.

### Branded Email Template
- Visual styling inspired by LaMia's design tokens:
  - Header: Warm amber accent (`#D97706`), LaMia wordmark & subtitle ("Cook, Share, and Discover").
  - Hero Card: Clean white card on warm neutral background (`#FAF7F2`).
  - Code Display: Large 32px monospaced bold letters with letter spacing `8px`, centered in an amber-tinted box (`#FEF3C7`).
  - Clear copy: "This code will expire in 10 minutes. If you did not request this, please disregard."

---

## 4. Frontend Design (Flutter)

### Dedicated OTP Screen: `EmailOtpVerificationScreen`
Located at `lib/features/auth/presentation/email_otp_verification_screen.dart`.

#### Visual & Interactive Features
1. **Hero Header**:
   - Animated shield/mail icon with warm amber pulse.
   - Clear typography: Fraunces headline ("Verify your email" / "Security verification").
   - Email subtitle with highlighted target address (`user@example.com`).
2. **Dedicated 6-Digit Pin Input Component (`OtpPinInput`)**:
   - 6 individual rounded cells (48x56px on mobile, responsive).
   - Focused cell has glowing border (`AppColors.primary` 2px).
   - Filled cells show bold digits with crisp Inter typography.
   - Automatic navigation to next cell on input; backspace jumps to previous cell.
   - Full clipboard paste listener: Pasting any 6-digit code distributes each digit across all cells.
   - Keyboard auto-focus on first cell on screen entry.
   - Automatic submission when the 6th digit is entered.
3. **Resend Timer & Button**:
   - Active countdown: "Resend code in 0:45".
   - Becomes an interactive text button "Resend Code" once timer expires.
4. **State & Error Feedback**:
   - Smooth loading spinner during verification call.
   - Shake animation + red border outline (`AppColors.error`) and descriptive message if code is incorrect or expired.
   - Success animation: Checkmark transition before navigating.
5. **Back / Cancel Action**:
   - For sign-up: "Sign out and return to Login" option.
   - For settings: Close (X) button to return to Settings without applying changes.

---

## 5. Integration Points

1. **`lib/features/auth/data/auth_service.dart`**:
   - Add `sendEmailOtp({required String purpose, String? targetEmail})`.
   - Add `verifyEmailOtp({required String code, required String purpose, String? newEmail})`.
   - Retain `reloadUser()` to refresh `isEmailVerified` after callable completes.
2. **`lib/features/auth/presentation/sign_up_screen.dart`**:
   - Call `authService.sendEmailOtp(purpose: 'signup')`.
   - Navigate to `EmailOtpVerificationScreen(purpose: OtpPurpose.signup)`.
3. **`lib/app/app.dart`**:
   - When an unverified non-Google user is detected, route to `EmailOtpVerificationScreen()`.
4. **`lib/features/profile/presentation/settings_screen.dart`**:
   - Change Password flow: Calls `sendEmailOtp(purpose: 'change_password')` -> shows OTP screen -> updates password.
   - Change Email flow: Calls `sendEmailOtp(purpose: 'change_email', targetEmail: newEmail)` -> shows OTP screen -> completes email update.
