import 'firestore_service.dart';

/// Reusable skill API for the app. When a user adds or updates a skill:
/// 1. Skill level/points are stored (and level label is derived: Basic / Intermediate / Advanced).
/// 2. The user's Firestore document is updated, so profile completion % recalculates on the dashboard (stream).
/// 3. Gap analysis is recalculated for all job roles and written to [analysis_results]; recommended
///    courses are fetched when the user opens the gap analysis screen (or from [analysis_results] if used).
///
/// Usage:
/// ```dart
/// import 'package:your_app/services/skill_api.dart';
///
/// await addSkill(uid, 'Python', 70);       // Add or upsert skill with 70 points (Intermediate).
/// await updateSkill(uid, 'Python', 85);     // Update existing skill to 85 points (Advanced).
/// ```

final _firestore = FirestoreService();

/// Adds a new skill for the user, or updates level/points if a skill with the same name already exists.
/// [uid] – Firestore user document id.
/// [skillName] – Display name of the skill (e.g. "Python", "Communication").
/// [points] – Proficiency points 0–100; converted to level (Basic ≤35, Intermediate ≤70, Advanced otherwise).
///
/// After the write, the user document stream emits so the dashboard and any open gap analysis
/// screen update immediately. [analysis_results] is refreshed in the background for all job roles.
Future<void> addSkill(String uid, String skillName, int points) =>
    _firestore.addSkill(uid, skillName, points);

/// Updates an existing skill's level/points by name (match is case-insensitive, trimmed).
/// No-op if no skill with that name exists.
///
/// Dashboard and gap analysis screens listening to the user doc will update immediately.
Future<void> updateSkill(String uid, String skillName, int points) =>
    _firestore.updateSkill(uid, skillName, points);
