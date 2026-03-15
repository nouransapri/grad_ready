# Phase 1: Centralized Skills Database

## What was added

- **Firestore collection:** `skills`
- **Document structure:** See `lib/models/skill_document.dart` for the full schema (skillId, skillName, aliases, type, category, courses, certifications, learningResources, practiceProjects, etc.).
- **Seed data:** 10 skills with realistic data in `lib/data/seed_skills_phase1.dart`:
  - JavaScript, Python, React, HTML, CSS, Communication, Teamwork, Problem Solving, Figma, Git
- **Seed function:** `seedSkillsPhase1()` in `lib/data/seed_skills_phase1.dart`

## Safe to run once

The seed function **only inserts** a document if it does **not** already exist (checks by `skillId`). It does **not** overwrite or delete. It does **not** modify `users` or `jobs`.

## How to run the seed

Firestore rules allow **write** on `skills` only when `request.auth.token.admin == true`. So you have two options:

1. **From the app (when logged in as admin):** In a future phase you can add a button in the Admin panel that calls `seedSkillsPhase1()`. For Phase 1, you can call it manually from code, e.g. temporarily in `main.dart`:
   ```dart
   import 'data/seed_skills_phase1.dart';
   // inside kDebugMode block:
   await seedSkillsPhase1();
   ```
   This will only succeed if the app has write access (e.g. after login as admin, or if you temporarily change Firestore rules for testing).

2. **From a script with Admin SDK:** Use a Node.js script with Firebase Admin SDK and a service account key so writes are allowed. (No such script is included in Phase 1; you can add one in `scripts/` if needed.)

## Each skill document includes

- Basic info: skillId, skillName, aliases, type (Technical/Soft/Tool), category, subCategory
- Description: description, difficultyLevel, learningCurve, averageTimeToLearn
- Relationships: prerequisites, relatedSkills, advancedSkills
- Market data: demandLevel, trending, growthRate, averageSalaryImpact
- usedInJobs (array)
- **Courses:** at least 2 per skill with real URLs
- **Certifications:** at least 1 per skill
- **Learning resources:** at least 3 free resources per skill
- **Practice projects:** at least 3 per skill
- Statistics and metadata

Existing `Skill` in `lib/models/skill.dart` and existing UI are **unchanged**. New documents include `name` and `category` for backward compatibility with current `Skill.fromFirestore()`.
