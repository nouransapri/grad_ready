#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = next;
      i += 1;
    }
  }
  return args;
}

async function readCollection(db, name) {
  const snapshot = await db.collection(name).get();
  const docs = snapshot.docs.map((doc) => ({
    id: doc.id,
    data: doc.data(),
  }));
  return docs;
}

async function clearCollection(db, name) {
  const batchSize = 400;
  let removed = 0;
  for (;;) {
    const snapshot = await db.collection(name).limit(batchSize).get();
    if (snapshot.empty) break;
    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
      removed += 1;
    }
    await batch.commit();
    if (snapshot.size < batchSize) break;
  }
  return removed;
}

async function run() {
  const args = parseArgs(process.argv);
  const serviceAccountArg =
    args['service-account'] || process.env.FIREBASE_SERVICE_ACCOUNT || 'scripts/firebase-sa.json';
  const serviceAccountPath = path.isAbsolute(serviceAccountArg)
    ? serviceAccountArg
    : path.resolve(process.cwd(), serviceAccountArg);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
  const db = admin.firestore();

  const targets = ['skills', 'jobs', 'users'];
  const ts = new Date().toISOString().replace(/[:.]/g, '-');
  const outDir = path.resolve(process.cwd(), 'scripts', 'out');
  fs.mkdirSync(outDir, { recursive: true });
  const backupPath = path.join(outDir, `firebase-backup-before-reset-${ts}.json`);

  const backup = {};
  for (const name of targets) {
    const docs = await readCollection(db, name);
    backup[name] = docs;
    console.log(`Backed up ${docs.length} docs from ${name}`);
  }
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  console.log(`Backup written: ${backupPath}`);

  for (const name of targets) {
    const removed = await clearCollection(db, name);
    console.log(`Cleared ${removed} docs from ${name}`);
  }
}

run().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
