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

function toSkillId(name) {
  return String(name || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function cleanName(name) {
  return String(name || '').replace(/\s+/g, ' ').trim();
}

function courseTemplatesForSkill(skillName) {
  const q = encodeURIComponent(skillName);
  const base = [
    {
      title: `${skillName} Courses - Coursera`,
      platform: 'Coursera',
      url: `https://www.coursera.org/search?query=${q}`,
      duration: 'Self-paced',
      cost: 'Paid/Free options',
      rating: 4.7,
      level: 'Beginner to Advanced',
      description: `Real courses for ${skillName} on Coursera.`,
    },
    {
      title: `${skillName} Courses - Udemy`,
      platform: 'Udemy',
      url: `https://www.udemy.com/courses/search/?q=${q}`,
      duration: 'Self-paced',
      cost: 'Paid',
      rating: 4.6,
      level: 'Beginner to Advanced',
      description: `Hands-on ${skillName} training on Udemy.`,
    },
    {
      title: `${skillName} Learning Path - freeCodeCamp`,
      platform: 'freeCodeCamp',
      url: `https://www.freecodecamp.org/news/search/?query=${q}`,
      duration: 'Self-paced',
      cost: 'Free',
      rating: 4.8,
      level: 'Beginner to Intermediate',
      description: `Free practical resources for ${skillName}.`,
    },
  ];
  return base;
}

async function run() {
  const args = parseArgs(process.argv);
  const dryRun = Boolean(args['dry-run']);
  const serviceAccountArg = args['service-account'];
  if (!serviceAccountArg) {
    console.error('Usage: node scripts/sync_skills_courses.js --service-account <key.json> [--dry-run]');
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

  const jobsSnap = await db.collection('jobs').get();
  if (jobsSnap.empty) {
    console.error('No jobs found in Firestore. Import jobs first.');
    process.exit(1);
  }

  const skillsMap = new Map();
  for (const doc of jobsSnap.docs) {
    const data = doc.data() || {};
    const groups = [
      { key: 'technicalSkills', type: 'Technical' },
      { key: 'softSkills', type: 'Soft' },
      { key: 'tools', type: 'Tool' },
    ];
    for (const group of groups) {
      const list = Array.isArray(data[group.key]) ? data[group.key] : [];
      for (const item of list) {
        const name = cleanName(item && item.name);
        if (!name) continue;
        const id = toSkillId(name);
        if (!id) continue;
        const requiredLevel = Number(item.requiredLevel || 0);
        const record = skillsMap.get(id) || {
          skillId: id,
          skillName: name,
          name,
          type: group.type,
          category: group.type === 'Tool' ? 'Tools' : group.type,
          subCategory: '',
          description: `${name} is required across active job roles in GradReady.`,
          aliases: [],
          prerequisites: [],
          relatedSkills: [],
          advancedSkills: [],
          demandLevel: 'Medium',
          trending: false,
          growthRate: 'Stable',
          averageSalaryImpact: 'Medium',
          usedInJobs: [],
          courses: [],
          certifications: [],
          learningResources: [],
          practiceProjects: [],
          totalJobsUsingSkill: 0,
          averageRequiredLevel: 0,
          mostCommonPriority: 'Important',
          isActive: true,
        };

        record.usedInJobs.push({
          jobId: String(data.jobId || doc.id),
          jobTitle: String(data.title || ''),
          category: String(data.category || ''),
          requiredLevel: Math.max(0, Math.min(100, requiredLevel)),
          priority: String(item.priority || 'Important'),
          weight: Number(item.weight || 5),
        });

        skillsMap.set(id, record);
      }
    }
  }

  const nowTs = admin.firestore.FieldValue.serverTimestamp();
  const skills = [...skillsMap.values()].map((s) => {
    const levels = s.usedInJobs.map((u) => Number(u.requiredLevel || 0));
    const avg = levels.length
      ? Number((levels.reduce((a, b) => a + b, 0) / levels.length).toFixed(2))
      : 0;
    const jobsCount = s.usedInJobs.length;
    let demandLevel = 'Medium';
    if (jobsCount >= 8) demandLevel = 'Very High';
    else if (jobsCount >= 5) demandLevel = 'High';
    else if (jobsCount <= 2) demandLevel = 'Low';

    return {
      ...s,
      totalJobsUsingSkill: jobsCount,
      averageRequiredLevel: avg,
      demandLevel,
      trending: jobsCount >= 5,
      createdAt: nowTs,
      updatedAt: nowTs,
    };
  });

  const courses = [];
  for (const s of skills) {
    const templates = courseTemplatesForSkill(s.skillName);
    for (const t of templates) {
      courses.push({
        skillName: s.skillName,
        title: t.title,
        platform: t.platform,
        url: t.url,
        duration: t.duration,
        cost: t.cost,
        rating: t.rating,
        level: t.level,
        description: t.description,
      });
    }
  }

  if (dryRun) {
    console.log(`Dry run only. Skills to upsert: ${skills.length}`);
    console.log(`Dry run only. Courses to add: ${courses.length}`);
    process.exit(0);
  }

  let skillsUpserted = 0;
  for (const s of skills) {
    const ref = db.collection('skills').doc(s.skillId);
    const existing = await ref.get();
    await ref.set(
      {
        ...s,
        createdAt: existing.exists ? existing.get('createdAt') || nowTs : nowTs,
        updatedAt: nowTs,
      },
      { merge: true },
    );
    skillsUpserted += 1;
  }

  const oldCourses = await db.collection('courses').get();
  const batchSize = 450;
  let batch = db.batch();
  let opCount = 0;
  for (const doc of oldCourses.docs) {
    batch.delete(doc.ref);
    opCount += 1;
    if (opCount >= batchSize) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }
  if (opCount > 0) await batch.commit();

  let coursesInserted = 0;
  batch = db.batch();
  opCount = 0;
  for (const c of courses) {
    const ref = db.collection('courses').doc();
    batch.set(ref, {
      ...c,
      createdAt: nowTs,
      updatedAt: nowTs,
    });
    coursesInserted += 1;
    opCount += 1;
    if (opCount >= batchSize) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }
  if (opCount > 0) await batch.commit();

  console.log(`Skills upserted: ${skillsUpserted}`);
  console.log(`Courses inserted: ${coursesInserted}`);
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
