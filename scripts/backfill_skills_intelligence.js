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

function toDisplayName(skillId) {
  return String(skillId || '')
    .replace(/[_-]+/g, ' ')
    .split(' ')
    .filter(Boolean)
    .map((w) => w[0].toUpperCase() + w.slice(1))
    .join(' ');
}

function uniqueStrings(values) {
  const seen = new Set();
  const out = [];
  for (const v of values || []) {
    const s = String(v || '').trim();
    if (!s) continue;
    const key = s.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(s);
  }
  return out;
}

const DEFAULT_BACKFILL = {
  isVerified: false,
  aliases: [],
  relatedSkills: [],
  domain: 'Technical',
  demandLevel: 'Low',
  category: 'Technical',
  type: 'Technical',
};

const SMART_RULES = [
  {
    re: /^(nodejs|node|express|npm)$/i,
    defaults: { domain: 'Backend', demandLevel: 'High', aliases: ['Node.js'] },
  },
  {
    re: /^(react|nextjs|vue|angular|svelte|typescript|javascript|html|css|tailwind|bootstrap)$/i,
    defaults: { domain: 'Frontend', demandLevel: 'Very High' },
  },
  {
    re: /^(python|django|flask|pandas|java|spring|php|laravel|go|rust|rails|gin|actix)$/i,
    defaults: { domain: 'Backend', demandLevel: 'High' },
  },
  {
    re: /^(sql|mysql|postgres|postgresql|mongodb)$/i,
    defaults: { domain: 'Data', demandLevel: 'High' },
  },
  {
    re: /^(docker|kubernetes|aws|git|github)$/i,
    defaults: { domain: 'DevOps', demandLevel: 'Very High' },
  },
  {
    re: /^(flutter|react-native|react_native|swift|kotlin|ios|android|dart)$/i,
    defaults: { domain: 'Mobile', demandLevel: 'High' },
  },
];

function inferDefaults(skillId) {
  let out = { ...DEFAULT_BACKFILL };
  const compact = String(skillId || '').replace(/-/g, '');
  for (const rule of SMART_RULES) {
    if (rule.re.test(skillId) || rule.re.test(compact)) {
      out = { ...out, ...rule.defaults };
      break;
    }
  }
  return out;
}

async function run() {
  const args = parseArgs(process.argv);
  const dryRun = Boolean(args['dry-run']);
  const serviceAccountArg = args['service-account'];

  if (!serviceAccountArg) {
    console.error('Usage: node scripts/backfill_skills_intelligence.js --service-account <key.json> [--dry-run]');
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

  console.log(`Backfilling ALL skills intelligence... (dryRun=${dryRun})\n`);

  const skills = await db.collection('skills').get();
  let updated = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of skills.docs) {
    const data = doc.data() || {};
    const skillId = canonicalSkillId(doc.id);
    if (!skillId) {
      failed += 1;
      console.log(`FAIL ${doc.id} (invalid id)`);
      continue;
    }

    const backfill = inferDefaults(skillId);
    const existingAliases = Array.isArray(data.aliases) ? data.aliases : [];
    const aliases = uniqueStrings([
      toDisplayName(skillId),
      ...backfill.aliases,
      ...existingAliases,
    ]);
    const related = uniqueStrings(
      (Array.isArray(data.relatedSkills) ? data.relatedSkills : backfill.relatedSkills).map(canonicalSkillId),
    );

    const isVerified =
      typeof data.isVerified === 'boolean' ? data.isVerified : backfill.isVerified;
    const domain = data.domain || backfill.domain;
    const demandLevel = data.demandLevel || backfill.demandLevel;
    const category = data.category || backfill.category;
    const type = data.type || backfill.type;

    const needsUpdate =
      !Array.isArray(data.aliases) ||
      !Array.isArray(data.relatedSkills) ||
      typeof data.isVerified !== 'boolean' ||
      !data.domain ||
      !data.demandLevel ||
      !data.category ||
      !data.type;

    if (!needsUpdate) {
      skipped += 1;
      continue;
    }

    if (!dryRun) {
      await doc.ref.set(
        {
          aliases,
          relatedSkills: related,
          isVerified,
          domain,
          demandLevel,
          category,
          type,
          updatedAt: nowTs,
        },
        { merge: true },
      );
    }
    updated += 1;
    console.log(`UPDATE ${doc.id} -> domain:${domain} demand:${demandLevel} verified:${isVerified}`);
  }

  console.log('\nBackfill Complete!');
  console.log(`Updated: ${updated}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Failed: ${failed}`);
  console.log(`Total skills: ${skills.size}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});

