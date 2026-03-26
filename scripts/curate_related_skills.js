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

function canonicalSkillId(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function uniqueIds(values) {
  const seen = new Set();
  const out = [];
  for (const v of values || []) {
    const id = canonicalSkillId(v);
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out;
}

const RELATED_SKILLS_GRAPH = {
  nodejs: ['javascript', 'express', 'npm', 'mongodb'],
  express: ['nodejs', 'javascript'],
  python: ['django', 'flask', 'pandas', 'sql'],
  django: ['python', 'sql'],
  react: ['javascript', 'nextjs', 'typescript', 'css'],
  nextjs: ['react', 'nodejs'],
  vue: ['javascript', 'nuxt'],
  angular: ['typescript', 'javascript'],
  svelte: ['javascript'],
  sql: ['mysql', 'postgresql', 'mongodb'],
  docker: ['kubernetes', 'aws'],
  kubernetes: ['docker'],
  git: ['github', 'gitlab'],
  flutter: ['dart'],
  'react-native': ['react', 'javascript'],
  aws: ['docker', 'kubernetes'],
  github: ['git'],
  javascript: ['react', 'nodejs', 'typescript'],
  typescript: ['javascript', 'react', 'angular'],
  html: ['css'],
  css: ['tailwind', 'bootstrap'],
};

async function run() {
  const args = parseArgs(process.argv);
  const dryRun = Boolean(args['dry-run']);
  const serviceAccountArg = args['service-account'];
  if (!serviceAccountArg) {
    console.error('Usage: node scripts/curate_related_skills.js --service-account <key.json> [--dry-run]');
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
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  // Expand graph with canonical ids and symmetric relations.
  const graph = {};
  for (const [k, arr] of Object.entries(RELATED_SKILLS_GRAPH)) {
    const key = canonicalSkillId(k);
    if (!key) continue;
    graph[key] = uniqueIds([...(graph[key] || []), ...arr]);
  }
  for (const [k, arr] of Object.entries(graph)) {
    for (const rel of arr) {
      if (!graph[rel]) graph[rel] = [];
      graph[rel] = uniqueIds([...(graph[rel] || []), k]);
    }
  }

  console.log(`Curating Related Skills Graph... (dryRun=${dryRun})\n`);
  const skillsSnap = await db.collection('skills').get();
  const existingIds = new Set(skillsSnap.docs.map((d) => canonicalSkillId(d.id)));

  let updated = 0;
  let skipped = 0;
  for (const doc of skillsSnap.docs) {
    const id = canonicalSkillId(doc.id);
    const desiredRaw = graph[id] || [];
    const desired = desiredRaw.filter((r) => existingIds.has(r) && r !== id);
    if (desired.length === 0) {
      skipped += 1;
      continue;
    }
    const data = doc.data() || {};
    const current = uniqueIds(data.relatedSkills || []);
    const merged = uniqueIds([...current, ...desired]).filter((r) => r !== id);
    if (merged.length === current.length) {
      skipped += 1;
      continue;
    }
    if (!dryRun) {
      await doc.ref.set(
        { relatedSkills: merged, updatedAt: nowTs },
        { merge: true },
      );
    }
    updated += 1;
    console.log(`UPDATE ${id} -> [${merged.join(', ')}]`);
  }

  console.log('\nRelated Skills Curation Complete!');
  console.log(`Updated: ${updated}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Total skills: ${skillsSnap.size}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});

