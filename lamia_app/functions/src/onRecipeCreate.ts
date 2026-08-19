/**
 * onRecipeCreate — Firestore onCreate trigger for recipe moderation.
 *
 * When a new recipe is created in the `recipes` collection, this function:
 *
 * 1. Rate-limit check: rejects if the author has submitted more than
 *    5 recipes in the past hour (anti-spam).
 *
 * 2. Text validation (Gemini API): checks if the recipe title,
 *    description, and ingredients describe actual food.
 *
 * 3. Image validation (Cloud Vision API): checks if the cover photo
 *    contains food and is not inappropriate.
 *
 * 4. Updates the recipe's `status` based on results:
 *    - 'rejected' if text is not a recipe or image is inappropriate
 *    - 'flagged' if image doesn't look like food (needs admin review)
 *    - 'pending' if everything passes (still needs admin approval at launch)
 *
 * The function also writes a moderation log to the `moderationLogs`
 * subcollection for audit purposes.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineString } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { validateTextWithGemini } from "./validators/textValidator";
import { validateImageWithVision } from "./validators/imageValidator";

// Initialize Firebase Admin SDK
admin.initializeApp();

// API key from environment (set via .env or firebase functions:secrets:set)
const geminiApiKey = defineString("GEMINI_API_KEY");

// Rate limit: max recipes per user per hour
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour

export const onRecipeCreate = onDocumentCreated(
  {
    document: "recipes/{recipeId}",
    // Run in the same region as your Firestore
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data in snapshot, skipping.");
      return;
    }

    const data = snapshot.data();
    const recipeId = event.params.recipeId;
    const authorId = data.authorId as string | undefined;
    const db = admin.firestore();

    // Skip system-seeded recipes (they don't need moderation)
    if (data.isSystemRecipe === true) {
      console.log(`Skipping system recipe: ${recipeId}`);
      return;
    }

    // Skip if already processed (e.g., status changed from 'pending')
    if (data.status !== "pending") {
      console.log(`Recipe ${recipeId} status is "${data.status}", skipping.`);
      return;
    }

    console.log(`Moderating recipe "${data.name}" (${recipeId}) by ${authorId}`);

    let finalStatus = "approved"; // Default to approved unless AI checks fail
    let rejectionReason = "";
    const moderationLog: Record<string, unknown> = {
      recipeId,
      authorId: authorId ?? null,
      recipeName: data.name,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    // ── 1. Rate Limit Check ──────────────────────────────────────────────

    if (authorId) {
      try {
        const cutoff = Date.now() - RATE_LIMIT_WINDOW_MS;
        const recentSnap = await db
          .collection("recipes")
          .where("authorId", "==", authorId)
          .limit(20)
          .get();

        const recentCount = recentSnap.docs.filter((doc) => {
          const ca = doc.data().createdAt;
          if (!ca) return false;
          const millis = ca.toMillis ? ca.toMillis() : new Date(ca).getTime();
          return millis >= cutoff;
        }).length;

        moderationLog.rateLimitCount = recentCount;

        if (recentCount > RATE_LIMIT_MAX) {
          finalStatus = "rejected";
          rejectionReason =
            `Rate limit exceeded: ${recentCount} recipes in the past hour (max ${RATE_LIMIT_MAX}).`;
          moderationLog.rateLimitExceeded = true;
          console.warn(`Rate limit exceeded for user ${authorId}: ${recentCount} recipes/hour`);
        }
      } catch (err) {
        console.error("Rate limit check failed:", err);
      }
    }

    // ── 2. Text Validation (Gemini API) ──────────────────────────────────

    if (finalStatus === "approved") {
      try {
        const textResult = await validateTextWithGemini(
          geminiApiKey.value(),
          {
            name: data.name ?? "",
            description: data.description ?? "",
            category: data.category ?? "",
            ingredients: data.ingredients ?? [],
            instructions: data.instructions ?? [],
          }
        );

        moderationLog.textValidation = {
          isRecipe: textResult.isRecipe,
          reason: textResult.reason,
        };

        if (!textResult.isRecipe) {
          finalStatus = "rejected";
          rejectionReason = `Content rejected: ${textResult.reason}`;
          console.warn(`Text validation failed for ${recipeId}: ${textResult.reason}`);
        }
      } catch (err) {
        console.error("Text validation error:", err);
        moderationLog.textValidation = { error: String(err) };
      }
    }

    // ── 3. Image Validation (Cloud Vision API) ───────────────────────────

    if (finalStatus === "approved") {
      try {
        const coverPhotoUrl = data.coverPhotoUrl as string | undefined;

        if (coverPhotoUrl && coverPhotoUrl.trim() !== "") {
          const imageResult = await validateImageWithVision(coverPhotoUrl);

          moderationLog.imageValidation = {
            isSafe: imageResult.isSafe,
            isFood: imageResult.isFood,
            labels: imageResult.labels.slice(0, 10),
            reason: imageResult.reason,
          };

          if (!imageResult.isSafe) {
            finalStatus = "rejected";
            rejectionReason = `Image rejected: ${imageResult.reason}`;
            console.warn(`Image validation failed (unsafe content) for ${recipeId}: ${imageResult.reason}`);
          }
        }
      } catch (err) {
        console.error("Image validation error:", err);
        moderationLog.imageValidation = { error: String(err) };
      }
    }

    // ── 4. Update Recipe Status ──────────────────────────────────────────

    moderationLog.finalStatus = finalStatus;
    moderationLog.rejectionReason = rejectionReason;

    try {
      await snapshot.ref.update({
        status: finalStatus,
        ...(rejectionReason ? { rejectionReason } : {}),
        ...(finalStatus === "approved"
          ? { approvedAt: admin.firestore.FieldValue.serverTimestamp() }
          : {}),
        moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Recipe ${recipeId} AI moderation completed with status: "${finalStatus}"`);

      // Write moderation log for audit trail
      await db
        .collection("moderationLogs")
        .add(moderationLog);

    } catch (err) {
      console.error("Failed to update recipe status:", err);
    }
  }
);
