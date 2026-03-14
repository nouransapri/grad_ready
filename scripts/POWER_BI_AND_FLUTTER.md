# Skill Match Results: Power BI & Flutter

## CSV location

- **Path:** `scripts/out/skill_match_results.csv` (after running the script)
- **Flutter copy:** `assets/data/skill_match_results.csv` (used by the app)

**Columns:** `user_id`, `job_id`, `match_percentage`, `recommend`

---

## Power BI

1. Open Power BI Desktop.
2. **Get Data** → **Text/CSV**.
3. Choose:
   - `N:\GradReady Implementation\grad_ready\scripts\out\skill_match_results.csv`
   - or `assets/data/skill_match_results.csv` if you use the app copy.
4. Click **Load** (or **Transform Data** to edit first).
5. Use the columns:
   - **user_id** – filter/slicer by user
   - **job_id** – filter/slicer by job
   - **match_percentage** – for charts (e.g. bar, table)
   - **recommend** – filter or highlight rows where `recommend = true` (match ≥ 70%)
6. Optional:
   - Table visual: all four columns.
   - Slicer: **user_id** and/or **job_id**.
   - Filter on **recommend** = True for “Recommended only”.
   - Conditional formatting on **match_percentage** (e.g. green if ≥ 70%).

---

## Flutter (in-app)

- The app loads **assets/data/skill_match_results.csv**.
- From the **Dashboard**, tap **Skill Match Report** to open the report screen.
- On that screen you can:
  - **Filter by user:** dropdown “Filter by user” (or “All users”).
  - **Recommended only:** check “Recommended only (match ≥ 70%)”.
- The table shows: User ID, Job ID, Match %, Recommend (✓/✗).

To refresh data in the app:

1. Run the Python script (see below) so it writes to `scripts/out/skill_match_results.csv`.
2. Copy that file into the project:
   - Overwrite `assets/data/skill_match_results.csv`.
3. Rebuild/restart the app so it loads the new CSV.

---

## Refresh CSV (Python)

**From CSV (users/jobs files):**

```bash
cd "n:\GradReady Implementation\grad_ready"
python scripts\skill_match_report.py
```

- Reads: `scripts/data/users.csv`, `scripts/data/jobs.csv`.
- Writes: `scripts/out/skill_match_results.csv`.

**From Firestore:**

1. Set the env variable to your service account JSON path:
   - Windows: `set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccountKey.json`
   - Or in PowerShell: `$env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\serviceAccountKey.json"`
2. Install: `pip install firebase-admin`
3. Run (no CSV args):
   ```bash
   python scripts\skill_match_report.py
   ```
   The script will use Firestore when `GOOGLE_APPLICATION_CREDENTIALS` is set and no `--users`/`--jobs` are given.

---

## Summary

| Step              | Action |
|-------------------|--------|
| Generate CSV      | `python scripts\skill_match_report.py` |
| Use in Power BI   | Get Data → Text/CSV → pick the CSV, use columns and filters above |
| Use in Flutter    | Ensure `assets/data/skill_match_results.csv` exists; open “Skill Match Report” from Dashboard |
| Refresh for app   | Regenerate CSV, copy to `assets/data/skill_match_results.csv`, rebuild app |
