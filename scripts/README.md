# GradReady Skill Match Report

Generates **user_id, job_id, match_percentage** (and optional **recommend** for match ≥ 70%) for use in the Flutter app or Power BI.

## Formula

- **match_percentage** = (number of matching skills / total required skills for the job) × 100  
- Matching uses normalized skill names (lowercase, trim).  
- **recommend** = `true` when match ≥ 70% (configurable in Python with `--threshold`).

## Run with CSV (no Firestore)

From project root:

```bash
# Node (no install)
node scripts/skill_match_report.mjs --users scripts/data/users.csv --jobs scripts/data/jobs.csv --output scripts/out/skill_match_results.csv
```

Or with Python (stdlib only for CSV):

```bash
python scripts/skill_match_report.py --users scripts/data/users.csv --jobs scripts/data/jobs.csv --output scripts/out/skill_match_results.csv
```

## Run with Firestore (Python only)

1. Install: `pip install -r scripts/requirements.txt`
2. Set `GOOGLE_APPLICATION_CREDENTIALS` to your Firebase service account JSON path.
3. Run: `python scripts/skill_match_report.py --firestore --output scripts/out/skill_match_results.csv`

## Input CSV format

- **users.csv**: `user_id`, `skills` (comma- or pipe-separated).  
- **jobs.csv**: `job_id`, `required_skills` (comma- or pipe-separated).

## Output

- **skill_match_results.csv**: `user_id`, `job_id`, `match_percentage`, `recommend`  
- Table printed to console; recommendations (match ≥ 70%) listed at the end.

## Use in Flutter

- Copy `scripts/out/skill_match_results.csv` into `assets/data/` (and add to `pubspec.yaml` under `assets`), or load from a URL.
- Parse CSV (e.g. `csv` package or split by line/coma) and filter by `user_id` or `recommend == true` for recommendations.

## Use in Power BI

- Get Data → Text/CSV → select `skill_match_results.csv`.
- Use `user_id`, `job_id`, `match_percentage` for visuals; filter or highlight rows where `recommend = true` for recommendations.

---

## Bulk import jobs to Firestore

You can import many jobs with full skills/requirements using:

- Script: `scripts/import_jobs.js`
- Guide: `scripts/JOBS_IMPORT_GUIDE.md`
- Sample input: `scripts/data/jobs_import.json`

Quick run from project root:

```bash
npm run import:jobs:dry
npm run import:jobs
```
