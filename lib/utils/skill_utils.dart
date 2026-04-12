/// Shared normalization for skill names (trim, lowercase, collapse spaces).
/// Use this everywhere to avoid duplicate logic and matching bugs.
String normalizeSkillName(String? value) {
  if (value == null) return '';
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Stronger normalization key used for alias matching.
/// Removes punctuation so variants like "Node.js", "Node js", "nodejs" converge.
String normalizeSkillAliasKey(String? value) {
  final n = normalizeSkillName(value);
  if (n.isEmpty) return '';
  return n.replaceAll(RegExp(r'[^a-z0-9]+'), '');
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

/// Stable job identity based on normalized title + category.
/// Use this to prevent duplicate role documents for the same role/category pair.
String canonicalJobId(String? title, String? category) {
  final t = title?.trim() ?? '';
  final c = category?.trim() ?? '';
  if (t.isEmpty && c.isEmpty) return '';
  return canonicalSkillId('$t-$c');
}

/// Project-wide level bands for 0-100 scales.
enum SkillLevelBand { beginner, intermediate, advanced, expert }

SkillLevelBand skillLevelBandFromValue(int level) {
  final v = level.clamp(0, 100);
  if (v <= 30) return SkillLevelBand.beginner;
  if (v <= 60) return SkillLevelBand.intermediate;
  if (v <= 80) return SkillLevelBand.advanced;
  return SkillLevelBand.expert;
}

String skillLevelBandLabel(int level) {
  switch (skillLevelBandFromValue(level)) {
    case SkillLevelBand.beginner:
      return 'Beginner';
    case SkillLevelBand.intermediate:
      return 'Intermediate';
    case SkillLevelBand.advanced:
      return 'Advanced';
    case SkillLevelBand.expert:
      return 'Expert';
  }
}
