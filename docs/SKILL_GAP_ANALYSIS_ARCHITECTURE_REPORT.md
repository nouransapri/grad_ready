# Skill Gap Analysis System — Technical Architecture Report

**Project:** GradReady  
**Scope:** Skill gap analysis data sources, storage, matching, and recommendations  
**Date:** March 2025  

---

## 1. Data Sources

### 1.1 User skills

**Source:** Firestore collection `users`, document per user, field `skills`.

- **Structure:** `skills` is a **list**. Each element can be:
  - **Legacy:** a string (skill name only).
  - **Current:** a map with:
    - `name` (string): skill display name  
    - `type` (string): e.g. `"Technical"` or `"Soft"`  
    - `level` (string): `"Basic"` | `"Intermediate"` | `"Advanced"`  
    - `points` (int, optional): 0–100, written by `FirestoreService.addSkill` / `updateSkill`  
- **Also used for matching:** skills are collected from:
  - `userData['skills']` (main list)
  - `userData['internships']` → each item’s `title`, `skills` list
  - `userData['projects']` → each item’s `name`, `skills` list
  - `userData['clubs']` → each item’s `name`, `skills` list  

So “user skills” for analysis = normalized skill **names** from profile skills + internships + projects + clubs. Levels are only used in the **UI** (skills_gap_analysis_screen) when building per-skill gap items; the **core service** does not use levels for the match score.

### 1.2 Job required skills

**Source:** Firestore collection `jobs`, one document per job role.

**Relevant fields:**

- `requiredSkills`: `List<String>` — legacy list of skill names (no levels).
- `technicalSkillsWithLevel`: `List<{ name: string, percent: number }>` — technical skills with required proficiency 0–100.
- `softSkillsWithLevel`: `List<{ name: string, percent: number }>` — soft skills with required proficiency 0–100.
- `criticalSkills`: `List<String>` — names of skills treated as high priority.

**Model (Dart):**

```dart
// lib/models/job_role.dart
class SkillProficiency {
  final String name;
  final int percent;  // 0-100
}
class JobRole {
  final List<String> requiredSkills;
  final List<SkillProficiency> technicalSkillsWithLevel;
  final List<SkillProficiency> softSkillsWithLevel;
  final List<String> criticalSkills;
  // ...
}
```

**Firestore shape (conceptual):**

```json
{
  "title": "Data Analyst",
  "requiredSkills": ["SQL", "Python", "Communication"],
  "technicalSkillsWithLevel": [
    { "name": "SQL", "percent": 80 },
    { "name": "Python", "percent": 75 }
  ],
  "softSkillsWithLevel": [
    { "name": "Communication", "percent": 70 }
  ],
  "criticalSkills": ["SQL", "Python"]
}
```

If `technicalSkillsWithLevel` or `softSkillsWithLevel` are non-empty, they define the **required skill set**; otherwise the service falls back to `requiredSkills` (names only).

### 1.3 Skill levels (user)

- **Stored:** In each skill map in `users.skills`: `level` (string) and optionally `points` (int 0–100).
- **Used in gap UI:** Only `level` is read; it is converted to a percentage via a fixed mapping:
  - `"Advanced"` → 95  
  - `"Intermediate"` → 65  
  - `"Basic"` → 35  
  - Integer/double → clamped to 0–100  
- **Note:** Create-profile flow stores only `name`, `type`, `level` (no `points`). `FirestoreService.addSkill` stores both `level` and `points`. The gap analysis screen uses only `level` (and the mapping above), so stored `points` are not used for analysis.

### 1.4 Skill categories (technical vs soft)

- **Job:** From structure: `technicalSkillsWithLevel` vs `softSkillsWithLevel`. No explicit “category” field per skill; category is implied by which list the skill is in.
- **User:** From `skills[].type` (e.g. `"Technical"`). Used in profile/UI; the **core gap service** does not use user skill type for matching—it only uses normalized **names** and whether the user has that skill (binary).

---

## 2. Skills database structure

### 2.1 Centralized “skills” collection

There is **no** master skills table used for **defining** or **validating** skill names or categories.

- **Firestore collection `skills`** exists and is used only for **recommendations**:
  - **Document ID:** normalized skill identifier (e.g. `name.trim().toLowerCase().replaceAll(/\s+/g, '_')`).
  - **Field:** `suggestedCourses` (array of strings).
- So: **no** central store of skill id, name, category, marketDemand, or synonyms. Skills are **free text** in jobs and user profiles.

### 2.2 Where skills are stored and duplication risk

- **Jobs:** Skill names live in `jobs` documents (`requiredSkills`, `technicalSkillsWithLevel`, `softSkillsWithLevel`, `criticalSkills`). Each job defines its own list; no reference to a shared skill ID.
- **Users:** Skill names (and optional type/level/points) live in `users.skills` as described above.
- **Duplication / consistency:** Duplicate or variant names (e.g. “Data Analysis” vs “Data analysis” vs “data analysis”) are possible. Matching relies on **normalization** (lowercase, trim, collapse spaces); there is no canonical skill ID or master list to prevent duplicates or merge synonyms.

---

## 3. User skills storage

### 3.1 Exact structure

**Create-profile (initial save):**

- `users.skills`: list of maps:
  - `name`: string  
  - `type`: string (e.g. `"Technical"`)  
  - `level`: string (`"Basic"` | `"Intermediate"` | `"Advanced"`)  
- No `skillId`, no numeric level in this path.

**FirestoreService.addSkill / updateSkill:**

- Each skill is a map:
  - `name`: string  
  - `type`: string (default `"Technical"`)  
  - `level`: string (from points: Basic ≤35, Intermediate ≤70, Advanced otherwise)  
  - `points`: int 0–100  

So the **actual** stored shape is:

```json
{
  "skills": [
    {
      "name": "Python",
      "type": "Technical",
      "level": "Intermediate",
      "points": 65
    }
  ]
}
```

Legacy format is still supported: list of plain strings (skill names only).

### 3.2 Storage type summary

| Aspect              | Implementation                                      |
|---------------------|------------------------------------------------------|
| Reference to master | None; no skillId or reference to a skills table.     |
| Level storage       | String `level` (+ optional `points` in addSkill).   |
| Usage in analysis   | Names (normalized) for match; level only in UI.     |

So: **not** raw strings only (maps with name/type/level are used), but **not** references to a master table either—skills are stored as **inline objects with levels**, with no shared skill taxonomy.

---

## 4. Job required skills storage

### 4.1 Structure

- **With levels (preferred):**
  - `technicalSkillsWithLevel` / `softSkillsWithLevel`: list of `{ name, percent }`.
  - `percent` = required proficiency 0–100.
- **Fallback:** `requiredSkills`: list of strings (names only). No required level, no weight, no skillId.

### 4.2 Required level, importance, and references

- **requiredLevel:** Present only when using `technicalSkillsWithLevel` / `softSkillsWithLevel` as the `percent` value. Not present when using only `requiredSkills`.
- **Importance / weight:** Only implied by:
  - **criticalSkills:** if a required skill name is in `criticalSkills`, it is treated as high priority (used for ranking and “high priority” badges). There is no numeric weight; it’s binary (critical vs non-critical).
- **skillId reference:** None. Jobs store skill **names** only.

### 4.3 How the system determines skill gaps

**In GapAnalysisService (backend-style logic):**

1. Build the set of **required skill names** from the job (from levels if present, else `requiredSkills`).
2. Build the set of **user skill names** (normalized) from profile + internships + projects + clubs.
3. For each required skill, if its normalized name is in the user set → **matched**; else → **missing** (gap).
4. Match score = (number of matched skills / number of required skills) × 100. No level or weight in this calculation.

**In the UI (skills_gap_analysis_screen):**

1. Build lists of required skills **with levels** from `technicalSkillsWithLevel` and `softSkillsWithLevel` (or synthetic 70% from `requiredSkills` if empty).
2. For each required skill, get **user level** from `users.skills` (via `level` → fixed mapping to percent).
3. Compare **currentPercent** (user) vs **requiredPercent** (job) to get:
   - **Strong:** current ≥ required  
   - **Developing:** gap ≤ 30%  
   - **Critical:** gap > 30%  
4. Display and recommendations use these UI buckets; the **header match %** still comes from the service (binary match), not from a level-weighted formula.

So: **gap detection** is name-based in the service; **gap severity** (strong/developing/critical) is level-based only in the UI.

---

## 5. Skill normalization

### 5.1 Where it exists

**GapAnalysisService:**

```dart
static String normalize(String? value) {
  if (value == null) return '';
  return value.trim().toLowerCase().replaceAll(RegExp(r'\\s+'), ' ').trim();
}
```

**FirestoreService (addSkill / updateSkill):**

- `_normalizeSkillName`: same idea — trim, lowercase, collapse whitespace to single space.

**skills_gap_analysis_screen:**

- `_normalizeSkillName`: trim, lowercase, collapse spaces (no final trim in one path but equivalent for matching).

So: **yes**, the system normalizes skill names (lowercase, trim, collapse spaces) for **matching** and for **deduplication** when adding/updating user skills.

### 5.2 Risks if normalization were missing

Without normalization:

- “Python” vs “python” vs “ Python ” would not match → false gaps and lower match score.
- Slight spelling or spacing differences would create duplicates in user skills and inconsistent match results.

So the current normalization is important for consistency; the main remaining risk is **semantic** variants (e.g. “ML” vs “Machine Learning”) which are not merged.

---

## 6. Match score calculation

### 6.1 Where it is implemented

- **Service:** `lib/services/gap_analysis_service.dart` → `runGapAnalysis`.
- **UI:** `lib/screens/skills_gap_analysis_screen.dart` → `_displayMatchPercent` (from `GapAnalysisResult`), and per-skill status from `SkillGapItem.status`.

### 6.2 Formula (GapAnalysisService)

- **Required skills:** `requiredSkills = getRequiredSkillNames(job)` (from technical/soft levels if present, else `requiredSkills`).
- **Matched:** For each required skill name (normalized), check if it exists in the normalized set of user skill names (from profile + internships + projects + clubs). Count matches.
- **Match percentage:**

  ```text
  matchPercentage = (matchedCount / requiredCount) * 100
  ```

- **Weighted match:** In the current code, `weightedMatchPercentage = matchPercentage`. So there is **no** extra weighting by level or importance; the name is misleading.

So the **service** match score is: **(number of required skills the user has at least by name) / (total required skills) × 100**. Mathematically it is consistent with a binary (has skill / does not have skill) model.

### 6.3 Strong / developing / critical (UI only)

Defined in `SkillGapItem` (skills_gap_analysis_screen):

- **Strong:** `currentPercent >= requiredPercent`
- **Developing:** `gapPercent <= 30` (and not strong)
- **Critical:** `gapPercent > 30`

Where:

- `gapPercent = (requiredPercent - currentPercent).clamp(0, 100)`
- `currentPercent` = user level (from `level` string mapped to 35/65/95 or from numeric field).
- `requiredPercent` = job’s required level for that skill.

So the **UI** uses a level-based rule; the **header percentage** does not use these buckets—it uses the service’s binary count. So you can have “Strong” in many skills but still a low header % if the service considers many skills “missing” (e.g. because they come from internships/projects and are not in the same normalized form, or because the service and UI use slightly different required-skill sets).

---

## 7. Recommendation logic

### 7.1 Top skill gap

- **Service:** Missing skills are sorted by `skillPriorityRanking` (descending). Critical skills get rank 1000 + order; others get decreasing order. So “top” missing = first in that sorted list.
- **UI:** Among `SkillGapItem`s with `status == 'Critical'`, the one with the **largest** `gapPercent` is chosen as “top priority skill gap” for the Overview card.

### 7.2 High-priority recommendations

- **Service:** `isHighPriority(skillName)` = `skillPriorityRanking[skillName] >= 1000`, i.e. skill is in the job’s `criticalSkills` (after normalization).
- **UI:** “High priority” = skills with `isCriticalGap` (gap > 30%) and/or in job’s `criticalSkills`. Learning path and missing-skill lists are ordered by priority (critical first, then by rank).

### 7.3 Expected score improvement

**UI only** (skills_gap_analysis_screen):

- **Per-skill contribution:** `improvementPerSkill = 100 / totalSkills` (equal weight per skill).
- **Current contribution of a skill:**  
  `currentContribution = (currentPercent / requiredPercent) * improvementPerSkill` (if requiredPercent > 0).
- **Improvement if skill “completed”:**  
  `fullContribution - currentContribution` (where full = improvementPerSkill).
- **Expected score if one skill completed:**  
  `currentScore + improvement` (capped at 100).
- **Potential score (top 3 critical):** Sum of improvements for the top 3 critical skills (by gap), add to current score, cap at 100.

So the algorithm assumes each skill contributes **equally** to the total score (100 / N per skill). There is no job-level or critical-skill weighting in this formula.

---

## 8. Weakness analysis

1. **No centralized skills table**  
   Skills are free text. No canonical IDs, no synonyms, no shared category or market demand. Duplicates and spelling variants can only be handled by normalization, not by design.

2. **Two parallel scoring systems**  
   - Service: binary (has skill / missing) → match % and “missing” list.  
   - UI: level-based (current vs required %) → strong/developing/critical and expected improvement.  
   The header match % is the service’s binary score; the rest of the screen is level-based. They can disagree (e.g. high “strong” count in UI but lower header % if the service counts a skill as missing).

3. **User level not used in service**  
   The service ignores user level; it only checks presence of skill name. So the official “match percentage” does not reflect how strong the user is in each skill, only how many required skills they have at all.

4. **Level stored but not always used**  
   Create-profile stores only `level` (string). addSkill also stores `points`, but the gap screen uses only `level` (mapped to 35/65/95). So finer-grained `points` are not used in analysis.

5. **No skill weighting in match**  
   All required skills count equally. Critical skills affect **ordering** and labels but not the numeric match percentage. So “critical” is not reflected in the score.

6. **Possible mismatch of required-skill sets**  
   Service uses `getRequiredSkillNames(job)` (technical + soft from levels, or requiredSkills). UI builds items from `_technicalSkills` and `_softSkills` (with fallback to requiredSkills and default 70%). If fallbacks differ or lists get out of sync, service and UI can show different sets of skills.

7. **Internships/projects/clubs skill extraction**  
   Service treats any skill name in these sections as “user has this skill.” There is no level or context; it’s binary. So “Python” in a project counts the same as “Python” at Advanced in profile.

8. **Recommendation quality**  
   “Expected score improvement” assumes equal weight per skill and linear addition. No priority weighting or diminishing returns. Course recommendations depend on the `skills` collection (doc id = normalized name, `suggestedCourses`); missing or inconsistent doc ids yield empty suggestions.

---

## 9. Improvement suggestions

### 9.1 Database structure

- **Introduce a master skills collection** (e.g. `skills` or `skill_definitions`) with:
  - `id` (canonical)
  - `name`, `normalizedName`, optional `aliases`
  - `category` (technical / soft)
  - Optional: `marketDemand`, `description`
- **User skills:** Store `skillId` (reference) + `level` or `points` (and optionally source: profile vs internship vs project). Resolve names to IDs on write using the master list or aliases.
- **Job required skills:** Store `skillId` + `requiredLevel` (0–100) + optional `weight` or `isCritical`. Reduces duplicate names and enables consistent matching and reporting.

### 9.2 Skill matching logic

- **Single source of truth:** Use one required-skill list (and one user-skill set) for both the service and the UI so match % and strong/developing/critical align.
- **Level-aware match score:** Define a formula that uses required level and user level (e.g. partial credit when user has the skill but below required level) so the main match % reflects both “has skill” and “at required level.”
- **Optional weighting:** Allow jobs to assign weights or “critical” to skills and use them in the match formula (e.g. weighted sum of (min(1, current/required)) instead of raw count).
- **Synonyms/aliases:** Use the master list (or a small alias map) so “ML” and “Machine Learning” match when appropriate.

### 9.3 Recommendation quality

- **Unify score with UI:** Either make the header “match %” level-based (and use the same formula in the service) or clearly label it as “skills coverage %” (binary).
- **Weight by priority:** In “expected score improvement,” weight critical or high-importance skills more than others instead of 100/N per skill.
- **Recommendations:** Ensure `skills` documents exist for all skills used in jobs (or resolve via master list). Optionally add a “market demand” or “importance” field and use it to order or highlight recommendations.
- **Learning path:** Optionally use both gap size and job priority (critical flag / weight) to order steps and time estimates.

---

## Summary table

| Topic              | Current state                                                                 | Supports accurate analysis? |
|--------------------|-------------------------------------------------------------------------------|-----------------------------|
| Data sources       | User: Firestore `users.skills` (+ internships/projects/clubs). Job: Firestore `jobs` with names and optional levels. | Partially (levels in UI only). |
| Master skills list | None for definitions; `skills` only for suggested courses.                   | No.                         |
| User skills        | Inline maps: name, type, level [, points]. No skillId.                         | Partially (no taxonomy).   |
| Job requirements   | Names + optional percent; criticalSkills for priority. No weight, no skillId. | Partially (no weighting).  |
| Normalization      | Yes (lowercase, trim, collapse spaces).                                        | Yes.                        |
| Match score        | Binary count in service; level-based buckets only in UI.                      | Partially (two systems).    |
| Recommendations    | Priority from criticalSkills; expected improvement = equal weight per skill.  | Partially (no weighting).  |

Overall, the data structure and logic **can support** a reasonable analysis for name-based coverage and level-based gap display, but **accuracy and consistency** are limited by: no master skills table, no level in the core match score, no weighting of skills, and the split between binary (service) and level-based (UI) logic. The suggestions above would bring the architecture closer to a single, level-aware, weighted, and taxonomy-backed model suitable for production-grade analysis and recommendations.
