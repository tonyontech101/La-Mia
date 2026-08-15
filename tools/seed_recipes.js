/**
 * La Mia — Recipe Seed Script (Firestore + Cloud Storage)
 *
 * Seeds TWO Firestore collections and uploads cover photos to Cloud Storage:
 *
 *   1. recipes/{categorySlug-recipeFolderSlug}
 *      - Doc id = `<category>-<recipe-folder>` slug (e.g. `ulam-chicken-adobo`):
 *        deterministic and idempotent across re-runs, and unique per category so
 *        dishes filed under multiple categories (e.g. Halo-Halo in merienda and
 *        panghimagas) don't collide.
 *      - Fields: title (= name), name, category, region, prepTime/cookTime
 *        (source strings, kept), prepTimeMin/cookTimeMin/totalTimeMin (parsed
 *        numbers or null), servings, difficulty, ingredients, instructions,
 *        tags, coverPhotoUrl, source, status:"approved", zero-init popularity
 *        counters, createdAt, updatedAt.
 *      - UPSERT: `set(doc, {merge:false})` — a re-run fully overwrites the doc
 *        so JSON edits propagate (not the old skip-by-name add).
 *
 *   2. ingredientCatalog/{nameSlug}
 *      - Built from each folder's `ingredients.txt` (a JSON array of
 *        { id, name, package_price, package_size, package_unit }).
 *      - Doc id = slug of the ingredient `name` (lowercased + trimmed).
 *      - MERGED BY NAME: recurring pantry items (Garlic, Soy sauce, ...) share
 *        a single doc; first-seen package_price/size/unit win per run.
 *      - This is a *pricing/package-size* catalog, distinct from the
 *        architecture doc's canonical `ingredients/{canonicalId}` dictionary
 *        (aliases/isPantryStaple/substitutes) — intentionally NOT mixed here.
 *
 * Storage:
 *   recipes/<category>/<recipe-folder>/<image-file>
 *   Mirrors the local `recipes/` tree (collision-proof, easy to browse). Images
 *   are made public via a per-object ACL (`makePublic()`), so Flutter can load
 *   them directly via Image.network(coverPhotoUrl) — no signed URLs required.
 *   Objects already present are REUSED (no re-upload churn on re-runs).
 *
 * Usage:
 *   1. Download your service account key from Firebase Console:
 *      Settings → Service accounts → Generate new private key
 *   2. Save it as `serviceAccountKey.json` in this `tools/` folder
 *   3. Run: npm install
 *   4. (Optional) Override the default bucket via env var:
 *      STORAGE_BUCKET=my-bucket npm run seed
 *   5. PREVIEW (no writes, no Firebase init, works even without a key):
 *      npm run seed:dry      (or: npm run seed -- --dry-run)
 *   6. Seed for real:
 *      npm run seed
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { readFileSync, readdirSync, statSync, existsSync } from 'fs';
import { join, extname, dirname } from 'path';
import { fileURLToPath } from 'url';

// ── Setup ────────────────────────────────────────────────────────────────────

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SERVICE_ACCOUNT_PATH = join(__dirname, 'serviceAccountKey.json');
const RECIPES_DIR = join(__dirname, '..', 'recipes');
const DRY_RUN = process.argv.includes('--dry-run');

// ── Validate prerequisites ──────────────────────────────────────────────────

if (!existsSync(RECIPES_DIR)) {
  console.error(`\n❌ Recipes directory not found at: ${RECIPES_DIR}\n`);
  process.exit(1);
}

// ── Initialize Firebase Admin (skipped entirely in --dry-run) ─────────────────

let db = null;
let bucket = null;
let liveBucketName = null;

if (!DRY_RUN) {
  if (!existsSync(SERVICE_ACCOUNT_PATH)) {
    console.error('\n❌ serviceAccountKey.json not found!');
    console.error('   Download it from Firebase Console:');
    console.error('   Settings → Service accounts → Generate new private key');
    console.error(`   Save it to: ${SERVICE_ACCOUNT_PATH}`);
    console.error('   Tip: run with --dry-run to preview without a key.\n');
    process.exit(1);
  }
  const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf-8'));
  const storageBucket =
    process.env.STORAGE_BUCKET ||
    `${serviceAccount.project_id}.firebasestorage.app`;
  initializeApp({
    credential: cert(serviceAccount),
    storageBucket,
  });
  db = getFirestore();
  bucket = getStorage().bucket();
  liveBucketName = bucket.name;
}

// ── Helpers ─────────────────────────────────────────────────────────────────

const MIME_BY_EXT = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
};

function contentTypeFor(filePath) {
  return MIME_BY_EXT[extname(filePath).toLowerCase()] || 'application/octet-stream';
}

function encodeGcsPath(gcsPath) {
  return gcsPath.split('/').map(encodeURIComponent).join('/');
}

function publicUrlFor(bucketName, gcsPath) {
  return `https://storage.googleapis.com/${bucketName}/${encodeGcsPath(gcsPath)}`;
}

/**
 * Lowercases + trims + kebab-cases a string into a safe Firestore doc id.
 * "Soy sauce" → "soy-sauce", "Chicken Adobo!" → "chicken-adobo".
 */
function slugify(s) {
  return String(s ?? '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * Parses the leading integer off a time string ("15 mins" → 15). Returns the
 * integer (minutes, per the source data) or null if no number is found.
 */
function parseMin(s) {
  if (s == null) return null;
  const m = String(s).match(/\d+/);
  return m ? parseInt(m[0], 10) : null;
}

/**
 * Resolves the intended bucket name for PREVIEW ONLY (dry-run). Safe — just
 * reads/parses the local key file if present and never touches Firebase.
 * Falls back to "<default-bucket>" so dry-run works with no key present.
 */
function previewBucketName() {
  if (process.env.STORAGE_BUCKET) return process.env.STORAGE_BUCKET;
  if (existsSync(SERVICE_ACCOUNT_PATH)) {
    try {
      const sa = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf-8'));
      if (sa.project_id) return `${sa.project_id}.appspot.com`;
    } catch {
      /* ignore — preview only */
    }
  }
  return '<default-bucket>';
}

const previewBucket = DRY_RUN ? previewBucketName() : null;

/**
 * Given a recipe folder (e.g. recipes/ulam/chicken-adobo/), finds the recipe
 * .txt (JSON), the optional ingredients.txt (JSON array), and the image file.
 * Prefers `recipes.txt`; never falls back to `ingredients.txt` for the recipe.
 */
function findRecipeFiles(folderPath) {
  const files = readdirSync(folderPath);
  const recipeTxt =
    files.find((f) => f === 'recipes.txt') ??
    files.find((f) => f.endsWith('.txt') && f !== 'ingredients.txt');
  const ingredientTxt = files.find((f) => f === 'ingredients.txt');
  const imgFile = files.find((f) =>
    ['.jpg', '.jpeg', '.png', '.webp'].some((ext) => f.toLowerCase().endsWith(ext))
  );
  return { recipeTxt, ingredientTxt, imgFile };
}

/**
 * Uploads a cover photo to Cloud Storage (if not already present) and returns
 * its public read URL. Idempotent: existing objects are reused, not re-uploaded.
 */
async function uploadCoverPhoto(localImagePath, gcsPath) {
  const file = bucket.file(gcsPath);
  const [exists] = await file.exists();
  if (exists) {
    console.log(`   🖼️  image already in Storage, reusing`);
    return publicUrlFor(bucket.name, gcsPath);
  }
  await bucket.upload(localImagePath, {
    destination: gcsPath,
    contentType: contentTypeFor(localImagePath),
    resumable: false,
  });
  try {
    await file.makePublic();
  } catch (e) {
    // Ignore metadata race condition if already public or modified
  }
  return publicUrlFor(bucket.name, gcsPath);
}

/**
 * Upserts an entry into ingredientCatalog/{nameSlug} (live) or just records the
 * slug (dry-run). Within a run, the first encounter of a given name wins; later
 * encounters with the same name-slug are skipped (no extra Firestore write).
 * Returns true only when this was a NEW unique entry handled this run.
 */
async function upsertCatalogEntry(entry, seen) {
  if (!entry || !entry.name) return false;
  const slug = slugify(entry.name);
  if (!slug) return false;
  if (seen.has(slug)) return false;
  seen.add(slug);

  if (DRY_RUN) return true; // record only — no Firestore write

  const doc = {
    name: entry.name,
    normalizedName: entry.name.toLowerCase().trim(),
    packagePrice: entry.package_price ?? null,
    packageSize: entry.package_size ?? null,
    packageUnit: entry.package_unit ?? null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  await db.collection('ingredientCatalog').doc(slug).set(doc, { merge: false });
  return true;
}

// ── Main seed function ──────────────────────────────────────────────────────

let printedCoverSample = false;

async function seedRecipes() {
  const categories = readdirSync(RECIPES_DIR).filter((name) =>
    statSync(join(RECIPES_DIR, name)).isDirectory()
  );

  console.log(`\n🍳 La Mia Recipe Seeder (Firestore + Cloud Storage)`);
  if (DRY_RUN) {
    console.log(`   ⚠️  DRY RUN — NOTHING will be written to Firestore or Storage`);
    console.log(`   Preview bucket: ${previewBucket}`);
  } else {
    console.log(`   Bucket: ${liveBucketName}`);
  }
  console.log(`   Found ${categories.length} categories\n`);

  let totalRecipes = 0;
  let totalFailed = 0;
  const catalogSeen = new Set();
  const failures = [];

  for (const category of categories) {
    const categoryPath = join(RECIPES_DIR, category);
    const recipeFolders = readdirSync(categoryPath).filter((name) =>
      statSync(join(categoryPath, name)).isDirectory()
    );

    console.log(`📁 ${category} (${recipeFolders.length} recipes)`);

    for (const recipeFolder of recipeFolders) {
      const recipePath = join(categoryPath, recipeFolder);
      const { recipeTxt, ingredientTxt, imgFile } = findRecipeFiles(recipePath);

      if (!recipeTxt) {
        console.log(`   ⚠️  ${recipeFolder}: No recipes.txt found, skipping`);
        totalFailed++;
        failures.push(`${category}/${recipeFolder}: Missing recipes.txt`);
        continue;
      }

      try {
        // 1. Read & parse the recipe JSON (validates it)
        const recipeData = JSON.parse(readFileSync(join(recipePath, recipeTxt), 'utf-8'));

        const recipeId = `${slugify(category)}-${slugify(recipeFolder)}`;
        const gcsPath = imgFile
          ? `recipes/${category}/${recipeFolder}/${imgFile}`
          : null;

        // 2. Parse + (upsert | record) catalog entries; first-seen wins
        let catalogTotal = 0;
        let catalogNew = 0;
        if (ingredientTxt) {
          const list = JSON.parse(readFileSync(join(recipePath, ingredientTxt), 'utf-8'));
          catalogTotal = Array.isArray(list) ? list.length : 0;
          if (Array.isArray(list)) {
            for (const entry of list) {
              if (await upsertCatalogEntry(entry, catalogSeen)) catalogNew++;
            }
          }
        }

        // 3. Dry run: print the plan, no writes/uploads, then move on
        if (DRY_RUN) {
          if (!printedCoverSample && gcsPath) {
            console.log(`   • [DRY] ${category}/${recipeFolder}`);
            console.log(`        recipeId:  recipes/${recipeId}`);
            console.log(`        coverPath: ${gcsPath}`);
            console.log(`        coverUrl:  ${publicUrlFor(previewBucket, gcsPath)}`);
            console.log(`        catalog:   ${ingredientTxt ? `${catalogTotal} entries (+${catalogNew} new)` : 'none'}`);
            printedCoverSample = true;
          } else {
            console.log(
              `   • [DRY] ${category}/${recipeFolder} → recipes/${recipeId}` +
                ` | cover: ${gcsPath || '(none)'}` +
                ` | catalog: ${ingredientTxt ? `${catalogTotal} entries (+${catalogNew} new)` : 'none'}`
            );
          }
          totalRecipes++;
          continue;
        }

        // 4. Parse numeric time fields
        const prepTimeMin = parseMin(recipeData.prep_time);
        const cookTimeMin = parseMin(recipeData.cook_time);
        const totalTimeMin =
          prepTimeMin != null || cookTimeMin != null
            ? (prepTimeMin ?? 0) + (cookTimeMin ?? 0)
            : null;

        // 5. Upload cover photo (reused if already present in Storage)
        let coverPhotoUrl = '';
        if (gcsPath) {
          coverPhotoUrl = await uploadCoverPhoto(join(recipePath, imgFile), gcsPath);
        } else {
          console.log(`   ⚠️  ${recipeFolder}: No image found, coverPhotoUrl will be empty`);
        }

        // 6. Prepare + upsert the Firestore recipe doc (full overwrite by slug)
        const firestoreDoc = {
          title: recipeData.name,
          name: recipeData.name,
          description: recipeData.description || '',
          category: recipeData.category,
          region: recipeData.region || 'Unknown',
          prepTime: recipeData.prep_time,
          cookTime: recipeData.cook_time,
          prepTimeMin,
          cookTimeMin,
          totalTimeMin,
          servings: recipeData.servings,
          difficulty: recipeData.difficulty,
          ingredients: recipeData.ingredients,
          instructions: recipeData.instructions,
          tags: recipeData.tags || [],
          coverPhotoUrl,
          coverPhotoPath: gcsPath || '',
          source: recipeData.source || '',
          authorId: null,
          authorName: 'La Mia',
          authorPhotoUrl: null,
          isSystemRecipe: true,
          status: 'approved',
          likeCount: 0,
          commentCount: 0,
          favoriteCount: 0,
          ratingAvg: 0,
          ratingCount: 0,
          isFeatured: false,
          trendingScore: 0,
          createdAt: new Date(),
          updatedAt: new Date(),
        };

        await db.collection('recipes').doc(recipeId).set(firestoreDoc, { merge: false });
        console.log(`   ✅ ${recipeData.name} (${recipeId}) +${catalogNew} catalog`);
        totalRecipes++;
      } catch (error) {
        console.log(`   ❌ ${recipeFolder}: ${error.message}`);
        totalFailed++;
        failures.push(`${category}/${recipeFolder}: ${error.message}`);
      }
    }
    console.log('');
  }

  // ── Summary ─────────────────────────────────────────────────────────────
  console.log('─'.repeat(50));
  if (DRY_RUN) {
    console.log(`\n🔎 DRY RUN — nothing was written to Firestore or Storage.`);
    console.log(`   Categories:           ${categories.length}`);
    console.log(`   Recipes planned:      ${totalRecipes}`);
    console.log(`   Recipes skipped/err:  ${totalFailed}`);
    console.log(`   Unique catalog items: ${catalogSeen.size}`);
    console.log(`   Preview bucket:       ${previewBucket}\n`);
  } else {
    console.log(`\n🎉 Seeding complete!`);
    console.log(`   ✅ Recipes seeded:    ${totalRecipes}`);
    console.log(`   ❌ Failed:            ${totalFailed}`);
    console.log(`   🧂 Catalog items:    ${catalogSeen.size}`);
    console.log(`   📊 Total folders:    ${totalRecipes + totalFailed}\n`);
  }

  if (failures.length > 0) {
    console.log('⚠️  Failures:');
    for (const f of failures) console.log(`   - ${f}`);
    console.log('');
  }
}

// ── Run ─────────────────────────────────────────────────────────────────────

seedRecipes()
  .then(() => {
    console.log(
      DRY_RUN
        ? 'Done (dry run — no writes).\n'
        : 'Done! You can now delete this tools/ folder if you like.\n'
    );
    process.exit(0);
  })
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });