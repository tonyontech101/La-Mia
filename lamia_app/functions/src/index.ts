/**
 * La Mia — Cloud Functions
 *
 * Content moderation & recipe validation functions that run server-side.
 * Triggered automatically when recipes are created in Firestore.
 */

import { onRecipeCreate } from "./onRecipeCreate";
import { onRecipeLikeWrite } from "./onRecipeLikeWrite";

export { onRecipeCreate, onRecipeLikeWrite };
