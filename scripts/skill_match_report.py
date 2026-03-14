#!/usr/bin/env python3
"""
GradReady Skill Match Report
----------------------------
Loads users and jobs (from Firestore or CSV), computes per-user per-job skill match %:
  match_percentage = (number of matching skills / total required skills for job) * 100
Outputs: table + CSV (user_id, job_id, match_percentage).
Optionally highlights users with match >= 70% for recommendations.

Usage:
  CSV:   python skill_match_report.py --users data/users.csv --jobs data/jobs.csv
  Firestore: set GOOGLE_APPLICATION_CREDENTIALS and run: python skill_match_report.py --firestore
"""

import argparse
import csv
import os
import sys
from pathlib import Path

# Optional Firestore
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    HAS_FIRESTORE = True
except ImportError:
    HAS_FIRESTORE = False


def normalize_skill(s: str) -> str:
    """Normalize for matching: lowercase, strip, single spaces (align with Flutter app)."""
    if not s or not isinstance(s, str):
        return ""
    return " ".join(s.strip().lower().split())


def parse_skills_cell(cell: str) -> list[str]:
    """Parse a CSV cell that may contain comma- or pipe-separated skills."""
    if not cell or not str(cell).strip():
        return []
    s = str(cell).strip()
    # Allow comma or pipe as separator
    if "|" in s:
        parts = [p.strip() for p in s.split("|") if p.strip()]
    else:
        parts = [p.strip() for p in s.split(",") if p.strip()]
    return [p for p in parts if p]


def load_users_from_csv(users_path: str) -> list[dict]:
    """Load users from CSV. Expected columns: user_id, skills (skills = comma/pipe-separated)."""
    users = []
    path = Path(users_path)
    if not path.exists():
        print(f"Warning: {users_path} not found.", file=sys.stderr)
        return users
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if "user_id" not in reader.fieldnames and "id" in reader.fieldnames:
            id_key = "id"
        else:
            id_key = "user_id"
        skills_key = "skills"
        for row in reader:
            uid = row.get(id_key, row.get("id", "")).strip()
            if not uid:
                continue
            raw = row.get(skills_key, row.get("skill_list", ""))
            skills = parse_skills_cell(raw)
            users.append({"id": uid, "skills": skills})
    return users


def load_jobs_from_csv(jobs_path: str) -> list[dict]:
    """Load jobs from CSV. Expected columns: job_id, required_skills (comma/pipe-separated)."""
    jobs = []
    path = Path(jobs_path)
    if not path.exists():
        print(f"Warning: {jobs_path} not found.", file=sys.stderr)
        return jobs
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        id_key = "job_id" if "job_id" in (reader.fieldnames or []) else "id"
        req_key = "required_skills" if "required_skills" in (reader.fieldnames or []) else "skills"
        for row in reader:
            jid = row.get(id_key, row.get("id", "")).strip()
            if not jid:
                continue
            raw = row.get(req_key, row.get("required_skills", ""))
            required = parse_skills_cell(raw)
            jobs.append({"id": jid, "required_skills": required})
    return jobs


def load_from_firestore() -> tuple[list[dict], list[dict]]:
    """Load users and jobs from Firestore. Requires GOOGLE_APPLICATION_CREDENTIALS."""
    if not HAS_FIRESTORE:
        raise RuntimeError("Install firebase-admin: pip install firebase-admin")
    if not firebase_admin._apps:
        cred = credentials.ApplicationDefault()
        try:
            firebase_admin.initialize_app(cred)
        except Exception:
            key_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
            if key_path and os.path.isfile(key_path):
                firebase_admin.initialize_app(credentials.Certificate(key_path))
            else:
                raise RuntimeError("Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON path")
    db = firestore.client()

    users = []
    for doc in db.collection("users").stream():
        data = doc.to_dict()
        raw = data.get("skills") or []
        skills = []
        for s in raw:
            if isinstance(s, str) and s.strip():
                skills.append(s.strip())
            elif isinstance(s, dict) and s.get("name"):
                skills.append(str(s["name"]).strip())
        users.append({"id": doc.id, "skills": skills})

    jobs = []
    for doc in db.collection("jobs").stream():
        data = doc.to_dict()
        required = list(data.get("requiredSkills") or data.get("required_skills") or [])
        # Also collect from technical/soft with level if required_skills empty
        if not required:
            for item in (data.get("technicalSkillsWithLevel") or data.get("technical_skills") or []):
                if isinstance(item, dict) and item.get("name"):
                    required.append(item["name"])
            for item in (data.get("softSkillsWithLevel") or data.get("soft_skills") or []):
                if isinstance(item, dict) and item.get("name"):
                    required.append(item["name"])
        jobs.append({"id": doc.id, "required_skills": required})

    return users, jobs


def match_percentage(user_skills: list[str], job_required: list[str]) -> float:
    """
    match_percentage = (number of matching skills / total required skills) * 100.
    Matching is normalized (lowercase, trim). Missing skills count as 0.
    """
    if not job_required:
        return 100.0
    user_set = {normalize_skill(s) for s in user_skills if normalize_skill(s)}
    required_norm = [normalize_skill(r) for r in job_required if normalize_skill(r)]
    if not required_norm:
        return 100.0
    matched = sum(1 for r in required_norm if r in user_set)
    return round((matched / len(required_norm)) * 100.0, 2)


def run_report(users: list[dict], jobs: list[dict], highlight_threshold: float = 70.0) -> list[dict]:
    """Compute rows: user_id, job_id, match_percentage; optional recommend (match >= threshold)."""
    rows = []
    for u in users:
        for j in jobs:
            pct = match_percentage(u["skills"], j["required_skills"])
            rows.append({
                "user_id": u["id"],
                "job_id": j["id"],
                "match_percentage": pct,
                "recommend": pct >= highlight_threshold,
            })
    return rows


def main():
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="GradReady skill match report (CSV or Firestore)")
    parser.add_argument("--users", default="", help="Path to users CSV (user_id, skills)")
    parser.add_argument("--jobs", default="", help="Path to jobs CSV (job_id, required_skills)")
    parser.add_argument("--firestore", action="store_true", help="Force load from Firestore (skip auto-detect)")
    parser.add_argument("--output", default="", help="Output CSV path (default: scripts/out/skill_match_results.csv)")
    parser.add_argument("--threshold", type=float, default=70.0, help="Recommend when match >= this (default 70)")
    parser.add_argument("--no-highlight", action="store_true", help="Do not add recommend column")
    args = parser.parse_args()

    # Default output: scripts/out/skill_match_results.csv
    if not args.output:
        args.output = str(script_dir / "out" / "skill_match_results.csv")

    # Use Firestore if GOOGLE_APPLICATION_CREDENTIALS is set (and no CSV paths given), else CSV
    use_firestore = args.firestore or (
        os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
        and HAS_FIRESTORE
        and not args.users
        and not args.jobs
    )
    if use_firestore:
        try:
            users, jobs = load_from_firestore()
            print("Loaded users and jobs from Firestore.", file=sys.stderr)
        except Exception as e:
            print(f"Firestore error: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        if not args.users or not args.jobs:
            args.users = args.users or str(script_dir / "data" / "users.csv")
            args.jobs = args.jobs or str(script_dir / "data" / "jobs.csv")
        users = load_users_from_csv(args.users)
        jobs = load_jobs_from_csv(args.jobs)
        print(f"Loaded {len(users)} users and {len(jobs)} jobs from CSV.", file=sys.stderr)

    if not users:
        print("No users loaded. Provide --users CSV or use --firestore.", file=sys.stderr)
        sys.exit(1)
    if not jobs:
        print("No jobs loaded. Provide --jobs CSV or use --firestore.", file=sys.stderr)
        sys.exit(1)

    rows = run_report(users, jobs, highlight_threshold=args.threshold)

    # CSV output
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        fieldnames = ["user_id", "job_id", "match_percentage"]
        if not args.no_highlight:
            fieldnames.append("recommend")
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} rows to {out_path}")

    # Table (first 20 + summary)
    print("\n--- Sample (first 20 rows) ---")
    cols = ["user_id", "job_id", "match_percentage"] + ([] if args.no_highlight else ["recommend"])
    widths = [max(len(str(r.get(c, ""))) for r in rows[:20]) for c in cols]
    widths = [max(w, len(c)) for w, c in zip(widths, cols)]
    header = " | ".join(c.ljust(widths[i]) for i, c in enumerate(cols))
    print(header)
    print("-" * len(header))
    for r in rows[:20]:
        print(" | ".join(str(r.get(c, "")).ljust(widths[i]) for i, c in enumerate(cols)))
    if len(rows) > 20:
        print(f"... and {len(rows) - 20} more rows")

    rec_count = sum(1 for r in rows if r.get("recommend"))
    if not args.no_highlight and rec_count:
        print(f"\n--- Recommendations: {rec_count} user-job pairs with match >= {args.threshold}% ---")
        recs = [r for r in rows if r.get("recommend")][:15]
        for r in recs:
            print(f"  user_id={r['user_id']}, job_id={r['job_id']}, match={r['match_percentage']}%")
        if rec_count > 15:
            print(f"  ... and {rec_count - 15} more (see CSV)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
