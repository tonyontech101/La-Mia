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
import { GoogleGenAI } from "@google/genai";

// Expanded labels that suggest the image contains food or culinary preparation
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
  "delicacy", "baked goods", "culinary art", "saucepan",
  "wok", "roasting", "steaming", "frying pan", "cutting board",
  "dining", "lunch box", "platter", "beverage",
  "drink", "tea", "coffee", "juice", "hot dog", "frankfurter",
  "sausage", "patty", "burger", "sandwich", "pizza", "pasta",
  "noodle soup", "porridge", "congee", "adobo", "sinigang",
  "filipino food", "asian food"
]);

interface ImageValidationResult {
  isSafe: boolean;
  isFood: boolean;
  labels: string[];
  reason: string;
}

export async function validateImageWithVision(
  imageUrl: string,
  apiKey?: string
): Promise<ImageValidationResult> {
  if (!imageUrl || imageUrl.trim() === "") {
    return {
      isSafe: true,
      isFood: false,
      labels: [],
      reason: "No cover photo URL provided.",
    };
  }

  // 1. Download image to base64 buffer so Cloud Vision and Gemini Vision receive raw bytes
  let base64Image = "";
  let mimeType = "image/jpeg";

  try {
    const imgRes = await fetch(imageUrl);
    if (imgRes.ok) {
      const arrayBuffer = await imgRes.arrayBuffer();
      base64Image = Buffer.from(arrayBuffer).toString("base64");
      mimeType = imgRes.headers.get("content-type") || "image/jpeg";
    } else {
      console.warn(`Could not download image from URL (${imgRes.status}). Falling back to URL reference.`);
    }
  } catch (downloadErr) {
    console.warn("Failed to pre-download image for vision check:", downloadErr);
  }

  // 2. Try Cloud Vision API first
  try {
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-vision"],
    });
    const client = await auth.getClient();
    const accessToken = await client.getAccessToken();

    const imageSource = base64Image
      ? { content: base64Image }
      : { source: { imageUri: imageUrl } };

    const requestBody = {
      requests: [
        {
          image: imageSource,
          features: [
            {
              type: "LABEL_DETECTION",
              maxResults: 20,
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

    if (response.ok) {
      const result = await response.json();
      const annotations = result.responses?.[0];

      // Safe Search check
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

      // Label Detection check
      const labelAnnotations = annotations?.labelAnnotations ?? [];
      const labels: string[] = labelAnnotations.map(
        (l: { description: string }) => l.description.toLowerCase()
      );

      const foodLabelsFound = labels.filter((label) => {
        if (FOOD_LABELS.has(label)) return true;
        // Check substring matches
        for (const food of FOOD_LABELS) {
          if (label.includes(food)) return true;
        }
        return false;
      });

      if (foodLabelsFound.length > 0) {
        return {
          isSafe: true,
          isFood: true,
          labels,
          reason: "",
        };
      }

      // Non-food detected by Cloud Vision
      return {
        isSafe: true,
        isFood: false,
        labels,
        reason: `Image does not appear to contain food. Detected objects: ${labels.slice(0, 6).join(", ")}. Please upload a photo of your dish.`,
      };
    } else {
      const errText = await response.text();
      console.warn("Cloud Vision REST API response was not OK:", response.status, errText);
    }
  } catch (visionErr) {
    console.warn("Cloud Vision API call failed:", visionErr);
  }

  // 3. Multimodal Gemini Vision fallback
  if (apiKey && base64Image) {
    try {
      console.log("Running Gemini Vision fallback for cover photo validation...");
      const ai = new GoogleGenAI({ apiKey });
      const response = await ai.models.generateContent({
        model: "gemini-2.5-flash",
        contents: [
          {
            role: "user",
            parts: [
              {
                text: `You are an image moderation system for "La Mia", a Filipino food recipe sharing application.
Examine this image and determine if it clearly shows food, a cooked dish, cooking ingredients, kitchen food preparation, or culinary beverages.

Reject images depicting:
- Laptops, computer screens, monitors, keyboards, electronic gadgets, desk setups, phones
- People/selfies with no clear food present
- Pets, animals (unless cooked meat dish), furniture, cars, outdoor scenery
- Non-edible items, memes, screenshots, or random objects

Respond with ONLY a valid JSON object (no markdown, no backticks, no code fences):
{"is_food": true/false, "is_safe": true/false, "reason": "brief explanation if rejected"}`,
              },
              {
                inlineData: {
                  mimeType: mimeType.split(";")[0] || "image/jpeg",
                  data: base64Image,
                },
              },
            ],
          },
        ],
      });

      const text = response.text?.trim() ?? "";
      const cleaned = text
        .replace(/^```json\s*/i, "")
        .replace(/^```\s*/i, "")
        .replace(/\s*```$/i, "")
        .trim();
      const parsed = JSON.parse(cleaned);

      const isFood = parsed.is_food === true;
      const isSafe = parsed.is_safe !== false;

      return {
        isSafe,
        isFood,
        labels: ["gemini-vision"],
        reason: isFood
          ? ""
          : (parsed.reason || "The cover photo does not appear to show food. Please upload a clear photo of your dish."),
      };
    } catch (geminiVisionErr) {
      console.error("Gemini Vision fallback failed:", geminiVisionErr);
    }
  }

  // If both vision checks fail, reject rather than passing non-food through
  return {
    isSafe: true,
    isFood: false,
    labels: [],
    reason: "Unable to verify if the photo contains food. Please try uploading another photo.",
  };
}
