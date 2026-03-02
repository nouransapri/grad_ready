import '../models/job_role.dart';

/// Result of comparing user profile with job requirements.
/// All lists use normalized display names (original casing from job/user where applicable).
class GapAnalysisResult {
  final List<String> missingSkills;
  final List<String> missingCourses;
  final double matchPercentage;

  const GapAnalysisResult({
    required this.missingSkills,
    required this.missingCourses,
    required this.matchPercentage,
  });

  Map<String, dynamic> toJson() => {
        'missingSkills': missingSkills,
        'missingCourses': missingCourses,
        'matchPercentage': matchPercentage,
      };
}

/// Service for gap analysis between user profile and job requirements.
/// Uses only user data and job data; no hardcoding. Case-insensitive, normalized text.
class GapAnalysisService {
  /// Normalizes a string for comparison: trim, lowercase, collapse whitespace.
  static String normalize(String? value) {
    if (value == null) return '';
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Adds a single skill name to the set (normalized key) and keeps one display name.
  static void _addSkillNames(Set<String> normalizedSet, Map<String, String> displayNames, List<String> names) {
    for (final name in names) {
      final n = normalize(name);
      if (n.isEmpty) continue;
      normalizedSet.add(n);
      displayNames[n] = name.trim();
    }
  }

  /// Extracts skill names from a list of maps (e.g. skills with "name", or items with "skills" list).
  static void _addSkillNamesFromMaps(
    Set<String> normalizedSet,
    Map<String, String> displayNames,
    List<dynamic>? list, {
    String nameKey = 'name',
    String? skillsListKey,
  }) {
    if (list == null) return;
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(Map<dynamic, dynamic>.from(item));
      if (skillsListKey != null) {
        final skillsList = m[skillsListKey];
        if (skillsList is List) {
          for (final s in skillsList) {
            final name = s is String ? s : s?.toString();
            if (name != null && name.trim().isNotEmpty) {
              _addSkillNames(normalizedSet, displayNames, [name]);
            }
          }
        }
      }
      final name = m[nameKey]?.toString();
      if (name != null && name.trim().isNotEmpty) {
        _addSkillNames(normalizedSet, displayNames, [name]);
      }
    }
  }

  /// Collects and merges all user skill names from profile data.
  /// Sources: direct skills, courses, internships (optional skills), projects (optional skills), clubs (optional skills).
  /// Returns a set of normalized names and a map from normalized -> display name.
  static ({Set<String> normalized, Map<String, String> displayNames}) collectAllUserSkillNames(
    Map<String, dynamic> userData,
  ) {
    final normalizedSet = <String>{};
    final displayNames = <String, String>{};

    // 1. Direct skills list (skills[].name)
    final skills = userData['skills'] as List?;
    if (skills != null) {
      _addSkillNamesFromMaps(normalizedSet, displayNames, skills, nameKey: 'name');
    }

    // 2. Courses (each course name counts as a skill gained)
    final courses = userData['added_courses'] as List?;
    if (courses != null) {
      for (final c in courses) {
        final name = c is String ? c : c?.toString();
        if (name != null && name.trim().isNotEmpty) {
          _addSkillNames(normalizedSet, displayNames, [name]);
        }
      }
    }

    // 3. Internships: optional "skills" list; otherwise no extra skills
    final internships = userData['internships'] as List?;
    if (internships != null) {
      _addSkillNamesFromMaps(
        normalizedSet,
        displayNames,
        internships,
        nameKey: 'title',
        skillsListKey: 'skills',
      );
    }

    // 4. Projects: optional "skills" list
    final projects = userData['projects'] as List?;
    if (projects != null) {
      _addSkillNamesFromMaps(
        normalizedSet,
        displayNames,
        projects,
        nameKey: 'name',
        skillsListKey: 'skills',
      );
    }

    // 5. Student activities (clubs): optional "skills" list
    final clubs = userData['clubs'] as List?;
    if (clubs != null) {
      _addSkillNamesFromMaps(
        normalizedSet,
        displayNames,
        clubs,
        nameKey: 'name',
        skillsListKey: 'skills',
      );
    }

    return (normalized: normalizedSet, displayNames: displayNames);
  }

  /// Returns the list of required skill names for the job (for comparison).
  /// Uses technical + soft skill names when available; otherwise requiredSkills.
  static List<String> getRequiredSkillNames(JobRole job) {
    final fromLevels = <String>[
      ...job.technicalSkillsWithLevel.map((s) => s.name),
      ...job.softSkillsWithLevel.map((s) => s.name),
    ];
    if (fromLevels.isNotEmpty) {
      final seen = <String>{};
      final result = <String>[];
      for (final name in fromLevels) {
        final n = normalize(name);
        if (n.isNotEmpty && !seen.contains(n)) {
          seen.add(n);
          result.add(name.trim());
        }
      }
      return result;
    }
    return job.requiredSkills.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Returns the list of required course names for the job.
  static List<String> getRequiredCourseNames(JobRole job) {
    return job.requiredCourses.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// Runs the full gap analysis: merges user skills, compares to job, returns result.
  /// [userData] is the Firestore user document (e.g. from users/{uid}).
  static GapAnalysisResult runGapAnalysis(Map<String, dynamic> userData, JobRole job) {
    final user = collectAllUserSkillNames(userData);
    final requiredSkills = getRequiredSkillNames(job);
    final requiredCourses = getRequiredCourseNames(job);

    final requiredSkillNormalized = requiredSkills.map((s) => normalize(s)).toList();
    final userSkillNormalized = user.normalized;

    final matchedSkillCount = requiredSkillNormalized.where((r) => userSkillNormalized.contains(r)).length;
    final matchPercentage = requiredSkills.isEmpty
        ? 100.0
        : (matchedSkillCount / requiredSkills.length) * 100.0;

    final missingSkillNormalized = requiredSkillNormalized.where((r) => !userSkillNormalized.contains(r)).toSet();
    final missingSkills = <String>[];
    final addedNormalized = <String>{};
    for (final name in requiredSkills) {
      final n = normalize(name);
      if (missingSkillNormalized.contains(n) && !addedNormalized.contains(n)) {
        addedNormalized.add(n);
        missingSkills.add(name);
      }
    }

    final userCourses = <String>{};
    final coursesList = userData['added_courses'] as List?;
    if (coursesList != null) {
      for (final c in coursesList) {
        final name = c is String ? c : c?.toString();
        if (name != null) {
          userCourses.add(normalize(name));
        }
      }
    }
    final missingCourses = requiredCourses.where((c) => !userCourses.contains(normalize(c))).toList();

    return GapAnalysisResult(
      missingSkills: missingSkills,
      missingCourses: missingCourses,
      matchPercentage: matchPercentage,
    );
  }
}
