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
    console.error('Usage: node scripts/check_skills_intelligence.js --service-account <key.json>');
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

  console.log('Enhanced Skills Intelligence Check...\n');

  const snapshot = await db.collection('skills').get();
  let verified = 0;
  let hasAliases = 0;
  let hasRelated = 0;
  let hasDomain = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const aliasesCount = Array.isArray(data.aliases) ? data.aliases.length : 0;
    const relatedCount = Array.isArray(data.relatedSkills) ? data.relatedSkills.length : 0;
    const isVerified = data.isVerified === true;
    if (isVerified) verified += 1;
    if (aliasesCount > 0) hasAliases += 1;
    if (relatedCount > 0) hasRelated += 1;
    if (String(data.domain || '').trim().length > 0) hasDomain += 1;
  }

  const total = snapshot.size || 1;
  const pct = (n) => ((n / total) * 100).toFixed(1);

  console.log(`GLOBAL COVERAGE (${snapshot.size} skills):`);
  console.log(`Verified: ${verified}/${snapshot.size} (${pct(verified)}%)`);
  console.log(`Has Aliases: ${hasAliases}/${snapshot.size} (${pct(hasAliases)}%)`);
  console.log(`Has Related: ${hasRelated}/${snapshot.size} (${pct(hasRelated)}%)`);
  console.log(`Has Domain: ${hasDomain}/${snapshot.size} (${pct(hasDomain)}%)`);

  const sampleSize = 5;
  const docs = [...snapshot.docs];
  for (let i = docs.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [docs[i], docs[j]] = [docs[j], docs[i]];
  }
  const sample = docs.slice(0, Math.min(sampleSize, docs.length));

  console.log('\nRANDOM SAMPLE:');
  sample.forEach((doc, idx) => {
    const data = doc.data() || {};
    const aliases = Array.isArray(data.aliases) ? data.aliases.length : 0;
    const related = Array.isArray(data.relatedSkills) ? data.relatedSkills : [];
    console.log(`${idx + 1}. ${doc.id}`);
    console.log(`   verified: ${data.isVerified === true}`);
    console.log(`   aliases: ${aliases}`);
    console.log(`   related: ${related.length} [${related.slice(0, 3).join(', ')}]`);
    console.log(`   domain: ${data.domain || 'N/A'} (${data.demandLevel || 'N/A'})`);
  });

  console.log('\nSkills Intelligence check complete.');
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});

