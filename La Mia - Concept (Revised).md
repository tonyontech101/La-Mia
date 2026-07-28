# La Mia

**Tagline:** Discover, Cook, and Share Delicious Recipes.

---

## Overview

La Mia is a community-driven food recipe application that helps users discover, cook, and share delicious recipes. Users can browse recipes without an account; signing up is only required for sharing recipes and interacting with the community.

To make everyday cooking easier, La Mia includes smart meal discovery features built around two everyday Filipino cooking questions:

- **"Ano pong ulam?"** – What should I cook today?
- **"What can I cook with what I already have?"**

These are answered by two clearly separated features (see below), so the app feels like a practical daily cooking companion rather than just a recipe archive.

---

## Two Smart Features — Now Clearly Distinct

> **Revision note:** In the original concept, *Cook by Ingredients* and *Ano Pong Ulam?* overlapped heavily (both take ingredients and return matches). They are now split by intent so users are never confused about which to use.

### 🍳 Cook by Ingredients — *You drive it (a search tool)*
The user enters the ingredients they have and La Mia returns every matching recipe, ranked by match. Best when the user is intentionally looking to use up what's in the kitchen.

### 🍽️ Ano Pong Ulam? — *It decides for you (a quick daily suggestion)*
An opinionated, one-tap suggestion engine. Instead of listing everything, it picks a small set of "what to cook today" ideas and lets the user refine with filters (budget, meal type, cooking time, difficulty, servings). Best when the user is undecided.

---

## Ingredient Matching — The Core of the Product (New Detail)

> **Revision note:** Match percentages ("Egg Fried Rice — 100% Match") are the heart of the USP and were previously hand-waved. If matching feels dumb, the whole product feels dumb. The concept now commits to a real approach:

- **Canonical ingredient dictionary** — every ingredient maps to a single canonical entry (e.g., "scallion", "spring onion", "green onion" → one item).
- **Aliases & Filipino/English names** — "kamatis" ↔ "tomato", "bawang" ↔ "garlic".
- **Pantry staples assumed present** — salt, pepper, oil, water, and similar staples are assumed available and excluded from match math (user-configurable).
- **Substitutions** — recognized swaps (e.g., calamansi ↔ lemon) count as partial matches.
- **Match result shows:** match percentage, missing ingredients, cooking time, difficulty, and rating.

Match % = (matched core ingredients) ÷ (total core ingredients), with staples excluded and substitutions weighted.

---

## User Flow

### Guest User
1. Open the app.
2. Browse the recipe dashboard.
3. Search recipes or use Cook by Ingredients.
4. Open a recipe and view: dish image, description, ingredients, step-by-step instructions, prep time, cook time, total time, servings.
5. Use Ano Pong Ulam? for meal recommendations.
6. Save to Favorites, like, comment, or rate — *these prompt login.*

### Recipe Contributor
1. Tap **Share Recipe**.
2. If not logged in → Login or Create an Account → complete registration.
3. Upload: cover photo, title, category, description, ingredients, step-by-step instructions, prep time, cook time, servings.
4. Publish.
5. **Publishing policy (decided — see below):** recipe enters a moderation queue and appears on the dashboard after approval.

---

## Content Moderation & Quality (New — Decision Made)

> **Revision note:** The original said recipes appear "immediately *or* after admin approval." That either/or changes the whole architecture, so it's now decided for launch:

- **Launch:** approval-required (moderation queue) to protect quality and stop spam.
- **Later:** trusted contributors can auto-publish; all recipes get a **report → auto-hide on threshold** system.
- **Upload rate limiting** to prevent spam/abuse.
- **Comment moderation:** report, block, and hide; basic profanity filtering.

## Cold-Start Plan (New)

> **Revision note:** Ingredient matching, "Trending," and "Popular Contributors" are worthless with an empty database.

- Seed the launch with a **curated set of quality Filipino staple recipes** (e.g., adobo, sinigang, tortang talong, fried rice variants) so the app is useful on day one.

---

## Core Features

### 1. Browse Recipes (Home Dashboard)
Featured, Trending, New, and Recommended recipes.

### 2. Recipe Details
Photo, name, author, description, ingredients, step-by-step instructions, prep time, cook time, total time, servings, likes, comments, **rating**.

### 3. Search Recipes
By name, ingredient, category, cuisine, and difficulty — with **combined filtering** (e.g., category + difficulty + max cooking time at once).

### 4. Cook by Ingredients ⭐
Enter available ingredients → Find Recipes → ranked matches (see matching section above).

### 5. Recipe Categories
Breakfast, Lunch, Dinner, Snacks, Desserts, Soup, Vegetables, Chicken, Pork, Beef, Seafood, Filipino, International.

### 6. User Accounts
**Login required for:** sharing, liking, commenting, **rating**, saving favorites, editing your recipes.
**Guests can:** browse, search, use Cook by Ingredients, use Ano Pong Ulam?, view details.

> **Revision note:** *Rating* was in the details spec but had no submit flow and wasn't gated — now added to the login-required list with a submit flow.

### 7. Share Recipe
Cover photo, title, description, ingredients, cooking steps, category, prep time, cook time, servings.

### 8. Favorites
Save recipes for later. **Saved favorites are available offline** (people cook with bad signal / messy hands).

### 9. Likes
Like recipes to highlight popular dishes.

### 10. Comments
Ask questions, share tips, give feedback, share cooking experience. Moderated (see above).

### 11. User Profile
Profile picture, bio, uploaded recipes, favorite recipes, total likes received.

---

## Dashboard Sections
Featured Recipes · Trending Today · New Recipes · Recommended Recipes · Categories · Recently Added · Popular Contributors.

---

## Cross-Cutting Requirements (New)

> **Revision note:** These weren't in the original but you'll want them early.

- **Units & localization:** support metric and cups; English + Tagalog ingredient names.
- **Image handling:** cover photos are central — enforce upload size limits, auto-compression, and a fallback placeholder.
- **Accessibility:** readable contrast, scalable text, screen-reader labels.
- **Performance:** fast search and matching even as the recipe database grows.

---

## Unique Selling Proposition (USP)

Unlike traditional recipe apps that only provide instructions, La Mia answers two everyday questions — *"Ano pong ulam?"* and *"What can I cook with what I have?"* — by combining community recipes with an opinionated daily suggestion engine and genuine ingredient-based matching. It's a practical everyday cooking companion for Filipino households.

**Benefits of ingredient-based cooking:** reduces food waste, saves grocery expenses, cooks with what's on hand, and makes meal planning faster.

---

## Suggested Build Scope

**MVP (Phase 1):** Browse + Recipe Details + Search + Cook by Ingredients + Share Recipe (with moderation) + seeded recipes + accounts/login.

**Phase 2:** Ano Pong Ulam? engine, Likes, Comments, Ratings, Favorites (offline), Profiles, Trending/Popular Contributors.

---

## Top Risks to Watch
1. **Ingredient matching quality** — the #1 technical risk; the USP depends on it.
2. **Content moderation & spam** — a community app lives or dies on content quality.
3. **Cold start** — needs seeded content to feel alive at launch.
