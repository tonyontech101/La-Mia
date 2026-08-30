/**
 * updateTrendingScores — Scheduled Cloud Function
 *
 * Runs every hour to compute and update the `trendingScore` field for all approved
 * and system recipes in Firestore.
 *
 * Formula:
 *   baseScore = 10 + (likes * 2) + (favorites * 3) + (comments * 2) + (ratingAvg * ratingCount * 4)
 *   decayFactor = 1 / (1 + ageInDays / 14)
 *   trendingScore = round(baseScore * decayFactor * 100) * (isSystemRecipe ? 1.0 : 2.0)
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

export const updateTrendingScores = onSchedule(
  {
    schedule: "0 * * * *", // Run every hour at minute 0
    region: "us-central1",
    timeZone: "Asia/Manila", // Set timezone to local timezone
  },
  async (event) => {
    console.log("Starting scheduled trending score update...");
    const db = admin.firestore();
    const now = Date.now();

    try {
      const recipesSnap = await db.collection("recipes").get();
      console.log(`Fetched ${recipesSnap.size} recipes for score recalculation.`);

      const batch = db.batch();
      let operationCount = 0;
      let batchCount = 1;

      // Firestore batches support up to 500 operations.
      // We will commit batches as we build them.
      const batches = [batch];
      let currentBatch = batch;

      recipesSnap.forEach((doc) => {
        const data = doc.data();
        
        // Only calculate for approved recipes or system recipes
        const status = data.status || "approved";
        const isSystemRecipe = data.isSystemRecipe === true;
        if (status !== "approved" && !isSystemRecipe) {
          return;
        }

        const likes = (data.likeCount as number) || 0;
        const favorites = (data.favoriteCount as number) || 0;
        const comments = (data.commentCount as number) || 0;
        const ratingAvg = (data.ratingAvg as number) || 0;
        const ratingCount = (data.ratingCount as number) || 0;

        // Base score with starting credit of 10 so new recipes decay nicely
        const baseScore = 10 + (likes * 2) + (favorites * 3) + (comments * 2) + (ratingAvg * ratingCount * 4);

        // Calculate age decay
        const createdAt = data.createdAt;
        let ageInDays = 0;
        if (createdAt) {
          const createdMillis = createdAt.toMillis ? createdAt.toMillis() : new Date(createdAt).getTime();
          ageInDays = (now - createdMillis) / (1000 * 60 * 60 * 24);
        }
        if (ageInDays < 0) ageInDays = 0;

        // Halve the score every 14 days
        const decayFactor = 1 / (1 + ageInDays / 14);

        let finalScore = Math.round(baseScore * decayFactor * 100);

        // Prioritize real user recipes: 2.0x boost over system/seeded recipes
        if (!isSystemRecipe) {
          finalScore = Math.round(finalScore * 2.0);
        }

        // Only update if the score has actually changed
        const currentScore = (data.trendingScore as number) || 0;
        if (finalScore !== currentScore) {
          if (operationCount >= 400) {
            // Start a new batch to stay safely under Firestore's 500 limit
            const nextBatch = db.batch();
            batches.push(nextBatch);
            currentBatch = nextBatch;
            operationCount = 0;
            batchCount++;
          }

          currentBatch.update(doc.ref, { trendingScore: finalScore });
          operationCount++;
        }
      });

      if (operationCount > 0 || batches.length > 1) {
        console.log(`Committing ${operationCount} updates across ${batchCount} batches.`);
        await Promise.all(batches.map((b) => b.commit()));
        console.log("Trending scores successfully updated.");
      } else {
        console.log("No score changes detected. Skipping write operations.");
      }
    } catch (error) {
      console.error("Error updating trending scores:", error);
    }
  }
);
