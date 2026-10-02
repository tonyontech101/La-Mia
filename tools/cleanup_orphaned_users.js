/**
 * La Mia — Cleanup Orphaned Firestore Users
 *
 * Scans Firestore `users` collection and deletes documents whose UID
 * does not exist in Firebase Authentication.
 *
 * Usage:
 *   node cleanup_orphaned_users.js --dry-run
 *   node cleanup_orphaned_users.js --force
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SERVICE_ACCOUNT_PATH = join(__dirname, 'serviceAccountKey.json');

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const FORCE = args.includes('--force') || args.includes('-y');

if (!existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('\n❌ serviceAccountKey.json not found in tools/ directory!');
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf-8'));
initializeApp({ credential: cert(serviceAccount) });

const auth = getAuth();
const db = getFirestore();

async function main() {
  console.log('🔍 Fetching all users from Firebase Auth...');
  const authUsers = await auth.listUsers();
  const validAuthUids = new Set(authUsers.users.map((u) => u.uid));
  console.log(`Found ${validAuthUids.size} user(s) in Firebase Auth.`);

  console.log('🔍 Fetching all documents from Firestore `users` collection...');
  const firestoreUsersSnap = await db.collection('users').get();
  console.log(`Found ${firestoreUsersSnap.size} document(s) in Firestore \`users\`.`);

  const orphanedDocs = [];
  for (const doc of firestoreUsersSnap.docs) {
    if (!validAuthUids.has(doc.id)) {
      orphanedDocs.push(doc);
    }
  }

  if (orphanedDocs.length === 0) {
    console.log('\n✅ No orphaned user documents found. Everything is in sync!');
    return;
  }

  console.log(`\n⚠️  Found ${orphanedDocs.length} orphaned Firestore user document(s):`);
  orphanedDocs.forEach((doc, idx) => {
    const data = doc.data();
    console.log(
      `  ${idx + 1}. [${doc.id}] displayName: "${data.displayName || '(none)'}", createdAt: ${
        data.createdAt ? JSON.stringify(data.createdAt) : '(none)'
      }`
    );
  });

  if (DRY_RUN) {
    console.log('\n🔍 [DRY RUN] No documents deleted. Run with --force to delete orphaned documents.');
    return;
  }

  if (!FORCE) {
    console.log('\nPass --force or -y to proceed with deletion.');
    return;
  }

  console.log('\n🗑️ Deleting orphaned Firestore user documents...');
  let deletedCount = 0;
  for (const doc of orphanedDocs) {
    try {
      await db.recursiveDelete(doc.ref);
      console.log(`  ✓ Deleted: ${doc.id} (${doc.data().displayName})`);
      deletedCount++;
    } catch (err) {
      console.error(`  ❌ Failed to delete ${doc.id}: ${err.message}`);
    }
  }

  console.log(`\n✅ Successfully deleted ${deletedCount} orphaned user document(s).\n`);
}

main().catch((err) => {
  console.error('\n❌ Fatal error:', err);
  process.exit(1);
});
