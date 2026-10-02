import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const verifyEmailOtp = onCall({ cors: true }, async (request) => {
  const uid = request.auth?.uid;
  const { code, purpose, newEmail, email, targetEmail, password, displayName } = request.data || {};

  if (!code || typeof code !== "string" || !/^\d{6}$/.test(code.trim())) {
    throw new HttpsError("invalid-argument", "Please enter a valid 6-digit verification code.");
  }

  if (!purpose || !["signup", "change_password", "change_email"].includes(purpose)) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid purpose. Must be one of: signup, change_password, change_email."
    );
  }

  let docId: string;
  let recipientEmail: string | undefined;

  if (purpose === "signup") {
    recipientEmail = (email || targetEmail || request.auth?.token?.email)?.trim()?.toLowerCase();
    if (!recipientEmail || !recipientEmail.includes("@")) {
      throw new HttpsError("invalid-argument", "A valid email is required.");
    }
    const emailHash = crypto.createHash("sha256").update(recipientEmail).digest("hex");
    docId = `signup_${emailHash}`;
  } else {
    if (!uid) {
      throw new HttpsError("unauthenticated", "You must be signed in to verify a code.");
    }
    docId = `${uid}_${purpose}`;
  }

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
    // If user is already signed in (legacy unverified user logging in), mark email as verified
    if (uid) {
      await admin.auth().updateUser(uid, {
        emailVerified: true,
      });
      return {
        success: true,
        emailVerified: true,
        message: "Email verified successfully.",
      };
    }

    // New user registration: create the account in Firebase Auth now that OTP is verified!
    if (!password || typeof password !== "string" || password.length < 6) {
      throw new HttpsError("invalid-argument", "A valid password is required to complete account creation.");
    }

    try {
      const newUser = await admin.auth().createUser({
        email: recipientEmail,
        password: password,
        displayName: displayName ? String(displayName).trim() : undefined,
        emailVerified: true,
      });

      // Atomically create the Firestore user document with Admin SDK
      const initialDisplayName = displayName ? String(displayName).trim() : (recipientEmail ? recipientEmail.split("@")[0] : "User");
      try {
        await db.collection("users").doc(newUser.uid).set({
          displayName: initialDisplayName,
          bio: null,
          photoUrl: null,
          recipeCount: 0,
          totalLikesReceived: 0,
          followerCount: 0,
          followingCount: 0,
          savedCount: 0,
          role: "user",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (docErr) {
        console.warn(`[verifyEmailOtp] Failed to create initial user document in Firestore: ${docErr}`);
      }

      return {
        success: true,
        emailVerified: true,
        uid: newUser.uid,
        message: "Account created and verified successfully.",
      };
    } catch (err: any) {
      if (err.code === "auth/email-already-in-use") {
        throw new HttpsError("already-exists", "The email address is already in use by another account.");
      }
      throw new HttpsError("internal", err.message || "Failed to create account.");
    }
  }

  if (purpose === "change_email") {
    const updatedEmail = (newEmail || data.email).trim().toLowerCase();
    // Update user's email in Firebase Auth and set emailVerified to true
    await admin.auth().updateUser(uid!, {
      email: updatedEmail,
      emailVerified: true,
    });

    // Sync email in Firestore users/{uid} document
    try {
      await db.collection("users").doc(uid!).set(
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
