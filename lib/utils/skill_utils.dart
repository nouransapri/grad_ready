/// Shared normalization for skill names (trim, lowercase, collapse spaces).
/// Use this everywhere to avoid duplicate logic and matching bugs.
String normalizeSkillName(String? value) {
  if (value == null) return '';
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Single canonical slug for matching skill ids across jobs, users, and Firestore.
/// Aligns with `scripts/import_jobs.js` / sync tools: lowercase, non-alphanumeric → `-`.
/// Also unifies legacy `_` vs `-` so `power_bi` and `power-bi` match.
String canonicalSkillId(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final t = raw.trim().toLowerCase();
  final slug = t.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return slug.replaceAll(RegExp(r'-+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Converts a display skill name to a stable id (Firestore doc id, job requiredSkills).
/// Prefer [canonicalSkillId] for any stored id string.
String skillNameToSkillId(String? name) => canonicalSkillId(name);
