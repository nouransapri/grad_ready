// Gap analysis compares a Firestore user profile (`skills`, legacy string lists, etc.)
// to a [JobDocument]. When the job exposes structured [JobRequiredSkill] rows
// (`requiredSkillsWithLevel` / `gapRequiredSkillsWithLevel` on the document), we use
// weighted level-based scoring: each requirement contributes
// `min(userLevel/requiredLevel, 1) × importance`. User levels are resolved from
// profile skill entries via the master skills catalog (canonical ids, aliases, and
// composite ids like `machine-learning-python` → `python`). [mergeJobRequiredSkillsCatalog]
// injects placeholder [Skill] rows for any job requirement id missing from the cache so
// analysis still runs offline of a full catalog. If structured requirements are absent,
// we fall back to legacy [JobRole]-style technical/soft lists and name-based matching.
import 'dart:developer' as developer;


import '../models/job_document.dart';
import '../models/job_role.dart';
import '../models/skill.dart';
import '../utils/skill_utils.dart';

import 'skills_analysis_service.dart';

/// One step in a learning path: a missing skill with priority and suggested resources.
class LearningStep {
  final int stepNumber;
  final String skillName;
  final int priority;
  final List<String> suggestedCourses;
  const LearningStep({
    required this.stepNumber,
    required this.skillName,
    required this.priority,
    required this.suggestedCourses,
  });
}

/// Technical vs soft skill match counts for chart visualization.
class SkillMatchDistribution {
  final int technicalMatched;
  final int technicalTotal;
  final int softMatched;
  final int softTotal;

  const SkillMatchDistribution({
    required this.technicalMatched,
    required this.technicalTotal,
    required this.softMatched,
    required this.softTotal,
  });
}

/// Aggregated market insights (for Admin dashboard). Populated by separate aggregation logic.
class MarketInsights {
  final List<String> mostMissingSkills;
  final List<String> mostMatchedSkills;
  final List<String> topDemandedSkills;

  const MarketInsights({
    this.mostMissingSkills = const [],
    this.mostMatchedSkills = const [],
    this.topDemandedSkills = const [],
  });
}

/// Result of gap analysis: skills only (no course fields). Includes recommendations and visualization data.
class GapAnalysisResult {
  final List<String> matchedSkills;
  /// Skills where the user is below the job requirement (missing entirely or lower level).
  final List<String> missingSkills;
  final double matchPercentage;
  final double weightedMatchPercentage;
  final Map<String, int> skillPriorityRanking;
  final Map<String, List<String>> skillRecommendations;
  final List<LearningStep> learningPath;
  final Map<String, String> skillGapSeverity;
  final SkillMatchDistribution skillMatchDistribution;
  final List<String> prioritySkills;
  final List<String> missingSkillsByPriority;
  final bool isQualified;
  final List<String> missingMandatorySkills;
  final List<String> mandatorySkills;


  const GapAnalysisResult({
    required this.matchedSkills,
    required this.missingSkills,
    required this.matchPercentage,
    required this.weightedMatchPercentage,
    required this.skillPriorityRanking,
    required this.skillRecommendations,
    required this.learningPath,
    required this.skillGapSeverity,
    required this.skillMatchDistribution,
    required this.prioritySkills,
    required this.missingSkillsByPriority,
    required this.isQualified,
    required this.missingMandatorySkills,
    required this.mandatorySkills,
  });

  bool isHighPriority(String skillName) {
    final rank = skillPriorityRanking[skillName] ?? 0;
    return rank >= 1000;
  }
}

/// Stateless helpers for computing skill gaps, match percentages, learning paths, and
/// course recommendations between a user document and a [JobDocument].
///
/// **Two modes:** (1) *Level-based* when [JobDocument] exposes structured requirements
/// (`gapRequiredSkillsWithLevel` / legacy `requiredSkillsWithLevel` via [JobRole] projection).
/// (2) *Legacy* when only flat skill names / tech-soft splits exist — binary or percent-based
/// comparison using [collectUserLevelsBySkillId] and name normalization.
class GapAnalysisService {
  static const int _criticalPriorityThreshold = 1000;
  static const int _priorityWeightBase = 500;
  static const int _criticalWeight = 10;
  static const int _defaultWeight = 5;
  static const double _compositeFallbackPenalty = 0.85;

  static String? _resolveSkillIdFromCatalog(
    Map<String, Skill> catalog,
    String raw,
  ) {
    final c = canonicalSkillId(raw);
    if (c.isEmpty) return null;
    if (catalog.containsKey(c)) return c;

    final nameKey = normalizeSkillAliasKey(raw);
    for (final s in catalog.values) {
      final sid = canonicalSkillId(s.id);
      if (sid == c) return sid;
      if (normalizeSkillAliasKey(s.name) == nameKey) return sid;
      for (final alias in s.aliases) {
        if (normalizeSkillAliasKey(alias) == nameKey) return sid;
      }
    }

    // Fallback: composite ids like "machine-learning-python" -> "python".
    final tokens = c.split('-').where((t) => t.length >= 3).toList().reversed;
    for (final t in tokens) {
      if (catalog.containsKey(t)) return t;
      for (final s in catalog.values) {
        final sid = canonicalSkillId(s.id);
        if (sid == t) return sid;
        if (normalizeSkillAliasKey(s.name) == t) return sid;
        for (final alias in s.aliases) {
          if (normalizeSkillAliasKey(alias) == t) return sid;
        }
      }
    }
    return null;
  }

  /// Resolves a skill from the catalog when keys differ by slug style (`-` vs `_`) or casing.
  static Skill? _catalogSkill(Map<String, Skill> catalog, String skillId) {
    final resolved = _resolveSkillIdFromCatalog(catalog, skillId);
    final byKey = resolved == null ? null : catalog[resolved];
    if (byKey != null) return byKey;
    final c = canonicalSkillId(skillId);
    final byRaw = catalog[c] ?? catalog[skillId];
    if (byRaw != null) return byRaw;
    for (final s in catalog.values) {
      if (canonicalSkillId(s.id) == c) return s;
    }
    return null;
  }

  static int _userLevelFor(Map<String, int> userLevels, String skillId) {
    final c = canonicalSkillId(skillId);
    final direct = userLevels[c] ?? userLevels[skillId];
    if (direct != null) return direct;
    // Fallback for composite job ids.
    final tokens = c.split('-').where((t) => t.length >= 3).toList().reversed;
    for (final t in tokens) {
      final v = userLevels[t];
      if (v != null && v > 0) return v;
    }
    return 0;
  }

  static bool _isCompositeFallback(String requestedSkillId, String resolvedSkillId) {
    final requested = canonicalSkillId(requestedSkillId);
    final resolved = canonicalSkillId(resolvedSkillId);
    if (requested.isEmpty || resolved.isEmpty) return false;
    if (requested == resolved) return false;
    if (!requested.contains('-')) return false;
    final tokens = requested.split('-').where((t) => t.length >= 3);
    return tokens.contains(resolved);
  }

  static int _legacyUserLevelByName(
    Map<String, dynamic> userData,
    String requiredSkillName,
  ) {
    final skills = userData['skills'] as List?;
    if (skills == null || requiredSkillName.trim().isEmpty) return 0;
    final target = normalizeSkillName(requiredSkillName);
    int best = 0;
    for (final s in skills) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(
        s.map((k, v) => MapEntry(k.toString(), v)),
      );
      final name = m['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final n = normalizeSkillName(name);
      if (!(n == target || n.contains(target) || target.contains(n))) continue;
      int level = 0;
      if (m['level'] is int) {
        level = (m['level'] as int).clamp(0, 100);
      } else if (m['points'] is int) {
        level = (m['points'] as int).clamp(0, 100);
      } else {
        final str = m['level']?.toString().trim().toLowerCase() ?? '';
        if (str == 'advanced' || str == 'expert') {
          level = 95;
        } else if (str == 'intermediate' || str == 'intermidiate' || str == 'mid') {
          level = 65;
        } else if (str == 'basic' || str == 'beginner') {
          level = 35;
        } else {
          level = (int.tryParse(str) ?? 35).clamp(0, 100);
        }
      }
      if (level > best) best = level;
    }
    return best;
  }

  /// Level-based skill score: min(userLevel / requiredLevel, 1). Same formula used in UI.
  static double skillScoreForLevel(int userLevel, int requiredLevel) {
    if (requiredLevel <= 0) return 1.0;
    final ratio = userLevel / requiredLevel;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  /// Delegates to [SkillsAnalysisService.weightedMatchRatio] (Σ(score×weight)/Σ(weight)).
  static double weightedMatchScore(
    List<double> skillScores,
    List<int> weights,
  ) =>
      SkillsAnalysisService.weightedMatchRatio(skillScores, weights);

  /// Builds user skillId -> level (0–100) from user document. Supports new (skillId, level) and legacy (name, level/points).
  static Map<String, int> collectUserLevelsBySkillId(
    Map<String, dynamic> userData,
    Map<String, Skill>? skillsCatalog,
  ) {
    final result = <String, int>{};
    final skills = userData['skills'] as List?;
    if (skills == null) return result;

    for (final s in skills) {
      final us = UserSkill.fromFirestore(s);
      if (us != null) {
        final level = us.level.clamp(0, 100);
        final cid = canonicalSkillId(us.skillId);
        if (level > (result[cid] ?? 0)) result[cid] = level;
        continue;
      }
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(
        s.map((k, v) => MapEntry(k.toString(), v)),
      );
      final name = m['name']?.toString().trim();
      if (name == null || name.isEmpty) continue;
      int level = 0;
      if (m['level'] is int) {
        level = (m['level'] as int).clamp(0, 100);
      } else if (m['points'] is int) {
        level = (m['points'] as int).clamp(0, 100);
      } else {
        final str = m['level']?.toString().trim().toLowerCase() ?? '';
        if (str == 'advanced' || str == 'expert') {
          level = 95;
        } else if (str == 'intermediate' || str == 'intermidiate' || str == 'mid')
          level = 65;
        else if (str == 'basic' || str == 'beginner')
          level = 35;
        else
          level = (int.tryParse(str) ?? 35).clamp(0, 100);
      }
      if (skillsCatalog != null && skillsCatalog.isNotEmpty) {
        final resolved = _resolveSkillIdFromCatalog(skillsCatalog, name);
        if (resolved != null && resolved.isNotEmpty) {
          if (level > (result[resolved] ?? 0)) result[resolved] = level;
        } else {
          final n = normalizeSkillName(name);
          for (final skill in skillsCatalog.values) {
            if (normalizeSkillName(skill.name) == n) {
              final cid = canonicalSkillId(skill.id);
              if (level > (result[cid] ?? 0)) result[cid] = level;
              break;
            }
          }
        }
      }
    }
    return result;
  }

  /// Delegates to shared [normalizeSkillName] for consistent matching.
  static String normalize(String? value) => normalizeSkillName(value);

  static void _addSkillNames(
    Set<String> normalizedSet,
    Map<String, String> displayNames,
    List<String> names,
  ) {
    for (final name in names) {
      final n = normalize(name);
      if (n.isEmpty) continue;
      normalizedSet.add(n);
      displayNames[n] = name.trim();
    }
  }

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

  /// Collects user skill names from profile. No course reading.
  static ({Set<String> normalized, Map<String, String> displayNames})
  collectAllUserSkillNames(Map<String, dynamic> userData) {
    final normalizedSet = <String>{};
    final displayNames = <String, String>{};

    final skills = userData['skills'] as List?;
    if (skills != null) {
      for (final s in skills) {
        if (s is String && s.trim().isNotEmpty) {
          _addSkillNames(normalizedSet, displayNames, [s]);
        } else if (s is Map) {
          final name = s['name']?.toString().trim();
          if (name != null && name.isNotEmpty) {
            _addSkillNames(normalizedSet, displayNames, [name]);
          }
        }
      }
    }

    for (final internships in [userData['internships'] as List?]) {
      _addSkillNamesFromMaps(
        normalizedSet,
        displayNames,
        internships ?? const [],
        nameKey: 'title',
        skillsListKey: 'skills',
      );
    }

    _addSkillNamesFromMaps(
      normalizedSet,
      displayNames,
      (userData['projects'] as List?) ?? const [],
      nameKey: 'name',
      skillsListKey: 'skills',
    );
    _addSkillNamesFromMaps(
      normalizedSet,
      displayNames,
      (userData['clubs'] as List?) ?? const [],
      nameKey: 'name',
      skillsListKey: 'skills',
    );

    return (normalized: normalizedSet, displayNames: displayNames);
  }

  /// Readable label from a job/user skill id slug (e.g. `power-bi` → `Power Bi`).
  static String displayNameFromSkillId(String raw) {
    final s = raw.trim();
    if (s.isEmpty) {
      return raw;
    }
    final parts = s
        .replaceAll('_', '-')
        .split(RegExp(r'[-\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return s;
    }
    const acronyms = <String, String>{
      'sql': 'SQL',
      'ui': 'UI',
      'ux': 'UX',
      'api': 'API',
      'qa': 'QA',
      'ai': 'AI',
      'ml': 'ML',
      'aws': 'AWS',
      'gcp': 'GCP',
      'html': 'HTML',
      'css': 'CSS',
      'js': 'JS',
      'ios': 'iOS',
      'seo': 'SEO',
    };
    return parts
        .map(
          (p) => acronyms[p.toLowerCase()] ??
              (p.length == 1
              ? p.toUpperCase()
              : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}'),
        )
        .join(' ');
  }

  /// Builds a catalog map that includes every [JobRequiredSkill.skillId] on the job, creating
  /// minimal [Skill] rows (Technical vs Soft inferred from the job’s soft-skill set) when the
  /// Firestore `skills` collection does not yet contain that id.
  static Map<String, Skill> mergeJobRequiredSkillsCatalog(
    JobDocument job,
    Map<String, Skill>? catalog,
  ) {
    final jobRole = job.toJobRole();
    final out = <String, Skill>{
      if (catalog != null) ...catalog,
    };
    final softIds = jobRole.softSkillsWithLevel
        .map((s) => canonicalSkillId(s.name))
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final req in jobRole.requiredSkillsWithLevel) {
      if (_catalogSkill(out, req.skillId) != null) {
        continue;
      }
      final cid = canonicalSkillId(req.skillId);
      final category = softIds.contains(cid) ? 'Soft' : 'Technical';
      out[cid] = Skill(
        id: cid,
        name: displayNameFromSkillId(req.skillId),
        category: category,
      );
    }
    return out;
  }

  static List<String> _getRequiredSkillNamesFromRole(JobRole job) {
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
    return job.requiredSkills
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static List<String> getRequiredSkillNames(JobDocument job) =>
      _getRequiredSkillNamesFromRole(job.toJobRole());

  /// Main entry: computes [GapAnalysisResult] (match %, missing skills, recommendations, learning path).
  ///
  /// Routes to [_runLevelBasedGapAnalysis] when [JobDocument] (via [JobRole] projection) has
  /// `requiredSkillsWithLevel`; otherwise [_runLegacyGapAnalysis]. Optional Firestore-backed
  /// callbacks load course titles and URLs for the UI without embedding course data in the job.
  static Future<GapAnalysisResult> runGapAnalysis(
    Map<String, dynamic> userData,
    JobDocument job, {
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
    Future<Map<String, List<String>>> Function(
      List<String> missingSkillNames,
      Set<String> userSkillIds,
    )?
    fetchSmartRecommendations,

    Map<String, Skill>? skillsCatalog,
  }) async {
    final jobRole = job.toJobRole();
    if (jobRole.requiredSkillsWithLevel.isEmpty && jobRole.requiredSkills.isEmpty) {
      return const GapAnalysisResult(
        matchedSkills: <String>[],
        missingSkills: <String>[],
        matchPercentage: 0,
        weightedMatchPercentage: 0,
        skillPriorityRanking: <String, int>{},
        skillRecommendations: <String, List<String>>{},
        learningPath: <LearningStep>[],
        skillGapSeverity: <String, String>{},
        skillMatchDistribution: SkillMatchDistribution(
          technicalMatched: 0,
          technicalTotal: 0,
          softMatched: 0,
          softTotal: 0,
        ),
        prioritySkills: <String>[],
        missingSkillsByPriority: <String>[],
        isQualified: false,
        missingMandatorySkills: <String>[],
        mandatorySkills: <String>[],
      );
    }
    if (jobRole.requiredSkillsWithLevel.isNotEmpty) {
      final merged = mergeJobRequiredSkillsCatalog(job, skillsCatalog);
      return _runLevelBasedGapAnalysis(
        userData,
        job,
        jobRole,
        merged,
        fetchRecommendations,
        fetchSmartRecommendations,
      );
    }
    return _runLegacyGapAnalysis(
      userData,
      jobRole,
      fetchRecommendations,
      fetchSmartRecommendations,
    );
  }

  static Future<GapAnalysisResult> _runLevelBasedGapAnalysis(
    Map<String, dynamic> userData,
    JobDocument jobDoc,
    JobRole job,
    Map<String, Skill> skillsCatalog,
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
    Future<Map<String, List<String>>> Function(
      List<String> missingSkillNames,
      Set<String> userSkillIds,
    )?
    fetchSmartRecommendations,

  ) async {
    final userLevels = collectUserLevelsBySkillId(userData, skillsCatalog);
    final requiredList = job.requiredSkillsWithLevel;
    final mandatoryIds = jobDoc.gapMandatorySkillIds;
    // Name-based fallback: catches mandatory skills even when skillId resolution
    // produces a different canonical id than what was stored in mandatoryIds.
    final mandatoryNormalizedNames = jobDoc.gapMandatorySkillNames
        .map(normalizeSkillName)
        .where((n) => n.isNotEmpty)
        .toSet();
    final hasMandatoryDefined =
        mandatoryIds.isNotEmpty || mandatoryNormalizedNames.isNotEmpty;

    developer.log(
      'Mandatory setup: mandatoryIds=${mandatoryIds.length} [${mandatoryIds.join(", ")}] | '
      'mandatoryNames=${mandatoryNormalizedNames.length} [${mandatoryNormalizedNames.join(", ")}] | '
      'hasMandatoryDefined=$hasMandatoryDefined | requiredList=${requiredList.length}',
      name: 'GapAnalysisService',
    );

    // ---------------------------------------------------------------
    // Stage 1 — Hard Gate: evaluate mandatory skills independently.
    // A skill is mandatory when its raw OR resolved canonical id is in
    // mandatoryIds, OR its display name matches a mandatory name.
    // Checking both IDs prevents silent misses caused by catalog
    // resolution changing "machine-learning-python" → "python" etc.
    // ---------------------------------------------------------------
    final missingMandatorySkills = <String>[];

    for (final req in requiredList) {
      final rawCanonical = canonicalSkillId(req.skillId);
      final resolvedReqId =
          _resolveSkillIdFromCatalog(skillsCatalog, req.skillId) ?? req.skillId;
      final reqCanonical = canonicalSkillId(resolvedReqId);
      final skill = _catalogSkill(skillsCatalog, resolvedReqId);
      final name = skill?.name ?? displayNameFromSkillId(resolvedReqId);

      final isMandatory = mandatoryIds.contains(reqCanonical) ||
          mandatoryIds.contains(rawCanonical) ||
          mandatoryNormalizedNames.contains(normalizeSkillName(name)) ||
          mandatoryNormalizedNames.contains(
              normalizeSkillName(displayNameFromSkillId(req.skillId)));
      if (!isMandatory) continue;

      int userLevel = _userLevelFor(userLevels, resolvedReqId);
      if (userLevel == 0) {
        userLevel = _legacyUserLevelByName(userData, name);
      }
      var score = skillScoreForLevel(userLevel, req.requiredLevel);
      if (_isCompositeFallback(req.skillId, resolvedReqId)) {
        score *= _compositeFallbackPenalty;
      }

      if (score < 1.0) {
        missingMandatorySkills.add(name);
      }
    }

    developer.log(
      'Hard Gate: mandatoryIds=${mandatoryIds.length}, '
      'mandatoryNames=${mandatoryNormalizedNames.length}, '
      'missing=${missingMandatorySkills.length}'
      '${missingMandatorySkills.isNotEmpty ? " [${missingMandatorySkills.join(", ")}]" : ""}',
      name: 'GapAnalysisService',
    );

    // ---------------------------------------------------------------
    // Stage 2 — Scoring: compute match percentages from ALL skills
    // (mandatory + optional). These numbers inform the UI but never
    // change the isQualified verdict from Stage 1.
    // ---------------------------------------------------------------
    final skillScores = <double>[];
    final weights = <int>[];
    final matchedNames = <String>[];
    final missingWithMeta =
        <({String skillId, String name, int importance, double score, bool isMandatory})>[];

    for (final req in requiredList) {
      final resolvedReqId =
          _resolveSkillIdFromCatalog(skillsCatalog, req.skillId) ?? req.skillId;
      final skill = _catalogSkill(skillsCatalog, resolvedReqId);
      final name = skill?.name ?? resolvedReqId;
      final reqCanonical = canonicalSkillId(resolvedReqId);
      final isMandatory = mandatoryIds.contains(reqCanonical);
      int userLevel = _userLevelFor(userLevels, resolvedReqId);
      if (userLevel == 0) {
        userLevel = _legacyUserLevelByName(userData, name);
      }
      var score = skillScoreForLevel(userLevel, req.requiredLevel);
      if (_isCompositeFallback(req.skillId, resolvedReqId)) {
        score *= _compositeFallbackPenalty;
      }
      final w = req.weight.clamp(1, 10);
      skillScores.add(score);
      weights.add(w);
      if (score >= 1.0) {
        matchedNames.add(name);
      } else {
        missingWithMeta.add((
          skillId: resolvedReqId,
          name: name,
          importance: req.importance.clamp(1, 3),
          score: score,
          isMandatory: isMandatory,
        ));
      }
    }

    final weightedScore = SkillsAnalysisService.weightedMatchRatio(
      skillScores,
      weights,
    );
    final matchedCount = skillScores.where((s) => s >= 1.0).length;
    final simpleScore = requiredList.isEmpty ? 0.0 : (matchedCount / requiredList.length);
    final matchPercentage = simpleScore * 100;
    final weightedMatchPercentage = weightedScore * 100;

    developer.log(
      'Scoring: total=${requiredList.length}, matched=$matchedCount, '
      'match%=${matchPercentage.toStringAsFixed(1)}, '
      'weighted%=${weightedMatchPercentage.toStringAsFixed(1)}',
      name: 'GapAnalysisService',
    );

    // Sort missing by mandatory first, then importance (high→low), then gap (low score first).
    missingWithMeta.sort((a, b) {
      if (a.isMandatory != b.isMandatory) {
        return a.isMandatory ? -1 : 1;
      }
      final impCmp = b.importance.compareTo(a.importance);
      if (impCmp != 0) return impCmp;
      return a.score.compareTo(b.score);
    });
    final missingSkills = missingWithMeta.map((e) => e.name).toList();

    // If no mandatory skills are configured on the job, require a 100% match.
    // This prevents "Qualified" when the job has no Critical-priority skills
    // but the user matches very few required skills.
    final isQualified = mandatoryIds.isEmpty
        ? missingSkills.isEmpty
        : missingMandatorySkills.isEmpty;

    developer.log(
      'Hard Gate result: qualified=$isQualified '
      '(mandatoryIds=${mandatoryIds.length}, missingMandatory=${missingMandatorySkills.length}, '
      'missingTotal=${missingSkills.length})',
      name: 'GapAnalysisService',
    );

    final skillPriorityRanking = <String, int>{};
    for (var i = 0; i < requiredList.length; i++) {
      final req = requiredList[i];
      final skill = _catalogSkill(skillsCatalog, req.skillId);
      final name = skill?.name ?? req.skillId;
      final imp = req.importance.clamp(1, 3);
      skillPriorityRanking[name] = imp * _priorityWeightBase + (requiredList.length - i);
    }

    Map<String, List<String>> skillRecommendations = {};
    final userSkillIds = userLevels.keys.map(canonicalSkillId).toSet();
    if (fetchSmartRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchSmartRecommendations(
          missingSkills,
          userSkillIds,
        );
      } catch (e, st) {
        developer.log(
          'fetchSmartRecommendations failed: $e',
          name: 'GapAnalysisService',
          error: e,
          stackTrace: st,
        );
        skillRecommendations = <String, List<String>>{};
      }
    } else if (fetchRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchRecommendations(missingSkills);
      } catch (e, st) {
        developer.log(
          'fetchRecommendations failed: $e',
          name: 'GapAnalysisService',
          error: e,
          stackTrace: st,
        );
        skillRecommendations = <String, List<String>>{};
      }
    }



    final learningPath = <LearningStep>[];
    for (var i = 0; i < missingWithMeta.length; i++) {
      final m = missingWithMeta[i];
      learningPath.add(
        LearningStep(
          stepNumber: i + 1,
          skillName: m.name,
          priority: skillPriorityRanking[m.name] ?? 0,
          suggestedCourses: skillRecommendations[m.name] ?? [],
        ),
      );
    }

    final skillGapSeverity = <String, String>{};
    for (final m in missingWithMeta) {
      skillGapSeverity[m.name] = m.isMandatory
          ? 'Hard Gate'
          : (m.importance >= 3
              ? 'High Gap'
              : (m.importance >= 2 ? 'Medium Gap' : 'Low Gap'));
    }

    final technicalIds = skillsCatalog.values
        .where((s) => s.isTechnical)
        .map((s) => canonicalSkillId(s.id))
        .toSet();
    int technicalMatched = 0,
        technicalTotal = 0,
        softMatched = 0,
        softTotal = 0;
    for (var i = 0; i < requiredList.length; i++) {
      final req = requiredList[i];
      final isTech = technicalIds.contains(canonicalSkillId(req.skillId));
      if (isTech) {
        technicalTotal++;
        if (skillScores[i] >= 1.0) technicalMatched++;
      } else {
        softTotal++;
        if (skillScores[i] >= 1.0) softMatched++;
      }
    }
    final skillMatchDistribution = SkillMatchDistribution(
      technicalMatched: technicalMatched,
      technicalTotal: technicalTotal,
      softMatched: softMatched,
      softTotal: softTotal,
    );

    final prioritySkills = missingWithMeta
        .where((m) => m.isMandatory || m.importance >= 3)
        .map((m) => m.name)
        .toList();

    return GapAnalysisResult(
      matchedSkills: matchedNames,
      missingSkills: missingSkills,
      matchPercentage: matchPercentage,
      weightedMatchPercentage: weightedMatchPercentage,
      skillPriorityRanking: skillPriorityRanking,
      skillRecommendations: skillRecommendations,
      learningPath: learningPath,
      skillGapSeverity: skillGapSeverity,
      skillMatchDistribution: skillMatchDistribution,
      prioritySkills: prioritySkills,
      missingSkillsByPriority: List.from(missingSkills),
      isQualified: isQualified,
      missingMandatorySkills: missingMandatorySkills,
      mandatorySkills: jobDoc.gapMandatorySkillNames,
    );
  }

  static Future<GapAnalysisResult> _runLegacyGapAnalysis(
    Map<String, dynamic> userData,
    JobRole job,
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
    Future<Map<String, List<String>>> Function(
      List<String> missingSkillNames,
      Set<String> userSkillIds,
    )?
    fetchSmartRecommendations,

  ) async {
    final user = collectAllUserSkillNames(userData);
    final requiredSkills = _getRequiredSkillNamesFromRole(job);
    final userSkillNormalized = user.normalized;

    final technicalSkills = job.technicalSkillsWithLevel
        .map((s) => s.name)
        .toList();
    final softSkills = job.softSkillsWithLevel.map((s) => s.name).toList();
    final technicalNormalized = technicalSkills
        .map((s) => normalize(s))
        .toList();
    final softNormalized = softSkills.map((s) => normalize(s)).toList();

    final useTechSoftLevels = job.technicalSkillsWithLevel.isNotEmpty ||
        job.softSkillsWithLevel.isNotEmpty;
    final Map<String, int> requiredPctByNorm = {};
    if (useTechSoftLevels) {
      void addPct(SkillProficiency s) {
        final n = normalize(s.name);
        if (n.isEmpty) return;
        final p = s.percent.clamp(0, 100);
        if (p > (requiredPctByNorm[n] ?? 0)) requiredPctByNorm[n] = p;
      }
      for (final s in job.technicalSkillsWithLevel) addPct(s);
      for (final s in job.softSkillsWithLevel) addPct(s);
    }

    int technicalMatchCount;
    int softMatchCount;
    if (useTechSoftLevels && requiredPctByNorm.isNotEmpty) {
      bool meets(SkillProficiency s) {
        final n = normalize(s.name);
        final need = requiredPctByNorm[n] ?? s.percent.clamp(0, 100);
        final u = _legacyUserLevelByName(userData, s.name);
        if (need <= 0) return userSkillNormalized.contains(n);
        return skillScoreForLevel(u, need) >= 1.0;
      }

      technicalMatchCount =
          job.technicalSkillsWithLevel.where(meets).length;
      softMatchCount = job.softSkillsWithLevel.where(meets).length;
    } else {
      technicalMatchCount = technicalNormalized
          .where((s) => userSkillNormalized.contains(s))
          .length;
      softMatchCount = softNormalized
          .where((s) => userSkillNormalized.contains(s))
          .length;
    }

    final criticalNormalized = job.criticalSkills
        .map((s) => normalize(s))
        .where((s) => s.isNotEmpty)
        .toSet();

    final skillPriorityRanking = <String, int>{};
    int orderPriority = requiredSkills.length;
    for (final skill in requiredSkills) {
      final n = normalize(skill);
      final isCritical = criticalNormalized.contains(n);
      skillPriorityRanking[skill] = isCritical
          ? _criticalPriorityThreshold + orderPriority
          : orderPriority;
      orderPriority -= 1;
    }

    final missingSkills = <String>[];
    final matchedSkills = <String>[];
    for (final skill in requiredSkills) {
      final n = normalize(skill);
      if (n.isEmpty) continue;
      if (useTechSoftLevels && requiredPctByNorm.isNotEmpty) {
        final need = requiredPctByNorm[n] ?? 0;
        final userLevel = _legacyUserLevelByName(userData, skill);
        if (need <= 0) {
          if (userSkillNormalized.contains(n)) {
            matchedSkills.add(skill);
          } else {
            missingSkills.add(skill);
          }
        } else if (skillScoreForLevel(userLevel, need) >= 1.0) {
          matchedSkills.add(skill);
        } else {
          missingSkills.add(skill);
        }
      } else {
        if (userSkillNormalized.contains(n)) {
          matchedSkills.add(skill);
        } else {
          missingSkills.add(skill);
        }
      }
    }
    missingSkills.sort(
      (a, b) => (skillPriorityRanking[b] ?? 0).compareTo(
        skillPriorityRanking[a] ?? 0,
      ),
    );

    final int requiredCount = requiredSkills.length;
    double matchPercentage;
    double weightedMatchPercentage;
    if (useTechSoftLevels &&
        requiredPctByNorm.isNotEmpty &&
        requiredCount > 0) {
      final scores = <double>[];
      final weights = <int>[];
      for (final skill in requiredSkills) {
        final n = normalize(skill);
        if (n.isEmpty) continue;
        final need = requiredPctByNorm[n] ?? 0;
        final userLevel = _legacyUserLevelByName(userData, skill);
        if (need <= 0) {
          scores.add(userSkillNormalized.contains(n) ? 1.0 : 0.0);
        } else {
          scores.add(skillScoreForLevel(userLevel, need));
        }
        weights.add(criticalNormalized.contains(n) ? _criticalWeight : _defaultWeight);
      }
      final m = weightedMatchScore(scores, weights);
      weightedMatchPercentage = m * 100;
      matchPercentage = requiredCount > 0
          ? (matchedSkills.length / requiredCount) * 100
          : 0.0;
    } else {
      // Match score = (matched skills / total required skills) * 100.
      matchPercentage = requiredCount > 0
          ? (matchedSkills.length / requiredCount) * 100
          : 0.0;
      weightedMatchPercentage = matchPercentage;
    }

    Map<String, List<String>> skillRecommendations = {};
    final userSkillIds = collectUserLevelsBySkillId(userData, null)
        .keys
        .map(canonicalSkillId)
        .toSet();
    if (fetchSmartRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchSmartRecommendations(
          missingSkills,
          userSkillIds,
        );
      } catch (e, st) {
        developer.log(
          'fetchSmartRecommendations failed: $e',
          name: 'GapAnalysisService',
          error: e,
          stackTrace: st,
        );
        skillRecommendations = <String, List<String>>{};
      }
    } else if (fetchRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchRecommendations(missingSkills);
      } catch (e, st) {
        developer.log(
          'fetchRecommendations failed: $e',
          name: 'GapAnalysisService',
          error: e,
          stackTrace: st,
        );
        skillRecommendations = <String, List<String>>{};
      }
    }



    final learningPath = <LearningStep>[];
    for (var i = 0; i < missingSkills.length; i++) {
      final skill = missingSkills[i];
      learningPath.add(
        LearningStep(
          stepNumber: i + 1,
          skillName: skill,
          priority: skillPriorityRanking[skill] ?? 0,
          suggestedCourses: skillRecommendations[skill] ?? [],
        ),
      );
    }

    final nonCriticalRanks =
        requiredSkills
            .where((s) => (skillPriorityRanking[s] ?? 0) < _criticalPriorityThreshold)
            .map((s) => skillPriorityRanking[s] ?? 0)
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final rankCount = nonCriticalRanks.length;
    final highThreshold = rankCount > 0 ? nonCriticalRanks[0] : 0;
    final lowThreshold = rankCount > 0 ? nonCriticalRanks[rankCount - 1] : 0;
    final midThreshold = (highThreshold + lowThreshold) ~/ 2;

    final skillGapSeverity = <String, String>{};
    for (final skill in missingSkills) {
      final rank = skillPriorityRanking[skill] ?? 0;
      if (rank >= _criticalPriorityThreshold) {
        skillGapSeverity[skill] = 'High Gap';
      } else if (rank >= midThreshold) {
        skillGapSeverity[skill] = 'High Gap';
      } else if (rank > lowThreshold) {
        skillGapSeverity[skill] = 'Medium Gap';
      } else {
        skillGapSeverity[skill] = 'Low Gap';
      }
    }

    final skillMatchDistribution = SkillMatchDistribution(
      technicalMatched: technicalMatchCount,
      technicalTotal: technicalNormalized.length,
      softMatched: softMatchCount,
      softTotal: softNormalized.length,
    );

    final prioritySkills = missingSkills
        .where((s) => (skillPriorityRanking[s] ?? 0) >= _criticalPriorityThreshold)
        .toList();
    final missingMandatorySkills = missingSkills
        .where((s) => criticalNormalized.contains(normalize(s)))
        .toList();
    final mandatorySkills = requiredSkills
        .where((s) => criticalNormalized.contains(normalize(s)))
        .toList();
    // Same rule as level-based path: no critical skills configured → must match all.
    final isQualified = criticalNormalized.isEmpty
        ? missingSkills.isEmpty
        : missingMandatorySkills.isEmpty;

    return GapAnalysisResult(
      matchedSkills: matchedSkills,
      missingSkills: missingSkills,
      matchPercentage: matchPercentage,
      weightedMatchPercentage: weightedMatchPercentage,
      skillPriorityRanking: skillPriorityRanking,
      skillRecommendations: skillRecommendations,
      learningPath: learningPath,
      skillGapSeverity: skillGapSeverity,
      skillMatchDistribution: skillMatchDistribution,
      prioritySkills: prioritySkills,
      missingSkillsByPriority: List.from(missingSkills),
      isQualified: isQualified,
      missingMandatorySkills: missingMandatorySkills,
      mandatorySkills: mandatorySkills,
    );
  }
}
