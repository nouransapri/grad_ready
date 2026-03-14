/// Shared normalization for skill names (trim, lowercase, collapse spaces).
/// Use this everywhere to avoid duplicate logic and matching bugs.
String normalizeSkillName(String? value) {
  if (value == null) return '';
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}
