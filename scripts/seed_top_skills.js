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

const TOP_50_SKILLS = {
  nodejs: { aliases: ['Node.js', 'Nodejs', 'Node JS'], related: ['javascript', 'express', 'npm'], verified: true, demand: 'Very High', domain: 'Backend' },
  python: { aliases: ['Python 3', 'py'], related: ['django', 'flask', 'pandas'], verified: true, demand: 'Very High', domain: 'Backend' },
  java: { aliases: ['Java 8', 'Java 11'], related: ['spring', 'hibernate'], verified: true, demand: 'High', domain: 'Backend' },
  php: { aliases: ['PHP 8'], related: ['laravel', 'symfony'], verified: true, demand: 'Medium', domain: 'Backend' },
  ruby: { aliases: ['Ruby on Rails'], related: ['rails'], verified: true, demand: 'Low', domain: 'Backend' },
  go: { aliases: ['Golang'], related: ['gin'], verified: true, demand: 'High', domain: 'Backend' },
  rust: { aliases: ['Rust lang'], related: ['actix'], verified: true, demand: 'Medium', domain: 'Backend' },
  django: { aliases: [], related: ['python'], verified: true, demand: 'High', domain: 'Backend' },
  spring: { aliases: ['Spring Boot'], related: ['java'], verified: true, demand: 'High', domain: 'Backend' },
  laravel: { aliases: [], related: ['php'], verified: true, demand: 'Medium', domain: 'Backend' },
  express: { aliases: [], related: ['nodejs'], verified: true, demand: 'High', domain: 'Backend' },
  flask: { aliases: [], related: ['python'], verified: true, demand: 'Medium', domain: 'Backend' },
  rails: { aliases: [], related: ['ruby'], verified: true, demand: 'Low', domain: 'Backend' },
  gin: { aliases: [], related: ['go'], verified: true, demand: 'Medium', domain: 'Backend' },
  actix: { aliases: [], related: ['rust'], verified: true, demand: 'Low', domain: 'Backend' },

  react: { aliases: ['React.js', 'ReactJS'], related: ['javascript', 'nextjs', 'typescript'], verified: true, demand: 'Very High', domain: 'Frontend' },
  vue: { aliases: ['Vue.js', 'VueJS'], related: ['javascript'], verified: true, demand: 'High', domain: 'Frontend' },
  angular: { aliases: ['Angular 16'], related: ['typescript'], verified: true, demand: 'Medium', domain: 'Frontend' },
  nextjs: { aliases: ['Next.js'], related: ['react'], verified: true, demand: 'Very High', domain: 'Frontend' },
  nuxt: { aliases: ['Nuxt.js'], related: ['vue'], verified: true, demand: 'Medium', domain: 'Frontend' },
  svelte: { aliases: ['SvelteKit'], related: ['javascript'], verified: true, demand: 'Medium', domain: 'Frontend' },
  javascript: { aliases: ['JS', 'ES6', 'ES2023'], related: ['react', 'nodejs'], verified: true, demand: 'Very High', domain: 'Frontend' },
  typescript: { aliases: ['TS'], related: ['javascript'], verified: true, demand: 'Very High', domain: 'Frontend' },
  html: { aliases: ['HTML5'], related: ['css'], verified: true, demand: 'High', domain: 'Frontend' },
  css: { aliases: ['CSS3'], related: ['html', 'tailwind'], verified: true, demand: 'High', domain: 'Frontend' },
  tailwind: { aliases: ['Tailwind CSS'], related: ['css'], verified: true, demand: 'Very High', domain: 'Frontend' },
  bootstrap: { aliases: ['Bootstrap 5'], related: ['css'], verified: true, demand: 'Medium', domain: 'Frontend' },

  flutter: { aliases: ['Flutter Dart'], related: ['dart'], verified: true, demand: 'High', domain: 'Mobile' },
  'react-native': { aliases: ['React Native'], related: ['react'], verified: true, demand: 'High', domain: 'Mobile' },
  swift: { aliases: ['Swift 5'], related: ['ios'], verified: true, demand: 'Medium', domain: 'Mobile' },
  kotlin: { aliases: ['Kotlin Android'], related: ['android'], verified: true, demand: 'Medium', domain: 'Mobile' },
  dart: { aliases: [], related: ['flutter'], verified: true, demand: 'Medium', domain: 'Mobile' },
  ios: { aliases: ['iOS Development'], related: ['swift'], verified: true, demand: 'Medium', domain: 'Mobile' },

  sql: { aliases: ['MySQL', 'PostgreSQL', 'SQL'], related: ['mongodb'], verified: true, demand: 'Very High', domain: 'Data' },
  mongodb: { aliases: ['Mongo DB'], related: ['sql'], verified: true, demand: 'High', domain: 'Data' },
  docker: { aliases: ['Docker container'], related: ['kubernetes'], verified: true, demand: 'Very High', domain: 'DevOps' },
  kubernetes: { aliases: ['K8s', 'Kube'], related: ['docker'], verified: true, demand: 'High', domain: 'DevOps' },
  aws: { aliases: ['Amazon Web Services'], related: ['docker'], verified: true, demand: 'Very High', domain: 'Cloud' },
  git: { aliases: ['Git version control'], related: ['github'], verified: true, demand: 'Very High', domain: 'Tools' },
  github: { aliases: ['GitHub'], related: ['git'], verified: true, demand: 'Very High', domain: 'Tools' },
  pandas: { aliases: [], related: ['python'], verified: true, demand: 'High', domain: 'Data' },
};

async function run() {
  const args = parseArgs(process.argv);
  const dryRun = Boolean(args['dry-run']);
  const serviceAccountArg = args['service-account'];

  if (!serviceAccountArg) {
    console.error('Usage: node scripts/seed_top_skills.js --service-account <key.json> [--dry-run]');
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

  console.log('Seeding top skills intelligence...');
  let upserts = 0;

  for (const [rawId, meta] of Object.entries(TOP_50_SKILLS)) {
    const skillId = canonicalSkillId(rawId);
    if (!skillId) continue;

    const ref = db.collection('skills').doc(skillId);
    const existing = await ref.get();
    const existingData = existing.data() || {};
    const currentAliases = Array.isArray(existingData.aliases) ? existingData.aliases : [];
    const aliases = uniqueStrings([
      toDisplayName(skillId),
      ...currentAliases,
      ...(meta.aliases || []),
    ]);
    const relatedSkills = uniqueStrings((meta.related || []).map(canonicalSkillId));

    const payload = {
      skillId,
      skillName: existingData.skillName || existingData.name || toDisplayName(skillId),
      name: existingData.name || existingData.skillName || toDisplayName(skillId),
      aliases,
      relatedSkills,
      isVerified: Boolean(meta.verified),
      category: existingData.category || 'Technical',
      type: existingData.type || 'Technical',
      domain: meta.domain || existingData.domain || 'General',
      demandLevel: meta.demand || existingData.demandLevel || 'Medium',
      totalJobsUsingSkill: Number(existingData.totalJobsUsingSkill || 0),
      averageRequiredLevel: Number(existingData.averageRequiredLevel || 0),
      updatedAt: nowTs,
    };

    if (!existing.exists) {
      payload.createdAt = nowTs;
    } else if (existingData.createdAt) {
      payload.createdAt = existingData.createdAt;
    } else {
      payload.createdAt = nowTs;
    }

    if (!dryRun) {
      await ref.set(payload, { merge: true });
    }
    upserts += 1;
    console.log(`${existing.exists ? 'UPDATE' : 'CREATE'} ${skillId}`);
  }

  console.log(`Done. ${dryRun ? 'Dry-run upserts' : 'Upserts'}: ${upserts}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});

