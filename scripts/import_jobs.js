#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Bulk import / upsert jobs into Firestore with validation.
 *
 * Usage:
 *   node scripts/import_jobs.js --file scripts/data/jobs_import.json --service-account scripts/your-key.json
 *   node scripts/import_jobs.js --file scripts/data/jobs_import.json --service-account scripts/your-key.json --dry-run
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

function normalizeJobIdentity(title, category) {
  return normalizeId(`${String(title || '').trim()}-${String(category || '').trim()}`);
}

function toNumber(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function clamp(num, min, max) {
  return Math.max(min, Math.min(max, num));
}

function isNonEmptyString(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

function validateSkillItem(item, groupName, index) {
  const errors = [];
  if (!item || typeof item !== 'object') {
    return [`${groupName}[${index}] must be an object.`];
  }

  if (!isNonEmptyString(item.name)) {
    errors.push(`${groupName}[${index}].name is required.`);
  }

  const requiredLevel = toNumber(item.requiredLevel, -1);
  if (requiredLevel < 0 || requiredLevel > 100) {
    errors.push(`${groupName}[${index}].requiredLevel must be between 0 and 100.`);
  }

  const weight = toNumber(item.weight, -1);
  if (weight < 1 || weight > 10) {
    errors.push(`${groupName}[${index}].weight must be between 1 and 10.`);
  }

  const allowedPriorities = new Set(['Critical', 'Important', 'Nice-to-have']);
  if (!allowedPriorities.has(String(item.priority || '').trim())) {
    errors.push(
      `${groupName}[${index}].priority must be one of: Critical, Important, Nice-to-have.`,
    );
  }

  return errors;
}

function normalizeSkillItem(item) {
  return {
    name: String(item.name || '').trim(),
    requiredLevel: clamp(Math.round(toNumber(item.requiredLevel, 0)), 0, 100),
    priority: String(item.priority || '').trim() || 'Important',
    weight: clamp(Math.round(toNumber(item.weight, 5)), 1, 10),
  };
}

function buildEducation(input) {
  const src = input && typeof input === 'object' ? input : {};
  return {
    minimumDegree: String(src.minimumDegree || '').trim(),
    preferredFields: Array.isArray(src.preferredFields)
      ? src.preferredFields.map((x) => String(x).trim()).filter(Boolean)
      : [],
  };
}

function buildExperience(input) {
  const src = input && typeof input === 'object' ? input : {};
  const minYears = Math.max(0, Math.round(toNumber(src.minYears, 0)));
  const maxYearsRaw = Math.round(toNumber(src.maxYears, minYears));
  const maxYears = Math.max(minYears, maxYearsRaw);
  return {
    minYears,
    maxYears,
    notes: String(src.notes || '').trim(),
  };
}

function buildSalary(input) {
  const src = input && typeof input === 'object' ? input : {};
  const minimum = Math.max(0, Math.round(toNumber(src.minimum, 0)));
  const maximumRaw = Math.round(toNumber(src.maximum, minimum));
  const maximum = Math.max(minimum, maximumRaw);
  return {
    minimum,
    maximum,
    currency: String(src.currency || 'EGP').trim(),
    period: String(src.period || 'monthly').trim(),
  };
}

function validateJob(job, index, seenJobIds) {
  const errors = [];
  if (!job || typeof job !== 'object') {
    return { errors: [`jobs[${index}] must be an object.`], normalized: null };
  }

  const normalizedTitle = String(job.title || '').trim();
  const normalizedCategory = String(job.category || '').trim();
  const jobId = normalizeJobIdentity(normalizedTitle, normalizedCategory);
  if (!jobId) {
    errors.push(`jobs[${index}] jobId could not be generated from title + category.`);
  }
  if (seenJobIds.has(jobId)) {
    errors.push(
      `jobs[${index}] duplicate role identity (title + category): "${jobId}".`,
    );
  } else {
    seenJobIds.add(jobId);
  }

  if (!isNonEmptyString(job.title)) errors.push(`jobs[${index}].title is required.`);
  if (!isNonEmptyString(job.category))
    errors.push(`jobs[${index}].category is required.`);
  if (!isNonEmptyString(job.description)) errors.push(`jobs[${index}].description is required.`);

  const technicalSkills = Array.isArray(job.technicalSkills) ? job.technicalSkills : [];
  const softSkills = Array.isArray(job.softSkills) ? job.softSkills : [];
  const tools = Array.isArray(job.tools) ? job.tools : [];

  if (technicalSkills.length + softSkills.length + tools.length === 0) {
    errors.push(`jobs[${index}] must have at least one skill in technicalSkills/softSkills/tools.`);
  }

  technicalSkills.forEach((s, i) => errors.push(...validateSkillItem(s, `jobs[${index}].technicalSkills`, i)));
  softSkills.forEach((s, i) => errors.push(...validateSkillItem(s, `jobs[${index}].softSkills`, i)));
  tools.forEach((s, i) => errors.push(...validateSkillItem(s, `jobs[${index}].tools`, i)));

  const normalized = {
    jobId,
    title: normalizedTitle,
    category: normalizedCategory,
    industry: String(job.industry || '').trim(),
    experienceLevel: String(job.experienceLevel || 'Mid-Level').trim(),
    description: String(job.description || '').trim(),
    technicalSkills: technicalSkills.map(normalizeSkillItem),
    softSkills: softSkills.map(normalizeSkillItem),
    tools: tools.map(normalizeSkillItem),
    certifications: Array.isArray(job.certifications)
      ? job.certifications
          .filter((c) => c && typeof c === 'object')
          .map((c) => ({
            name: String(c.name || '').trim(),
            issuer: String(c.issuer || '').trim(),
            required: Boolean(c.required),
          }))
          .filter((c) => c.name)
      : [],
    education: buildEducation(job.education),
    experience: buildExperience(job.experience),
    salary: buildSalary(job.salary),
    isActive: job.isActive !== false,
    source: String(job.source || 'manual-import').trim(),
  };

  const allSkillsCount =
    normalized.technicalSkills.length + normalized.softSkills.length + normalized.tools.length;
  const allSkillLevels = [
    ...normalized.technicalSkills,
    ...normalized.softSkills,
    ...normalized.tools,
  ].map((s) => s.requiredLevel);
  const averageRequiredLevel =
    allSkillLevels.length === 0
      ? 0
      : Number(
          (allSkillLevels.reduce((acc, v) => acc + v, 0) / allSkillLevels.length).toFixed(2),
        );

  normalized.totalSkillsCount = allSkillsCount;
  normalized.averageRequiredLevel = averageRequiredLevel;
  normalized.updatedAt = admin.firestore.FieldValue.serverTimestamp();

  return { errors, normalized };
}

async function run() {
  const args = parseArgs(process.argv);
  const fileArg = args.file;
  const serviceAccountArg = args['service-account'];
  const dryRun = Boolean(args['dry-run']);

  if (!fileArg || !serviceAccountArg) {
    console.error(
      'Usage: node scripts/import_jobs.js --file <jobs.json> --service-account <service-account.json> [--dry-run]',
    );
    process.exit(1);
  }

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

  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (e) {
    console.error(`Invalid JSON: ${e.message}`);
    process.exit(1);
  }

  const jobs = Array.isArray(parsed) ? parsed : parsed.jobs;
  if (!Array.isArray(jobs)) {
    console.error('Input JSON must be an array or object with "jobs" array.');
    process.exit(1);
  }
  if (jobs.length === 0) {
    console.error('No jobs found in input file.');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
  const db = admin.firestore();

  const seenJobIds = new Set();
  const normalizedJobs = [];
  const errors = [];

  jobs.forEach((job, index) => {
    const result = validateJob(job, index, seenJobIds);
    if (result.errors.length > 0) {
      errors.push(...result.errors);
    } else if (result.normalized) {
      normalizedJobs.push(result.normalized);
    }
  });

  if (errors.length > 0) {
    console.error('\nValidation failed:\n');
    errors.forEach((err) => console.error(`- ${err}`));
    console.error(`\nTotal errors: ${errors.length}`);
    process.exit(1);
  }

  console.log(`Validated ${normalizedJobs.length} jobs successfully.`);

  if (dryRun) {
    console.log('\nDry run enabled. No writes were made.');
    console.log(
      `Sample IDs: ${normalizedJobs
        .slice(0, 10)
        .map((j) => j.jobId)
        .join(', ')}`,
    );
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
    if (snap.exists) updated += 1;
    else created += 1;
  }

  console.log('\nImport completed successfully.');
  console.log(`Created: ${created}`);
  console.log(`Updated: ${updated}`);
  console.log(`Total processed: ${normalizedJobs.length}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
