/**
 * Sets Firebase Auth custom claim "admin: true" for a user.
 * Run once so that user can write to jobs, skills, courses, insights, market_trends in Firestore.
 *
 * Usage:
 *   node set-admin-claim.js <path-to-service-account-key.json> <user-uid>
 *
 * Example:
 *   node set-admin-claim.js ./gradready-service-account.json fg5dfREO6odFYlXlVjB1LliJim82
 *
 * Get UID: Firebase Console → Authentication → Users → copy "User UID"
 * Get key: Firebase Console → Project Settings → Service accounts → Generate new private key
 */

const admin = require('firebase-admin');
const path = require('path');

const keyPath = process.argv[2];
const uid = process.argv[3];

if (!keyPath || !uid) {
  console.error('Usage: node set-admin-claim.js <path-to-service-account-key.json> <user-uid>');
  console.error('Example: node set-admin-claim.js ./gradready-key.json fg5dfREO6odFYlXlVjB1LliJim82');
  process.exit(1);
}

const absoluteKeyPath = path.isAbsolute(keyPath) ? keyPath : path.resolve(process.cwd(), keyPath);

admin.initializeApp({ credential: admin.credential.cert(absoluteKeyPath) });

admin
  .auth()
  .setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log('Admin claim set successfully for UID:', uid);
    console.log('Sign out and sign in again in the app for the new token to take effect.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Error:', err.message);
    process.exit(1);
  });
