/**
 * La Mia — Recipe Seed Script (Firestore Only)
 *
 * Uploads all recipe data (.txt JSON) from the local `recipes/` folder
 * to Cloud Firestore. Images are bundled as local assets in the Flutter
 * app instead of being uploaded to Cloud Storage.
 *
 * Usage:
 *   1. Download your service account key from Firebase Console:
 *      Settings → Service accounts → Generate new private key
 *   2. Save it as `serviceAccountKey.json` in this `tools/` folder
 *   3. Run: npm install
 *   4. Run: npm run seed
 *
 * This script is idempotent — it checks for existing documents and skips them.
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, readdirSync, statSync, existsSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

// ── Setup ────────────────────────────────────────────────────────────────────

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SERVICE_ACCOUNT_PATH = join(__dirname, 'serviceAccountKey.json');
const RECIPES_DIR = join(__dirname, '..', 'recipes');

// ── Validate prerequisites ──────────────────────────────────────────────────

if (!existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('\n❌ serviceAccountKey.json not found!');
  console.error('   Download it from Firebase Console:');
  console.error('   Settings → Service accounts → Generate new private key');
  console.error(`   Save it to: ${SERVICE_ACCOUNT_PATH}\n`);
  process.exit(1);
}

if (!existsSync(RECIPES_DIR)) {
  console.error(`\n❌ Recipes directory not found at: ${RECIPES_DIR}\n`);
  process.exit(1);
}

// ── Initialize Firebase Admin ───────────────────────────────────────────────

const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf-8'));

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

// ── Helper: find recipe files in a folder ───────────────────────────────────

/**
 * Given a recipe folder (e.g. `recipes/ulam/chicken-adobo/`), finds the
 * `.txt` (JSON) and image files inside.
 */
function findRecipeFiles(folderPath) {
  const files = readdirSync(folderPath);
  const txtFile = files.find((f) => f.endsWith('.txt'));
  const imgFile = files.find((f) =>
    ['.jpg', '.jpeg', '.png', '.webp'].some((ext) =>
      f.toLowerCase().endsWith(ext)
    )
  );
  return { txtFile, imgFile };
}

// ── Main seed function ──────────────────────────────────────────────────────

async function seedRecipes() {
  const categories = readdirSync(RECIPES_DIR).filter((name) => {
    const fullPath = join(RECIPES_DIR, name);
    return statSync(fullPath).isDirectory();
  });

  console.log(`\n🍳 La Mia Recipe Seeder (Firestore only)`);
  console.log(`   Found ${categories.length} categories\n`);

  let totalUploaded = 0;
  let totalSkipped = 0;
  let totalFailed = 0;
  const failures = [];

  for (const category of categories) {
    const categoryPath = join(RECIPES_DIR, category);
    const recipeFolders = readdirSync(categoryPath).filter((name) => {
      return statSync(join(categoryPath, name)).isDirectory();
    });

    console.log(`📁 ${category} (${recipeFolders.length} recipes)`);

    for (const recipeFolder of recipeFolders) {
      const recipePath = join(categoryPath, recipeFolder);
      const { txtFile, imgFile } = findRecipeFiles(recipePath);

      if (!txtFile) {
        console.log(`   ⚠️  ${recipeFolder}: No .txt file found, skipping`);
        totalFailed++;
        failures.push(`${category}/${recipeFolder}: Missing .txt file`);
        continue;
      }

      try {
        // 1. Read and parse the recipe JSON
        const rawJson = readFileSync(join(recipePath, txtFile), 'utf-8');
        const recipeData = JSON.parse(rawJson);

        // 2. Build the local asset path for the image
        //    This matches the Flutter asset path:
        //    assets/images/recipes/{category}/{image-file}
        const localImagePath = imgFile
          ? `assets/images/recipes/${category}/${imgFile}`
          : '';

        // 3. Prepare Firestore document (camelCase keys for consistency)
        const firestoreDoc = {
          name: recipeData.name,
          category: recipeData.category,
          region: recipeData.region || 'Unknown',
          prepTime: recipeData.prep_time,
          cookTime: recipeData.cook_time,
          servings: recipeData.servings,
          difficulty: recipeData.difficulty,
          ingredients: recipeData.ingredients,
          instructions: recipeData.instructions,
          tags: recipeData.tags || [],
          imagePath: localImagePath, // local asset path instead of URL
          source: recipeData.source || '',
          createdAt: new Date(),
        };

        // 4. Check if a recipe with this name already exists
        const existing = await db
          .collection('recipes')
          .where('name', '==', recipeData.name)
          .limit(1)
          .get();

        if (!existing.empty) {
          console.log(`   ⏭️  ${recipeData.name} (already exists)`);
          totalSkipped++;
          continue;
        }

        // 5. Write to Firestore (auto-generated ID)
        await db.collection('recipes').add(firestoreDoc);
        console.log(`   ✅ ${recipeData.name}`);
        totalUploaded++;
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
  console.log(`\n🎉 Seeding complete!`);
  console.log(`   ✅ Uploaded:  ${totalUploaded}`);
  console.log(`   ⏭️  Skipped:   ${totalSkipped}`);
  console.log(`   ❌ Failed:    ${totalFailed}`);
  console.log(`   📊 Total:     ${totalUploaded + totalSkipped + totalFailed}\n`);

  if (failures.length > 0) {
    console.log('⚠️  Failures:');
    for (const f of failures) {
      console.log(`   - ${f}`);
    }
    console.log('');
  }
}

// ── Run ─────────────────────────────────────────────────────────────────────

seedRecipes()
  .then(() => {
    console.log('Done! You can now delete this tools/ folder if you like.\n');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
