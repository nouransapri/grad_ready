#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Dedupe jobs by normalized (title + category).
 *
 * Usage:
 *   node scripts/dedupe_jobs.js --service-account scripts/firebase-sa.json --dry-run
 *   node scripts/dedupe_jobs.js --service-account scripts/firebase-sa.json
 */

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

function normalizeId(input) {
  return String(input || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function jobIdentity(title, category) {
  return normalizeId(`${String(title || '').trim()}-${String(category || '').trim()}`);
}

function normalizeSkillId(input) {
  return normalizeId(input);
}

function toNum(v, fallback = 0) {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function normalizeSkillList(rawList) {
  const out = [];
  const seen = new Set();
  const arr = Array.isArray(rawList) ? rawList : [];
  for (const item of arr) {
    if (!item || typeof item !== 'object') continue;
    const name = String(item.name || '').trim();
    if (!name) continue;
    const skillId = normalizeSkillId(item.skillId || name);
    const key = skillId || normalizeSkillId(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push({
      skillId,
      name,
      requiredLevel: Math.max(0, Math.min(100, Math.round(toNum(item.requiredLevel, 70)))),
      priority: String(item.priority || 'Important').trim() || 'Important',
      weight: Math.max(1, Math.min(10, Math.round(toNum(item.weight, 5)))),
      category: String(item.category || '').trim(),
    });
  }
  return out;
}

function skillCount(docData) {
  if (typeof docData.totalSkillsCount === 'number' && Number.isFinite(docData.totalSkillsCount)) {
    return docData.totalSkillsCount;
  }
  const tech = Array.isArray(docData.technicalSkills) ? docData.technicalSkills.length : 0;
  const soft = Array.isArray(docData.softSkills) ? docData.softSkills.length : 0;
  const tools = Array.isArray(docData.tools) ? docData.tools.length : 0;
  return tech + soft + tools;
}

async function run() {
  const args = parseArgs(process.argv);
  const saArg = args['service-account'];
  const dryRun = Boolean(args['dry-run']);

  if (!saArg) {
    console.error(
      'Usage: node scripts/dedupe_jobs.js --service-account <service-account.json> [--dry-run]',
    );
    process.exit(1);
  }

  const serviceAccountPath = path.isAbsolute(saArg)
    ? saArg
    : path.resolve(process.cwd(), saArg);

  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`Service account file not found: ${serviceAccountPath}`);
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
  const db = admin.firestore();

  const snapshot = await db.collection('jobs').get();
  if (snapshot.empty) {
    console.log('No jobs found.');
    return;
  }

  const groups = new Map();
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const title = String(data.title || '').trim();
    const category = String(data.category || '').trim();
    const key = jobIdentity(title, category);
    if (!key) continue;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push({ docId: doc.id, data });
  }

  let duplicateGroups = 0;
  let docsToDelete = 0;
  let docsToUpdate = 0;

  for (const [key, docs] of groups.entries()) {
    if (docs.length <= 1) continue;
    duplicateGroups += 1;
    docs.sort((a, b) => skillCount(b.data) - skillCount(a.data));
    const keeper = docs[0];
    const duplicates = docs.slice(1);

    const mergedTech = normalizeSkillList([
      ...(Array.isArray(keeper.data.technicalSkills) ? keeper.data.technicalSkills : []),
      ...duplicates.flatMap((d) => (Array.isArray(d.data.technicalSkills) ? d.data.technicalSkills : [])),
    ]);
    const mergedSoft = normalizeSkillList([
      ...(Array.isArray(keeper.data.softSkills) ? keeper.data.softSkills : []),
      ...duplicates.flatMap((d) => (Array.isArray(d.data.softSkills) ? d.data.softSkills : [])),
    ]);
    const mergedTools = normalizeSkillList([
      ...(Array.isArray(keeper.data.tools) ? keeper.data.tools : []),
      ...duplicates.flatMap((d) => (Array.isArray(d.data.tools) ? d.data.tools : [])),
    ]);

    const totalSkillsCount = mergedTech.length + mergedSoft.length + mergedTools.length;
    const allLevels = [...mergedTech, ...mergedSoft, ...mergedTools].map((s) => s.requiredLevel);
    const averageRequiredLevel =
      allLevels.length === 0
        ? 0
        : Number((allLevels.reduce((a, v) => a + v, 0) / allLevels.length).toFixed(2));

    docsToUpdate += 1;
    docsToDelete += duplicates.length;

    console.log(
      `Group "${key}": keep=${keeper.docId}, remove=[${duplicates.map((d) => d.docId).join(', ')}]`,
    );

    if (!dryRun) {
      await db.collection('jobs').doc(keeper.docId).set(
        {
          jobId: key,
          technicalSkills: mergedTech,
          softSkills: mergedSoft,
          tools: mergedTools,
          totalSkillsCount,
          averageRequiredLevel,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      const batch = db.batch();
      for (const d of duplicates) {
        batch.delete(db.collection('jobs').doc(d.docId));
      }
      await batch.commit();
    }
  }

  console.log('\nDedupe summary:');
  console.log(`Duplicate groups: ${duplicateGroups}`);
  console.log(`Docs to update: ${docsToUpdate}`);
  console.log(`Docs to delete: ${docsToDelete}`);
  console.log(`Mode: ${dryRun ? 'DRY-RUN' : 'APPLIED'}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
