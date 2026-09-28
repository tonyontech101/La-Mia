/**
 * La Mia — Bulk Delete Users Script
 *
 * Queries all users from Firebase Authentication and deletes them in batches.
 * Optionally also cleans up their Firestore documents in `users/{uid}`.
 *
 * Usage:
 *   # Preview what users exist without deleting anything:
 *   node delete_all_users.js --dry-run
 *
 *   # Delete all users (with interactive confirmation):
 *   node delete_all_users.js
 *
 *   # Delete all users and skip confirmation:
 *   node delete_all_users.js --force
 *
 *   # Only delete from Auth, do not touch Firestore:
 *   node delete_all_users.js --auth-only
 *
 *   # Exclude specific emails (e.g. admin accounts):
 *   node delete_all_users.js --exclude admin@example.com,test@example.com
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import readline from 'readline';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const SERVICE_ACCOUNT_PATH = join(__dirname, 'serviceAccountKey.json');

// Command line flags
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const FORCE = args.includes('--force') || args.includes('-y');
const AUTH_ONLY = args.includes('--auth-only');

// Parse --exclude arguments (e.g. --exclude email1@test.com,email2@test.com)
const excludeIndex = args.indexOf('--exclude');
const excludedList = [];
if (excludeIndex !== -1 && args[excludeIndex + 1]) {
  excludedList.push(...args[excludeIndex + 1].split(',').map((s) => s.trim().toLowerCase()));
}

if (!existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('\n❌ serviceAccountKey.json not found in tools/ directory!');
  console.error('   Please ensure serviceAccountKey.json is placed in: ' + SERVICE_ACCOUNT_PATH);
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf-8'));

initializeApp({
  credential: cert(serviceAccount),
});

const auth = getAuth();
const db = getFirestore();

function askQuestion(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) =>
    rl.question(query, (ans) => {
      rl.close();
      resolve(ans.trim());
    })
  );
}

async function main() {
  console.log('\n======================================================');
  console.log('           La Mia — Bulk User Deletion Tool           ');
  console.log('======================================================');
  console.log(`Mode:            ${DRY_RUN ? '🔍 DRY RUN (Preview only)' : '⚠️  LIVE DELETION'}`);
  console.log(`Clean Firestore: ${AUTH_ONLY ? 'No (Auth only)' : 'Yes (users/{uid} documents)'}`);
  if (excludedList.length > 0) {
    console.log(`Excluded:        ${excludedList.join(', ')}`);
  }
  console.log('------------------------------------------------------\n');

  console.log('Fetching all users from Firebase Authentication...');
  const allUsers = [];
  let nextPageToken;

  do {
    const listResult = await auth.listUsers(1000, nextPageToken);
    allUsers.push(...listResult.users);
    nextPageToken = listResult.pageToken;
  } while (nextPageToken);

  if (allUsers.length === 0) {
    console.log('No users found in Firebase Authentication.');
    return;
  }

  // Filter out excluded users
  const targetUsers = allUsers.filter((u) => {
    const email = (u.email || '').toLowerCase();
    const uid = u.uid.toLowerCase();
    return !excludedList.includes(email) && !excludedList.includes(uid);
  });

  const skippedCount = allUsers.length - targetUsers.length;

  console.log(`\nFound ${allUsers.length} total user(s).`);
  if (skippedCount > 0) {
    console.log(`Excluded ${skippedCount} user(s) matching exclude filter.`);
  }
  console.log(`Targeting ${targetUsers.length} user(s) for deletion:\n`);

  targetUsers.forEach((u, i) => {
    const provider = u.providerData.map((p) => p.providerId).join(', ') || 'password';
    console.log(
      `  ${String(i + 1).padStart(3, ' ')}. [${u.uid}] ${u.email || '(no email)'} ` +
      `| Provider: ${provider} | Created: ${u.metadata.creationTime}`
    );
  });

  if (targetUsers.length === 0) {
    console.log('\nNo users left to delete after exclusions.');
    return;
  }

  if (DRY_RUN) {
    console.log('\n🔍 [DRY RUN] No changes were made. To execute deletion, run without --dry-run.');
    return;
  }

  // Confirmation prompt if not forced
  if (!FORCE) {
    console.log('\n⚠️  WARNING: This will permanently delete the users listed above!');
    if (!AUTH_ONLY) {
      console.log('   Corresponding Firestore user profiles in `users/{uid}` will also be deleted.');
    }
    const answer = await askQuestion("\nType 'yes' to proceed with deletion: ");
    if (answer.toLowerCase() !== 'yes') {
      console.log('Deletion cancelled by user.');
      return;
    }
  }

  console.log('\nProceeding with deletion...');

  // 1. Delete from Firebase Authentication (in chunks of 1000)
  const uids = targetUsers.map((u) => u.uid);
  const CHUNK_SIZE = 1000;
  let authSuccess = 0;
  let authFailure = 0;

  for (let i = 0; i < uids.length; i += CHUNK_SIZE) {
    const chunk = uids.slice(i, i + CHUNK_SIZE);
    try {
      const deleteResult = await auth.deleteUsers(chunk);
      authSuccess += deleteResult.successCount;
      authFailure += deleteResult.failureCount;

      if (deleteResult.failureCount > 0) {
        deleteResult.errors.forEach((err) => {
          console.error(`  ❌ Failed to delete user index ${err.index}: ${err.error.message}`);
        });
      }
    } catch (err) {
      console.error('  ❌ Error deleting batch:', err);
    }
  }

  console.log(`\n✅ Firebase Auth: Successfully deleted ${authSuccess} user(s). (Failed: ${authFailure})`);

  // 2. Delete from Firestore (if not --auth-only)
  if (!AUTH_ONLY) {
    console.log('\nCleaning up Firestore user documents...');
    let firestoreDeleted = 0;

    for (const uid of uids) {
      try {
        const userDocRef = db.collection('users').doc(uid);
        // recursiveDelete removes the document and any subcollections (e.g. notifications)
        await db.recursiveDelete(userDocRef);
        firestoreDeleted++;
      } catch (err) {
        console.warn(`  ⚠️ Could not delete Firestore doc for ${uid}: ${err.message}`);
      }
    }

    console.log(`✅ Firestore: Cleaned up ${firestoreDeleted} document(s) in 'users' collection.`);
  }

  console.log('\n🎉 Finished user deletion process.\n');
}

main().catch((err) => {
  console.error('\n❌ Fatal error:', err);
  process.exit(1);
});
