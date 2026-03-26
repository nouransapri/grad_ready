# Gap analysis roadmap (notes)

## Done (1–4)

1. Missing skills ordered by priority + `criticalSkills` in ranking — `GapAnalysisService` + UI.
2. Weighted match % — `weightedMatchPercentage` in header/cards.
3. Visualization — green/orange bar + “High priority” for critical gaps.
4. Skill → suggested courses (lightweight) — `skillRecommendations` / course links under each gap skill.

## Deferred

5. Richer course/task suggestions — optional future Firestore collections.

## Technical notes

- Priority: skills in `criticalSkills` get higher rank (e.g. 1000+); others follow `requiredSkills` order.
- UI: show missing skills sorted by priority; link suggested courses per skill when data exists.
