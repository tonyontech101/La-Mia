import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const verifyEmailOtp = onCall({ cors: true }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to verify a code.");
  }

  const { code, purpose, newEmail } = request.data || {};
  if (!code || typeof code !== "string" || !/^\d{6}$/.test(code.trim())) {
    throw new HttpsError("invalid-argument", "Please enter a valid 6-digit verification code.");
  }

  if (!purpose || !["signup", "change_password", "change_email"].includes(purpose)) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid purpose. Must be one of: signup, change_password, change_email."
    );
  }

  const docId = `${uid}_${purpose}`;
  const otpRef = db.collection("otp_verifications").doc(docId);
  const otpDoc = await otpRef.get();

  if (!otpDoc.exists) {
    throw new HttpsError(
      "not-found",
      "No active verification code found. Please request a new code."
    );
  }

  const data = otpDoc.data()!;
  const now = Date.now();
  const expiresAtMillis = data.expiresAt?.toMillis?.() || 0;

  // Check expiration
  if (now > expiresAtMillis) {
    await otpRef.delete();
    throw new HttpsError(
      "deadline-exceeded",
      "Verification code has expired. Please request a new code."
    );
  }

  const currentAttempts = data.attempts || 0;
  if (currentAttempts >= 5) {
    await otpRef.delete();
    throw new HttpsError(
      "resource-exhausted",
      "Too many incorrect attempts. This code is no longer valid. Please request a new code."
    );
  }

  // Verify HMAC hash
  const computedHash = crypto
    .createHmac("sha256", data.salt)
    .update(code.trim())
    .digest("hex");

  if (computedHash !== data.otpHash) {
    await otpRef.update({
      attempts: admin.firestore.FieldValue.increment(1),
    });
    const remaining = 4 - currentAttempts;
    if (remaining <= 0) {
      await otpRef.delete();
      throw new HttpsError(
        "resource-exhausted",
        "Too many incorrect attempts. Please request a new code."
      );
    }
    throw new HttpsError(
      "invalid-argument",
      `Incorrect code. ${remaining} attempt${remaining === 1 ? "" : "s"} remaining.`
    );
  }

  // Code is verified — delete the OTP record
  await otpRef.delete();

  if (purpose === "signup") {
    // Mark email as verified in Firebase Auth
    await admin.auth().updateUser(uid, {
      emailVerified: true,
    });
    return {
      success: true,
      emailVerified: true,
      message: "Email verified successfully.",
    };
  }

  if (purpose === "change_email") {
    const updatedEmail = (newEmail || data.email).trim().toLowerCase();
    // Update user's email in Firebase Auth and set emailVerified to true
    await admin.auth().updateUser(uid, {
      email: updatedEmail,
      emailVerified: true,
    });

    // Sync email in Firestore users/{uid} document
    try {
      await db.collection("users").doc(uid).set(
        { email: updatedEmail, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
        { merge: true }
      );
    } catch (err) {
      console.warn(`[verifyEmailOtp] Failed to update Firestore user document email: ${err}`);
    }

    return {
      success: true,
      emailVerified: true,
      newEmail: updatedEmail,
      message: "Email updated and verified successfully.",
    };
  }

  if (purpose === "change_password") {
    return {
      success: true,
      verified: true,
      message: "Identity verified. You may now update your password.",
    };
  }

  return { success: true };
});
