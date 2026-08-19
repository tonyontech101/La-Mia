/**
 * validateImageWithVision — checks whether a cover photo contains food
 * using the Google Cloud Vision API (Label Detection).
 *
 * The Cloud Vision API is called using the service account credentials
 * that Cloud Functions automatically inherits from the Firebase project,
 * so no separate API key is needed.
 *
 * Returns:
 *  - isFood: boolean — true if food-related labels are detected
 *  - labels: string[] — all labels detected in the image
 *  - reason: string — explanation if flagged
 */

// We use the REST API directly to avoid a heavy dependency on the
// @google-cloud/vision client library. Cloud Functions' default
// service account provides the auth automatically via google-auth-library.
import { GoogleAuth } from "google-auth-library";

// Labels that suggest the image contains food
const FOOD_LABELS = new Set([
  "food", "dish", "cuisine", "meal", "recipe", "ingredient",
  "cooking", "baking", "plate", "bowl", "snack", "dessert",
  "breakfast", "lunch", "dinner", "soup", "salad", "meat",
  "vegetable", "fruit", "seafood", "rice", "noodle", "bread",
  "pastry", "cake", "grilled", "fried", "stew", "broth",
  "chicken", "pork", "beef", "fish", "shrimp", "egg",
  "produce", "comfort food", "fast food", "side dish",
  "staple food", "finger food", "street food", "appetizer",
  "condiment", "sauce", "spice", "herb", "garnish",
  "tableware", "cookware", "kitchen", "pan", "pot",
]);

interface ImageValidationResult {
  isSafe: boolean;
  isFood: boolean;
  labels: string[];
  reason: string;
}

export async function validateImageWithVision(
  imageUrl: string
): Promise<ImageValidationResult> {
  if (!imageUrl || imageUrl.trim() === "") {
    return {
      isSafe: true,
      isFood: false,
      labels: [],
      reason: "No cover photo URL provided.",
    };
  }

  try {
    // Use Application Default Credentials (Cloud Functions service account)
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-vision"],
    });
    const client = await auth.getClient();
    const accessToken = await client.getAccessToken();

    const requestBody = {
      requests: [
        {
          image: {
            source: {
              imageUri: imageUrl,
            },
          },
          features: [
            {
              type: "LABEL_DETECTION",
              maxResults: 15,
            },
            {
              type: "SAFE_SEARCH_DETECTION",
            },
          ],
        },
      ],
    };

    const response = await fetch(
      "https://vision.googleapis.com/v1/images:annotate",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(requestBody),
      }
    );

    if (!response.ok) {
      const errText = await response.text();
      console.error("Vision API error:", response.status, errText);
      // Fail open — pass through
      return {
        isSafe: true,
        isFood: true,
        labels: [],
        reason: "Vision API error; passed through.",
      };
    }

    const result = await response.json();
    const annotations = result.responses?.[0];

    // ── Check Safe Search ─────────────────────────────────────────────
    const safeSearch = annotations?.safeSearchAnnotation;
    if (safeSearch) {
      const dangerLevels = ["LIKELY", "VERY_LIKELY"];
      if (
        dangerLevels.includes(safeSearch.adult) ||
        dangerLevels.includes(safeSearch.violence) ||
        dangerLevels.includes(safeSearch.racy)
      ) {
        return {
          isSafe: false,
          isFood: false,
          labels: [],
          reason: "Image flagged for inappropriate content (adult/violence/racy).",
        };
      }
    }

    // ── Check Labels for food ─────────────────────────────────────────
    const labelAnnotations = annotations?.labelAnnotations ?? [];
    const labels: string[] = labelAnnotations.map(
      (l: { description: string }) => l.description.toLowerCase()
    );

    const foodLabelsFound = labels.filter((label) => FOOD_LABELS.has(label));

    if (foodLabelsFound.length > 0) {
      return {
        isSafe: true,
        isFood: true,
        labels,
        reason: "",
      };
    }

    // No explicit food labels found but safe
    return {
      isSafe: true,
      isFood: false,
      labels,
      reason: `No food-related labels detected. Labels found: ${labels.join(", ")}`,
    };
  } catch (error) {
    console.error("Vision API validation error:", error);
    // Fail open
    return {
      isSafe: true,
      isFood: true,
      labels: [],
      reason: "Vision validation unavailable; passed through.",
    };
  }
}
