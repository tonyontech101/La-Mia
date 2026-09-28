import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { sendVerificationEmail } from "./services/emailService";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const sendEmailOtp = onCall({ cors: true }, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "You must be signed in to request a verification code.");
  }
  const uid = request.auth.uid;

  const { purpose, targetEmail } = request.data || {};
  if (!purpose || !["signup", "change_password", "change_email"].includes(purpose)) {
    throw new HttpsError(
      "invalid-argument",
      "Invalid purpose. Must be one of: signup, change_password, change_email."
    );
  }

  let recipientEmail: string | undefined = targetEmail;

  if (purpose === "change_email") {
    if (!recipientEmail || !recipientEmail.includes("@")) {
      throw new HttpsError("invalid-argument", "A valid target email is required for email changes.");
    }
  } else {
    // For signup or change_password, default to current user's email if not provided
    if (!recipientEmail) {
      recipientEmail = request.auth.token.email;
    }
    if (!recipientEmail) {
      // Fallback: fetch from Firebase Auth
      const userRecord = await admin.auth().getUser(uid);
      recipientEmail = userRecord.email;
    }
  }

  if (!recipientEmail) {
    throw new HttpsError("not-found", "User email could not be determined.");
  }

  recipientEmail = recipientEmail.trim().toLowerCase();

  const docId = `${uid}_${purpose}`;
  const otpRef = db.collection("otp_verifications").doc(docId);
  const otpDoc = await otpRef.get();

  const now = Date.now();

  // Check 60-second cooldown
  if (otpDoc.exists) {
    const data = otpDoc.data();
    const lastSentMillis = data?.lastSentAt?.toMillis?.() || 0;
    const elapsed = now - lastSentMillis;
    if (elapsed < 60000) {
      const waitSeconds = Math.ceil((60000 - elapsed) / 1000);
      throw new HttpsError(
        "resource-exhausted",
        `Please wait ${waitSeconds} seconds before requesting a new code.`
      );
    }
  }

  // Generate cryptographically secure 6-digit code
  const code = crypto.randomInt(100000, 1000000).toString();

  // Generate salt and compute SHA-256 HMAC
  const salt = crypto.randomBytes(16).toString("hex");
  const otpHash = crypto.createHmac("sha256", salt).update(code).digest("hex");

  // Save to Firestore with 10-minute expiry
  await otpRef.set({
    uid,
    email: recipientEmail,
    purpose,
    otpHash,
    salt,
    attempts: 0,
    expiresAt: admin.firestore.Timestamp.fromMillis(now + 10 * 60 * 1000),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastSentAt: admin.firestore.Timestamp.fromMillis(now),
  });

  // Dispatch email via Resend
  await sendVerificationEmail(recipientEmail, code, purpose);

  return {
    success: true,
    email: recipientEmail,
    cooldownSeconds: 60,
  };
});
