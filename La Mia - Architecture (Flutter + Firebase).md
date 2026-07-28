# La Mia — Technical Architecture (Flutter + Firebase)

Version 1.0 · Based on *La Mia - Concept (Revised).md*

This document defines the app architecture, tech stack, data model, security model, and the design of the two flagship features (Cook by Ingredients + Ano Pong Ulam?). It is the contract the Frontend and Backend engineers build against.

---

## 1. Tech Stack

| Layer | Choice | Why |
|---|---|---|
| App framework | **Flutter** (Dart, stable channel) | Single codebase for Android/iOS (+ web later) |
| State management | **Riverpod** (v2, code-gen) | Compile-safe, testable, no BuildContext coupling, good for async/streams |
| Navigation | **go_router** | Declarative routing, deep links, guest vs auth guards |
| Auth | **Firebase Auth** | Email/password + Google Sign-In; anonymous browsing needs no auth |
| Database | **Cloud Firestore** | Realtime, offline persistence, scales for community content |
| File storage | **Cloud Storage for Firebase** | Recipe cover photos, profile pictures |
| Server logic | **Cloud Functions** (Node/TS) | Ingredient matching, moderation, denormalized counters, notifications |
| Search | **Firestore queries** (MVP) → **Algolia/Typesense** (Phase 2) | Firestore can't do full-text; extract to search service when needed |
| Messaging | **Firebase Cloud Messaging** | Recipe approved, new comment, etc. |
| Abuse protection | **Firebase App Check** | Blocks non-app clients from hitting APIs |
| Monitoring | **Crashlytics + Analytics + Performance** | Quality signals |
| Config | **Remote Config** | Feature flags, pantry-staple list, tunable match weights |

---

## 2. App Architecture — Clean/Layered

Feature-first structure with a clean separation of Presentation → Domain → Data. Each feature owns its slice.

```
lib/
├── main.dart
├── app/
│   ├── app.dart                 # MaterialApp.router, theme
│   ├── router.dart              # go_router config + auth/guest guards
│   └── theme/                   # design system (colors, typography, spacing)
├── core/
│   ├── error/                   # Failure/Exception types, Result<T>
│   ├── network/                 # connectivity, retry helpers
│   ├── firebase/                # Firebase init, providers
│   ├── utils/                   # formatters (time, servings), validators
│   └── widgets/                 # shared reusable widgets
├── features/
│   ├── auth/
│   │   ├── data/                # AuthRepositoryImpl, FirebaseAuthDataSource
│   │   ├── domain/              # entities, repository interface, usecases
│   │   └── presentation/        # screens, controllers (Riverpod), widgets
│   ├── recipes/                 # browse, details, dashboard
│   ├── search/
│   ├── cook_by_ingredients/     # ⭐ ingredient matching UI
│   ├── ano_pong_ulam/           # daily suggestion engine UI
│   ├── share_recipe/            # upload + edit flow
│   ├── favorites/               # offline-capable
│   ├── social/                  # likes, comments, ratings
│   └── profile/
└── shared/
    ├── models/                  # cross-feature DTOs
    └── providers/               # global Riverpod providers
```

**Layer rules**
- **Presentation**: Widgets + Riverpod controllers (`AsyncNotifier`). No Firebase imports here.
- **Domain**: Pure Dart. Entities, repository *interfaces*, use cases. No Flutter/Firebase.
- **Data**: Repository *implementations* + Firebase data sources. Maps Firestore docs ↔ domain entities.

Dependency direction always points inward: Presentation → Domain ← Data.

---

## 3. Firestore Data Model

Firestore is NoSQL — model for read patterns and denormalize counters. Collections:

### `users/{userId}`
```
displayName, bio, photoUrl,
recipeCount, totalLikesReceived,   // denormalized, updated by Functions
role: "user" | "trusted" | "admin",
createdAt
```

### `recipes/{recipeId}`
```
title, description, authorId, authorName, authorPhotoUrl,  // denormalized author
coverPhotoUrl, category, cuisine, difficulty,
prepTimeMin, cookTimeMin, totalTimeMin, servings,
steps: [ { order, text, imageUrl? } ],
ingredients: [ { raw, canonicalId, quantity, unit, optional } ],
canonicalIngredientIds: [ "egg", "onion", "tomato" ],  // ⭐ flattened for array-contains matching
status: "pending" | "approved" | "rejected" | "hidden",
likeCount, commentCount, favoriteCount, ratingAvg, ratingCount,  // denormalized
isFeatured, trendingScore,
createdAt, updatedAt, approvedAt
```

Subcollections:
- `recipes/{id}/comments/{commentId}` → `authorId, authorName, text, createdAt, reportCount`
- `recipes/{id}/ratings/{userId}` → `value (1-5), createdAt` (doc id = userId enforces one rating per user)

### `favorites/{userId}/items/{recipeId}`
Small doc `{ recipeId, savedAt }`. Kept per-user for offline sync; recipe snapshot cached client-side.

### `likes/{recipeId}/users/{userId}`
Existence = liked. Function updates `recipes.likeCount`.

### `ingredients/{canonicalId}` (the matching backbone)
```
canonicalId: "onion",
displayName: "Onion",
aliases: ["sibuyas", "red onion", "white onion"],
isPantryStaple: false,
substitutes: ["shallot"]
```

### `moderationQueue/{recipeId}`
Mirrors pending recipes for admin review (or query `recipes where status == pending`).

### `reports/{reportId}`
`{ targetType: "recipe"|"comment", targetId, reason, reporterId, createdAt }`

---

## 4. ⭐ Cook by Ingredients — Matching Architecture

This is the #1 technical risk, so matching logic lives server-side in a **Cloud Function** (callable) for consistency and to protect the algorithm.

**Flow:**
1. User enters raw ingredient strings in Flutter.
2. Client normalizes lightly, then calls `matchRecipesByIngredients(rawIngredients[])`.
3. Function:
   - Resolves each raw string → `canonicalId` via `ingredients` collection (aliases + fuzzy match).
   - Drops pantry staples (from Remote Config list).
   - Queries `recipes` with `array-contains-any` on `canonicalIngredientIds` (approved only), gets candidates.
   - For each candidate computes:
     `matchPct = matchedCore / totalCore`, with substitutions weighted (e.g., 0.7).
   - Returns sorted list: `{ recipeId, matchPct, missingIngredients[], cookTime, difficulty, ratingAvg }`.

**Why server-side:** consistent scoring, tunable weights via Remote Config, avoids shipping the ingredient dictionary to every client, and keeps the "secret sauce" off-device.

**Ano Pong Ulam?** reuses the same matcher but is *opinionated*: applies user filters (budget, mealType, time, difficulty, servings), then returns a **small randomized top-N** rather than the full list.

---

## 5. Security Model

### Auth & access
- **Guests** browse via anonymous/no auth — read access to `approved` recipes only.
- Login required (enforced in rules + UI) for: share, like, comment, rate, favorite, edit-own.

### Firestore Security Rules (key intent — final rules written by Backend engineer)
```
match /recipes/{id} {
  allow read: if resource.data.status == "approved"
              || request.auth.uid == resource.data.authorId
              || isAdmin();
  allow create: if isSignedIn()
              && request.resource.data.authorId == request.auth.uid
              && request.resource.data.status == "pending";   // can't self-approve
  allow update: if (isAuthor(id) && !changingStatus())        // edit own content only
              || isAdmin();                                    // only admin approves
  allow delete: if isAuthor(id) || isAdmin();
}
match /recipes/{id}/ratings/{userId} {
  allow write: if isSignedIn() && request.auth.uid == userId; // one rating per user
}
```
- **Counters** (`likeCount`, `ratingAvg`, etc.) are written **only by Cloud Functions**, never by clients — clients can't forge popularity.
- **App Check** enforced on Functions + Firestore to block non-app traffic.
- **Storage rules**: only owner writes to their paths; image size/type validated.

> Security note: All popularity/moderation-sensitive fields are server-authoritative. Clients never set `status`, counters, or trending scores directly.

---

## 6. Cloud Functions (server logic)

| Function | Trigger | Purpose |
|---|---|---|
| `matchRecipesByIngredients` | Callable | Ingredient matching (§4) |
| `onRecipeCreate` | Firestore create | Add to moderation queue, notify admin |
| `onRecipeApproved` | Firestore update | Set approvedAt, bump author recipeCount, notify author (FCM) |
| `onLikeWrite` | Firestore create/delete | Maintain `likeCount`, author `totalLikesReceived` |
| `onRatingWrite` | Firestore write | Recompute `ratingAvg`, `ratingCount` |
| `onCommentCreate` | Firestore create | Bump `commentCount`, notify recipe author |
| `onReportThreshold` | Firestore create | Auto-hide content when reports exceed threshold |
| `computeTrending` | Scheduled (hourly) | Update `trendingScore` from recent likes/views |

---

## 7. Offline & Performance

- **Firestore offline persistence** enabled — favorites and recently-viewed recipes readable offline (concept requirement).
- **Image handling**: compress on-device before upload (target ~1080px, WebP/JPEG); Storage rules cap size; cached with `cached_network_image`; placeholder fallback.
- **Pagination**: dashboard and search use cursor pagination (`startAfter`) — never load whole collections.
- **Search**: MVP uses Firestore composite indexes for category/difficulty/time filters; full-text search deferred to Algolia/Typesense in Phase 2 (Firestore can't do substring search).

---

## 8. Environments & CI

- **Flavors**: `dev`, `staging`, `prod` → separate Firebase projects (isolated data + rules).
- **CI**: analyze + test + build on PR; deploy Functions/rules via CI to staging then prod.
- **Seed script**: loads curated Filipino staple recipes + canonical ingredient dictionary (cold-start requirement).

---

## 9. Build Order (maps to concept's MVP → Phase 2)

**MVP**
1. Firebase project + flavors + App Check.
2. Auth (guest browsing + email/Google).
3. Recipe data model + seed script + ingredient dictionary.
4. Browse dashboard + Recipe details + Search with filters.
5. Cook by Ingredients (matching Function).
6. Share Recipe + moderation queue + admin approval.

**Phase 2**
7. Ano Pong Ulam? engine.
8. Likes, Comments, Ratings (+ counter Functions).
9. Favorites (offline) + Profiles.
10. Trending/Popular Contributors + FCM notifications.

---

## 10. Key Dependencies (pinned at implementation time)
`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging`, `firebase_app_check`, `firebase_remote_config`, `firebase_crashlytics`, `firebase_analytics`, `google_sign_in`, `flutter_riverpod` + `riverpod_generator`, `go_router`, `cached_network_image`, `image_picker`, `image` (compression), `freezed` + `json_serializable`.
