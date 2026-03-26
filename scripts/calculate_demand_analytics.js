#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err && err.stack ? err.stack : err);
  process.exit(1);
});
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err && err.stack ? err.stack : err);
  process.exit(1);
});

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

function getDemandLevel(jobCount) {
  if (jobCount >= 50) return 'Very High';
  if (jobCount >= 20) return 'High';
  if (jobCount >= 5) return 'Medium';
  return 'Low';
}

async function run() {
  const args = parseArgs(process.argv);
  const serviceAccountArg =
    args['service-account'] || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const dryRun = Boolean(args['dry-run']);
  if (!serviceAccountArg) {
    console.error(
      'Usage: node scripts/calculate_demand_analytics.js --service-account <key.json> [--dry-run] (or set GOOGLE_APPLICATION_CREDENTIALS)',
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

  // Validate service-account JSON early with actionable errors.
  let serviceAccountJson;
  try {
    serviceAccountJson = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
  } catch (e) {
    console.error(`Invalid JSON service account file: ${e.message}`);
    process.exit(1);
  }
  const missingKeys = ['project_id', 'client_email', 'private_key'].filter(
    (k) => !serviceAccountJson[k],
  );
  if (missingKeys.length > 0) {
    console.error(
      `Service account missing required keys: ${missingKeys.join(', ')}`,
    );
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountJson),
  });
  const db = admin.firestore();
  const startTime = Date.now();
  const nowTs = admin.firestore.FieldValue.serverTimestamp();

  console.log(`Calculating Market Demand Analytics... (dryRun=${dryRun})\n`);

  // Connectivity/auth sanity check to surface permission issues before main flow.
  try {
    await db.collection('jobs').limit(1).get();
    console.log('Firebase connection test: OK');
  } catch (e) {
    console.error(`Firebase connection test failed: ${e.message}`);
    process.exit(1);
  }

  const jobsSnapshot = await db.collection('jobs').get();
  console.log(`Scanning ${jobsSnapshot.size} jobs...`);

  const skillStats = {}; // skillId -> { count, totalLevel }
  for (let index = 0; index < jobsSnapshot.docs.length; index += 1) {
    if (index > 0 && index % 100 === 0) {
      console.log(`  ${index}/${jobsSnapshot.size} jobs`);
    }
    const jobData = jobsSnapshot.docs[index].data() || {};
    const allSkills = [
      ...(Array.isArray(jobData.technicalSkills) ? jobData.technicalSkills : []),
      ...(Array.isArray(jobData.softSkills) ? jobData.softSkills : []),
      ...(Array.isArray(jobData.tools) ? jobData.tools : []),
    ];

    for (const skillItem of allSkills) {
      let rawSkillId = '';
      let requiredLevel = 50;
      if (skillItem && typeof skillItem === 'object') {
        rawSkillId = skillItem.skillId || skillItem.name || '';
        const level = Number(skillItem.requiredLevel);
        if (Number.isFinite(level)) requiredLevel = level;
      } else {
        rawSkillId = String(skillItem || '');
      }
      const skillId = canonicalSkillId(rawSkillId);
      if (!skillId) continue;
      if (!skillStats[skillId]) {
        skillStats[skillId] = { count: 0, totalLevel: 0 };
      }
      skillStats[skillId].count += 1;
      skillStats[skillId].totalLevel += requiredLevel;
    }
  }

  // include zero-usage updates for existing skills to avoid stale values
  const skillsSnapshot = await db.collection('skills').get();
  for (const doc of skillsSnapshot.docs) {
    const id = canonicalSkillId(doc.id);
    if (!id) continue;
    if (!skillStats[id]) {
      skillStats[id] = { count: 0, totalLevel: 0 };
    }
  }

  const entries = Object.entries(skillStats);
  console.log(`\nUpdating ${entries.length} skills...`);
  let updated = 0;
  let opCount = 0;
  let batch = db.batch();

  for (const [skillId, stats] of entries) {
    const avgLevel = stats.count > 0 ? Math.round(stats.totalLevel / stats.count) : 0;
    const demandLevel = getDemandLevel(stats.count);
    const ref = db.collection('skills').doc(skillId);
    if (!dryRun) {
      batch.set(
        ref,
        {
          totalJobsUsingSkill: stats.count,
          averageRequiredLevel: avgLevel,
          demandLevel,
          marketUpdatedAt: nowTs,
          updatedAt: nowTs,
        },
        { merge: true },
      );
      opCount += 1;
      if (opCount >= 450) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }
    updated += 1;
  }
  if (!dryRun && opCount > 0) {
    await batch.commit();
  }

  const durationSec = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log('\nDemand Analytics Complete!');
  console.log(`${dryRun ? 'Would update' : 'Updated'}: ${updated} skills`);
  console.log(`Duration: ${durationSec}s`);

  const top10 = entries
    .sort(([, a], [, b]) => b.count - a.count)
    .slice(0, 10);
  console.log('\nTop 10 by demand:');
  for (const [skillId, stats] of top10) {
    console.log(`  ${stats.count} jobs -> ${skillId} (${getDemandLevel(stats.count)})`);
  }
}

run().catch((err) => {
  console.error('Error:', err.message);
  process.exit(1);
});

