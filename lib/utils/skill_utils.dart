/// Shared normalization for skill names (trim, lowercase, collapse spaces).
/// Use this everywhere to avoid duplicate logic and matching bugs.
String normalizeSkillName(String? value) {
  if (value == null) return '';
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Converts a display skill name to a stable id (e.g. for Firestore doc id or matching).
String skillNameToSkillId(String? name) {
  if (name == null || name.trim().isEmpty) return '';
  return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
}
