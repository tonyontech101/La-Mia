/**
 * validateTextWithGemini — checks whether recipe text content is actually
 * about food/cooking, using the Gemini API.
 *
 * Returns an object with:
 *  - isRecipe: boolean — true if the content appears to be a real recipe
 *  - reason: string — explanation of why it was flagged (empty if valid)
 */

import { GoogleGenAI } from "@google/genai";

// Valid categories the app uses — must match Firestore rules & Flutter app
const VALID_CATEGORIES = [
  "Almusal", "Ulam", "Sabaw", "Merienda",
  "Panghimagas", "Gulay", "Inihaw", "Lamang Dagat", "Pulutan",
];

interface TextValidationResult {
  isRecipe: boolean;
  reason: string;
}

export async function validateTextWithGemini(
  apiKey: string,
  data: {
    name: string;
    description: string;
    category: string;
    ingredients: string[];
    instructions: string[];
  }
): Promise<TextValidationResult> {
  // ── Quick heuristic checks (no API call needed) ──────────────────────

  // Check for URLs in title or description (spam signal)
  const urlPattern = /https?:\/\/|www\.|\.com|\.net|\.org|\.ph/i;
  if (urlPattern.test(data.name) || urlPattern.test(data.description)) {
    return {
      isRecipe: false,
      reason: "Title or description contains URLs — likely spam.",
    };
  }

  // Check for category validity
  if (!VALID_CATEGORIES.includes(data.category)) {
    return {
      isRecipe: false,
      reason: `Invalid category "${data.category}".`,
    };
  }

  // Check title is not all caps (spam signal)
  if (data.name.length > 5 && data.name === data.name.toUpperCase()) {
    return {
      isRecipe: false,
      reason: "Title is all uppercase — likely spam.",
    };
  }

  // ── Gemini API check ─────────────────────────────────────────────────

  try {
    const ai = new GoogleGenAI({ apiKey });

    const ingredientsSample = data.ingredients.slice(0, 5).join(", ");
    const instructionsSample = data.instructions.slice(0, 3).join(" | ");

    const prompt = `You are a content moderator for a Filipino food recipe app called "La Mia".

Your job is to determine if the following submission is a genuine food recipe or not.

A VALID recipe must:
- Have a title that refers to a food dish, beverage, or cooking (in English, Tagalog, Cebuano, Ilocano, or any Philippine language/dialect)
- Have ingredients that are actual edible food items
- Have instructions that describe cooking/food preparation steps

REJECT if:
- The content is about non-food objects or topics (keyboards, watches, electronics, furniture, gadgets, ads, jokes, spam, gibberish)
- Any of the ingredients are non-edible items (e.g. "keyboard", "relo", "computer", "plastic", "phone")
- The instructions do not describe food preparation

Submission:
- Title: "${data.name}"
- Description: "${data.description}"
- Category: "${data.category}"
- Ingredients (first 5): ${ingredientsSample}
- Instructions (first 3): ${instructionsSample}

Respond with ONLY a JSON object (no markdown, no backticks, no code fences):
{"is_recipe": true/false, "reason": "brief explanation"}`;

    const candidateModels = ["gemini-2.5-flash", "gemini-2.0-flash"];
    let responseText = "";
    let lastError: unknown = null;

    for (const model of candidateModels) {
      try {
        const response = await ai.models.generateContent({
          model,
          contents: prompt,
        });
        responseText = response.text?.trim() ?? "";
        if (responseText) break;
      } catch (err) {
        lastError = err;
        console.warn(`Model ${model} failed, trying next candidate:`, err);
      }
    }

    if (!responseText) {
      throw lastError || new Error("No response from AI models");
    }

    const text = responseText;

    // Parse the JSON response
    // Strip markdown code fences if present
    const cleaned = text
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();

    const result = JSON.parse(cleaned);

    return {
      isRecipe: result.is_recipe === true,
      reason: result.reason ?? "",
    };
  } catch (error) {
    console.error("Gemini validation error:", error);
    return {
      isRecipe: false, // Strict: do not auto-approve if AI check fails
      reason: `AI check error: ${error instanceof Error ? error.message : String(error)}`,
    };
  }
}
