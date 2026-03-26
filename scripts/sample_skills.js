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

async function run() {
  const args = parseArgs(process.argv);
  const serviceAccountArg = args['service-account'];
  if (!serviceAccountArg) {
    console.error('Usage: node scripts/sample_skills.js --service-account <key.json>');
    process.exit(1);
  }

  const serviceAccountPath = path.isAbsolute(serviceAccountArg)
    ? serviceAccountArg
    : path.resolve(process.cwd(), serviceAccountArg);
  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`Service account file not found: ${serviceAccountPath}`);
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
  const db = admin.firestore();

  const snapshot = await db.collection('skills').limit(5).get();
  console.log('Sample 5 skills:\n');
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const aliases = Array.isArray(data.aliases) ? data.aliases.join(', ') : '[]';
    const related = Array.isArray(data.relatedSkills)
      ? data.relatedSkills.join(', ')
      : '[]';
    console.log(`- ${doc.id}`);
    console.log(`  aliases: ${aliases || '[]'}`);
    console.log(`  relatedSkills: ${related || '[]'}`);
    console.log(`  domain: ${data.domain || '?'}`);
    console.log(`  demandLevel: ${data.demandLevel || '?'}\n`);
  }
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});

