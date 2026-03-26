# Jobs Bulk Import Guide

This importer validates and upserts many jobs into Firestore in one run.

## What it does

- Validates required fields for each job.
- Validates each skill item (`name`, `requiredLevel`, `priority`, `weight`).
- Normalizes `jobId` to slug format.
- Upserts into `jobs/{jobId}` (create if missing, update if existing).
- Calculates and stores:
  - `totalSkillsCount`
  - `averageRequiredLevel`
  - `updatedAt`

## Input file

Default input is:

- `scripts/data/jobs_import.json`

Format:

```json
{
  "jobs": [
    {
      "jobId": "frontend-developer-001",
      "title": "Frontend Developer",
      "category": "Engineering",
      "description": "Build responsive UI",
      "technicalSkills": [
        { "name": "React", "requiredLevel": 80, "priority": "Critical", "weight": 9 }
      ],
      "softSkills": [
        { "name": "Communication", "requiredLevel": 75, "priority": "Important", "weight": 6 }
      ],
      "tools": [
        { "name": "Git", "requiredLevel": 70, "priority": "Important", "weight": 6 }
      ],
      "education": { "minimumDegree": "Bachelor" },
      "experience": { "minYears": 0, "maxYears": 2 },
      "salary": { "minimum": 10000, "maximum": 18000, "currency": "EGP", "period": "monthly" },
      "isActive": true
    }
  ]
}
```

## Run commands

From project root:

```bash
npm run import:jobs:dry
```

Then apply writes:

```bash
npm run import:jobs
```

## Custom file/key

```bash
node scripts/import_jobs.js --file path/to/jobs.json --service-account path/to/key.json --dry-run
node scripts/import_jobs.js --file path/to/jobs.json --service-account path/to/key.json
```

## Validation rules

- Job must include: `title`, `category`, `description`.
- At least one skill in: `technicalSkills` or `softSkills` or `tools`.
- Skill rules:
  - `requiredLevel` is `0..100`
  - `weight` is `1..10`
  - `priority` is one of:
    - `Critical`
    - `Important`
    - `Nice-to-have`
- No duplicate `jobId` in same input file.

## Recommended workflow

- Keep one JSON file per domain (`engineering_jobs.json`, `business_jobs.json`, etc.).
- Run `--dry-run` first.
- Import to Firestore only after validation passes.
- Commit JSON source files so your job catalog is versioned.
