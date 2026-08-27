/**
 * La Mia — Cloud Functions
 *
 * Content moderation & recipe validation functions that run server-side.
 * Triggered automatically when recipes are created or social actions occur
 * in Firestore.
 */

import { onRecipeCreate } from "./onRecipeCreate";
import { onRecipeLikeWrite } from "./onRecipeLikeWrite";
import { onFavoriteWrite } from "./onFavoriteWrite";

export { onRecipeCreate, onRecipeLikeWrite, onFavoriteWrite };
