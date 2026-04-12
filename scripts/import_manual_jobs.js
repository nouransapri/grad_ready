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

function normalizeId(input) {
  return String(input || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function canonicalJobId(title, category) {
  return normalizeId(`${title}-${category}`);
}

function inferCategory(title) {
  const t = String(title || '').toLowerCase();
  if (t.includes('data scientist') || t.includes('data analyst')) return 'Data';
  if (t.includes('machine learning') || t.startsWith('ai ')) return 'AI';
  if (t.includes('mobile')) return 'Mobile';
  if (t.includes('ui/ux') || t.includes('designer') || t.includes('video editor')) return 'Design';
  if (t.includes('cybersecurity')) return 'Security';
  if (t.includes('devops') || t.includes('software engineer') || t.includes('qa')) {
    return 'Engineering';
  }
  if (t.includes('cloud')) return 'Cloud';
  if (t.includes('marketing') || t.includes('seo') || t.includes('social media') || t.includes('copywriter') || t.includes('content creator')) {
    return 'Marketing';
  }
  if (t.includes('product manager') || t.includes('project manager') || t.includes('business analyst')) {
    return 'Business';
  }
  if (t.includes('sales')) return 'Sales';
  if (t.includes('customer support')) return 'Support';
  if (t.includes('hr specialist')) return 'HR';
  if (t.includes('e-commerce')) return 'E-Commerce';
  return 'General';
}

function mapSkillList(names, category) {
  const arr = Array.isArray(names) ? names : [];
  return arr
    .map((name, idx) => ({
      skillId: normalizeId(name),
      name: String(name || '').trim(),
      requiredLevel: [80, 75, 70, 65, 60][idx] || 60,
      priority: idx === 0 ? 'Critical' : idx <= 2 ? 'Important' : 'Nice-to-have',
      weight: [10, 9, 8, 7, 6][idx] || 6,
      category,
    }))
    .filter((s) => s.name && s.skillId);
}

async function run() {
  const args = parseArgs(process.argv);
  const fileArg = args.file || 'scripts/data/manual_jobs_input.json';
  const serviceAccountArg = args['service-account'] || 'scripts/firebase-sa.json';
  const dryRun = Boolean(args['dry-run']);

  const filePath = path.isAbsolute(fileArg) ? fileArg : path.resolve(process.cwd(), fileArg);
  const serviceAccountPath = path.isAbsolute(serviceAccountArg)
    ? serviceAccountArg
    : path.resolve(process.cwd(), serviceAccountArg);

  if (!fs.existsSync(filePath)) {
    console.error(`Input file not found: ${filePath}`);
    process.exit(1);
  }
  if (!fs.existsSync(serviceAccountPath)) {
    console.error(`Service account file not found: ${serviceAccountPath}`);
    process.exit(1);
  }

  const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const jobs = Array.isArray(parsed.jobs) ? parsed.jobs : [];
  if (jobs.length === 0) {
    console.error('No jobs found in input file.');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
  const db = admin.firestore();

  const normalizedJobs = jobs.map((job) => {
    const title = String(job.title || '').trim();
    const category = inferCategory(title);
    const technicalSkills = mapSkillList(job.technical, 'Technical');
    const softSkills = mapSkillList(job.soft, 'Soft');
    const tools = mapSkillList(job.tools, 'Tool');
    const all = [...technicalSkills, ...softSkills, ...tools];
    const averageRequiredLevel = all.length
      ? Number((all.reduce((sum, s) => sum + s.requiredLevel, 0) / all.length).toFixed(2))
      : 0;

    return {
      jobId: canonicalJobId(title, category),
      title,
      category,
      industry: category,
      experienceLevel: 'Mid-Level',
      description: `${title} role with required technical, soft, and tool skills.`,
      technicalSkills,
      softSkills,
      tools,
      certifications: [],
      education: { minimumDegree: '', preferredFields: [] },
      experience: { minYears: 0, maxYears: 3, notes: '' },
      salary: { minimum: 0, maximum: 0, currency: 'EGP', period: 'monthly' },
      isActive: true,
      source: 'manual-admin-list',
      totalSkillsCount: all.length,
      averageRequiredLevel,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  });

  if (dryRun) {
    console.log(`Dry run: ${normalizedJobs.length} jobs prepared.`);
    console.log(`Sample ids: ${normalizedJobs.slice(0, 8).map((j) => j.jobId).join(', ')}`);
    process.exit(0);
  }

  let created = 0;
  let updated = 0;
  for (const job of normalizedJobs) {
    const ref = db.collection('jobs').doc(job.jobId);
    const snap = await ref.get();
    await ref.set(
      {
        ...job,
        createdAt: snap.exists
          ? snap.get('createdAt') || admin.firestore.FieldValue.serverTimestamp()
          : admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    if (snap.exists) {
      updated += 1;
    } else {
      created += 1;
    }
  }

  console.log(`Imported jobs: ${normalizedJobs.length}`);
  console.log(`Created: ${created}`);
  console.log(`Updated: ${updated}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
