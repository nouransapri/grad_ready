#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Backfill legacy jobs skill items with skillId references.
 *
 * What it does:
 * - Scans jobs in pages (ordered by document id).
 * - For each technicalSkills / softSkills / tools item:
 *   - If skillId is missing/empty, resolve by normalized name from skills collection.
 *   - If no central skill exists, create one and use its id.
 * - Updates jobs in-place only when changes are needed.
 *
 * Usage:
 *   node scripts/migrate_job_skill_ids.js --service-account scripts/your-key.json --dry-run
 *   node scripts/migrate_job_skill_ids.js --service-account scripts/your-key.json
 *
 * Optional:
 *   --page-size 200      // jobs page size (default: 200)
 *   --batch-size 400     // max writes per batch commit (default: 400)
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

function toInt(value, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return Math.trunc(n);
}

function normalizeName(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function toSkillId(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function cleanName(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function inferCategory(groupKey) {
  if (groupKey === 'softSkills') return 'Soft';
  if (groupKey === 'tools') return 'Tool';
  return 'Technical';
}

async function preloadSkills(db) {
  const byId = new Map();
  const byNormalizedName = new Map();
  const snap = await db.collection('skills').get();
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const skillId = String(data.skillId || doc.id || '').trim();
    const name = cleanName(data.skillName || data.name || '');
    if (!skillId) continue;
    byId.set(skillId, {
      id: skillId,
      name,
      category: String(data.category || data.type || 'Technical'),
    });
    const norm = normalizeName(name);
    if (norm && !byNormalizedName.has(norm)) {
      byNormalizedName.set(norm, skillId);
    }
  }
  return { byId, byNormalizedName };
}

async function run() {
  const args = parseArgs(process.argv);
  const dryRun = Boolean(args['dry-run']);
  const serviceAccountArg = args['service-account'];
  const pageSize = Math.max(1, Math.min(500, toInt(args['page-size'], 200)));
  const batchSize = Math.max(1, Math.min(450, toInt(args['batch-size'], 400)));

  if (!serviceAccountArg) {
    console.error(
      'Usage: node scripts/migrate_job_skill_ids.js --service-account <key.json> [--dry-run] [--page-size 200] [--batch-size 400]',
    );
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

  const skillsCache = await preloadSkills(db);
  const pendingSkillsToCreate = new Map(); // skillId -> payload

  let scannedJobs = 0;
  let updatedJobs = 0;
  let migratedSkillItems = 0;
  let createdSkills = 0;

  let batch = db.batch();
  let pendingWrites = 0;
  const commitBatch = async () => {
    if (pendingWrites === 0 || dryRun) return;
    await batch.commit();
    batch = db.batch();
    pendingWrites = 0;
  };

  const queueWrite = (fn) => {
    if (dryRun) return;
    fn(batch);
    pendingWrites += 1;
  };

  async function resolveSkillId(skillName, groupKey) {
    const cleaned = cleanName(skillName);
    const normalized = normalizeName(cleaned);
    if (!normalized) return '';

    const existingByName = skillsCache.byNormalizedName.get(normalized);
    if (existingByName) return existingByName;

    const candidateId = toSkillId(cleaned);
    if (!candidateId) return '';

    if (skillsCache.byId.has(candidateId)) {
      skillsCache.byNormalizedName.set(normalized, candidateId);
      return candidateId;
    }

    if (!pendingSkillsToCreate.has(candidateId)) {
      const category = inferCategory(groupKey);
      pendingSkillsToCreate.set(candidateId, {
        skillId: candidateId,
        skillName: cleaned,
        name: cleaned,
        aliases: [cleaned],
        category,
        type: category,
        domain: category,
        isVerified: false,
        relatedSkills: [],
        demandLevel: 'Medium',
        totalJobsUsingSkill: 0,
        averageRequiredLevel: 0,
        isActive: true,
        createdAt: nowTs,
        updatedAt: nowTs,
      });
      createdSkills += 1;
    }

    skillsCache.byId.set(candidateId, {
      id: candidateId,
      name: cleaned,
      category: inferCategory(groupKey),
    });
    skillsCache.byNormalizedName.set(normalized, candidateId);
    return candidateId;
  }

  let lastDoc = null;
  while (true) {
    let query = db.collection('jobs').orderBy(admin.firestore.FieldPath.documentId()).limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);
    const page = await query.get();
    if (page.empty) break;

    for (const doc of page.docs) {
      scannedJobs += 1;
      const data = doc.data() || {};
      const groups = ['technicalSkills', 'softSkills', 'tools'];
      let changed = false;

      const updatedData = { ...data };
      for (const groupKey of groups) {
        const list = Array.isArray(data[groupKey]) ? data[groupKey] : [];
        const normalizedList = [];

        for (const item of list) {
          if (!item || typeof item !== 'object') {
            normalizedList.push(item);
            continue;
          }
          const obj = { ...item };
          const name = cleanName(obj.name);
          const existingId = toSkillId(obj.skillId);

          let resolvedId = existingId;
          if (!resolvedId) {
            resolvedId = await resolveSkillId(name, groupKey);
            if (resolvedId) {
              obj.skillId = resolvedId;
              changed = true;
              migratedSkillItems += 1;
            }
          }

          normalizedList.push(obj);
        }

        updatedData[groupKey] = normalizedList;
      }

      if (changed) {
        updatedJobs += 1;
        queueWrite((b) =>
          b.set(
            doc.ref,
            {
              technicalSkills: updatedData.technicalSkills,
              softSkills: updatedData.softSkills,
              tools: updatedData.tools,
              updatedAt: nowTs,
            },
            { merge: true },
          ),
        );
      }

      if (pendingWrites >= batchSize) {
        await commitBatch();
      }
    }

    lastDoc = page.docs[page.docs.length - 1];
  }

  for (const [skillId, payload] of pendingSkillsToCreate.entries()) {
    const ref = db.collection('skills').doc(skillId);
    queueWrite((b) => b.set(ref, payload, { merge: true }));
    if (pendingWrites >= batchSize) {
      await commitBatch();
    }
  }

  await commitBatch();

  console.log('Migration completed.');
  console.log(`Dry run: ${dryRun ? 'YES' : 'NO'}`);
  console.log(`Jobs scanned: ${scannedJobs}`);
  console.log(`Jobs updated: ${updatedJobs}`);
  console.log(`Skill items migrated: ${migratedSkillItems}`);
  console.log(`New skills created: ${createdSkills}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});

