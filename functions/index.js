const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Returns true if the user is admin via custom claim or admins/{uid} document.
 */
async function callerIsAdmin(uid) {
  const user = await admin.auth().getUser(uid);
  if (user.customClaims && user.customClaims.admin === true) return true;
  const snap = await admin.firestore().collection('admins').doc(uid).get();
  return snap.exists;
}

/**
 * Promotes a user to admin: sets custom claim admin:true and creates admins/{uid}.
 * Client apps must not rely on users/{uid}.role; privileges are claims + admins/* only.
 * Caller must already be an admin (claim or Firestore doc).
 *
 * data: { uid: string } — target user's Firebase Auth UID
 */
exports.makeAdmin = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Must be signed in.',
    );
  }
  const callerUid = context.auth.uid;
  if (!(await callerIsAdmin(callerUid))) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only existing admins can promote users.',
    );
  }

  const targetUid = typeof data?.uid === 'string' ? data.uid.trim() : '';
  if (!targetUid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Field "uid" is required.',
    );
  }

  await admin.firestore().collection('admins').doc(targetUid).set(
    {
      promotedAt: admin.firestore.FieldValue.serverTimestamp(),
      promotedBy: callerUid,
    },
    { merge: true },
  );

  await admin.auth().setCustomUserClaims(targetUid, { admin: true });

  return { ok: true, uid: targetUid };
});
