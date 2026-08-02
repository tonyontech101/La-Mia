/**
 * La Mia — Seed Featured & Popular Recipes
 *
 * Since there are no users yet, this script:
 *   1. Sets `isFeatured: true` on a curated list of iconic Filipino dishes
 *   2. Gives well-known dishes realistic initial popularity scores
 *      (likeCount, favoriteCount, ratingAvg, ratingCount, trendingScore)
 *
 * These values give the home screen's "Featured" and "Popular" sections
 * content to display before real user engagement data exists.
 *
 * Usage:  node seed_featured.js
 * Re-run safe: uses Firestore merge, only touches the fields listed below.
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SERVICE_ACCOUNT_PATH = join(__dirname, 'serviceAccountKey.json');

if (!existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('❌ serviceAccountKey.json not found!');
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf-8'));
initializeApp({
  credential: cert(serviceAccount),
});
const db = getFirestore();

// ── Curated Lists ───────────────────────────────────────────────────────────

// Featured recipes: iconic dishes that represent Filipino cuisine well.
// These get `isFeatured: true` and high popularity scores.
const FEATURED = [
  { id: 'ulam-chicken-adobo',         likes: 482, favs: 310, ratingAvg: 4.8, ratingCount: 215, trending: 95 },
  { id: 'sabaw-beef-sinigang',        likes: 437, favs: 285, ratingAvg: 4.7, ratingCount: 198, trending: 90 },
  { id: 'ulam-kare-kare',             likes: 356, favs: 220, ratingAvg: 4.6, ratingCount: 172, trending: 85 },
  { id: 'ulam-lechon-kawali',         likes: 398, favs: 265, ratingAvg: 4.7, ratingCount: 189, trending: 88 },
  { id: 'ulam-crispy-pata',           likes: 375, favs: 240, ratingAvg: 4.6, ratingCount: 165, trending: 82 },
  { id: 'panghimagas-halo-halo',      likes: 420, favs: 295, ratingAvg: 4.8, ratingCount: 205, trending: 92 },
  { id: 'panghimagas-leche-flan',     likes: 345, favs: 230, ratingAvg: 4.7, ratingCount: 158, trending: 80 },
  { id: 'pancit-at-noodles-pancit-canton', likes: 312, favs: 195, ratingAvg: 4.5, ratingCount: 142, trending: 75 },
  { id: 'ulam-kaldereta',             likes: 328, favs: 210, ratingAvg: 4.6, ratingCount: 155, trending: 78 },
  { id: 'sabaw-bulalo',               likes: 365, favs: 245, ratingAvg: 4.7, ratingCount: 178, trending: 84 },
];

// Popular (but not featured): well-known dishes that get moderate popularity.
const POPULAR = [
  { id: 'ulam-bicol-express',         likes: 245, favs: 155, ratingAvg: 4.4, ratingCount: 120, trending: 65 },
  { id: 'ulam-dinuguan',              likes: 210, favs: 130, ratingAvg: 4.3, ratingCount: 105, trending: 58 },
  { id: 'ulam-menudo',                likes: 198, favs: 125, ratingAvg: 4.3, ratingCount: 98,  trending: 55 },
  { id: 'almusal-beef-tapa',          likes: 275, favs: 175, ratingAvg: 4.5, ratingCount: 135, trending: 70 },
  { id: 'almusal-bangsilog',          likes: 260, favs: 165, ratingAvg: 4.4, ratingCount: 128, trending: 68 },
  { id: 'inihaw-inihaw-na-liempo',    likes: 285, favs: 180, ratingAvg: 4.5, ratingCount: 140, trending: 72 },
  { id: 'inihaw-inihaw-na-bangus',    likes: 230, favs: 145, ratingAvg: 4.4, ratingCount: 112, trending: 60 },
  { id: 'merienda-lumpiang-shanghai', likes: 295, favs: 190, ratingAvg: 4.5, ratingCount: 145, trending: 73 },
  { id: 'merienda-kwek-kwek',         likes: 220, favs: 140, ratingAvg: 4.3, ratingCount: 108, trending: 58 },
  { id: 'panghimagas-buko-pandan',    likes: 235, favs: 150, ratingAvg: 4.4, ratingCount: 115, trending: 62 },
  { id: 'kakanin-bibingka',           likes: 255, favs: 160, ratingAvg: 4.5, ratingCount: 125, trending: 66 },
  { id: 'kakanin-puto',               likes: 200, favs: 120, ratingAvg: 4.2, ratingCount: 95,  trending: 52 },
  { id: 'lamang-dagat-sinigang-na-hipon', likes: 240, favs: 155, ratingAvg: 4.4, ratingCount: 118, trending: 63 },
  { id: 'sabaw-sinampalukang-manok',  likes: 185, favs: 110, ratingAvg: 4.2, ratingCount: 88,  trending: 48 },
  { id: 'panghimagas-cassava-cake',   likes: 195, favs: 120, ratingAvg: 4.3, ratingCount: 92,  trending: 50 },
];

// ── Apply updates ───────────────────────────────────────────────────────────

async function run() {
  console.log('\n🌟 Seeding Featured & Popular recipes...\n');

  let updated = 0;
  let skipped = 0;

  for (const entry of FEATURED) {
    const ref = db.collection('recipes').doc(entry.id);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`   ⚠️  ${entry.id} — not found, skipping`);
      skipped++;
      continue;
    }
    await ref.set({
      isFeatured: true,
      likeCount: entry.likes,
      favoriteCount: entry.favs,
      ratingAvg: entry.ratingAvg,
      ratingCount: entry.ratingCount,
      trendingScore: entry.trending,
      updatedAt: new Date(),
    }, { merge: true });
    console.log(`   ⭐ ${entry.id} — featured + popular (${entry.likes} likes, ${entry.ratingAvg}★)`);
    updated++;
  }

  for (const entry of POPULAR) {
    const ref = db.collection('recipes').doc(entry.id);
    const snap = await ref.get();
    if (!snap.exists) {
      console.log(`   ⚠️  ${entry.id} — not found, skipping`);
      skipped++;
      continue;
    }
    await ref.set({
      likeCount: entry.likes,
      favoriteCount: entry.favs,
      ratingAvg: entry.ratingAvg,
      ratingCount: entry.ratingCount,
      trendingScore: entry.trending,
      updatedAt: new Date(),
    }, { merge: true });
    console.log(`   🔥 ${entry.id} — popular (${entry.likes} likes, ${entry.ratingAvg}★)`);
    updated++;
  }

  console.log(`\n✅ Done! Updated: ${updated}, Skipped: ${skipped}\n`);
  console.log('Your home screen now has:');
  console.log(`   ⭐ ${FEATURED.length} Featured recipes (isFeatured: true + high scores)`);
  console.log(`   🔥 ${POPULAR.length} Popular recipes (moderate scores)`);
  console.log('\nFlutter queries:');
  console.log('   Featured → where("isFeatured", "==", true)');
  console.log('   Popular  → orderBy("trendingScore", "desc"), limit(10)\n');
}

run().catch((err) => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});
