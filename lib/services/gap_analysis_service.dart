import '../models/course.dart';
import '../models/job_role.dart';
import '../models/skill.dart';
import '../utils/skill_utils.dart';
import 'package:flutter/foundation.dart';

import 'skills_analysis_service.dart';

/// One step in a learning path: a missing skill with priority and suggested resources.
class LearningStep {
  final int stepNumber;
  final String skillName;
  final int priority;
  final List<String> suggestedCourses;
  /// Courses with URLs (from `courses` collection); preferred over [suggestedCourses] for taps.
  final List<Course> suggestedCourseLinks;

  const LearningStep({
    required this.stepNumber,
    required this.skillName,
    required this.priority,
    required this.suggestedCourses,
    this.suggestedCourseLinks = const [],
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
  /// Same keys as [skillRecommendations]; full course rows for opening URLs in UI.
  final Map<String, List<Course>> skillCourseResources;

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
    this.skillCourseResources = const <String, List<Course>>{},
  });

  bool isHighPriority(String skillName) {
    final rank = skillPriorityRanking[skillName] ?? 0;
    return rank >= 1000;
  }
}

/// Service for gap analysis between user profile and job requirements. Skills only.
/// Uses level-based weighted scoring when job has [JobRequiredSkill] and skills catalog is provided.
class GapAnalysisService {
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
    return parts
        .map(
          (p) => p.length == 1
              ? p.toUpperCase()
              : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// Merges Firestore [skills] cache with synthetic [Skill] rows for every [JobRequiredSkill] so
  /// level-based analysis always runs when the job lists structured requirements, even if the
  /// catalog is empty or still loading.
  static Map<String, Skill> mergeJobRequiredSkillsCatalog(
    JobRole job,
    Map<String, Skill>? catalog,
  ) {
    final out = <String, Skill>{
      if (catalog != null) ...catalog,
    };
    final softIds = job.softSkillsWithLevel
        .map((s) => canonicalSkillId(s.name))
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final req in job.requiredSkillsWithLevel) {
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
    return job.requiredSkills
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Runs gap analysis (skills only). If [fetchRecommendations] is provided, uses it to load suggested courses per skill (e.g. from Firestore).
  /// When the job has [requiredSkillsWithLevel], uses level-based weighted formula:
  /// skillScore = min(userLevel/requiredLevel, 1), matchScore = sum(skillScore×importance)/sum(importance).
  /// [skillsCatalog] is merged with placeholder [Skill] rows for any required id missing from cache
  /// (see [mergeJobRequiredSkillsCatalog]) so analysis still runs if Firestore skills are empty.
  /// Otherwise uses legacy binary / tech-soft level match.
  static Future<GapAnalysisResult> runGapAnalysis(
    Map<String, dynamic> userData,
    JobRole job, {
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
    Future<Map<String, List<String>>> Function(
      List<String> missingSkillNames,
      Set<String> userSkillIds,
    )?
    fetchSmartRecommendations,
    Future<Map<String, List<Course>>> Function(List<String> missingSkillNames)?
    fetchCourseDetails,
    Map<String, Skill>? skillsCatalog,
  }) async {
    if (job.requiredSkillsWithLevel.isNotEmpty) {
      final merged = mergeJobRequiredSkillsCatalog(job, skillsCatalog);
      return _runLevelBasedGapAnalysis(
        userData,
        job,
        merged,
        fetchRecommendations,
        fetchSmartRecommendations,
        fetchCourseDetails,
      );
    }
    return _runLegacyGapAnalysis(
      userData,
      job,
      fetchRecommendations,
      fetchSmartRecommendations,
      fetchCourseDetails,
    );
  }

  static Future<GapAnalysisResult> _runLevelBasedGapAnalysis(
    Map<String, dynamic> userData,
    JobRole job,
    Map<String, Skill> skillsCatalog,
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
    Future<Map<String, List<String>>> Function(
      List<String> missingSkillNames,
      Set<String> userSkillIds,
    )?
    fetchSmartRecommendations,
    Future<Map<String, List<Course>>> Function(List<String> missingSkillNames)?
    fetchCourseDetails,
  ) async {
    final userLevels = collectUserLevelsBySkillId(userData, skillsCatalog);
    final requiredList = job.requiredSkillsWithLevel;
    final skillScores = <double>[];
    final weights = <int>[];
    final matchedNames = <String>[];
    final missingWithMeta =
        <({String skillId, String name, int importance, double score})>[];

    for (final req in requiredList) {
      final resolvedReqId =
          _resolveSkillIdFromCatalog(skillsCatalog, req.skillId) ?? req.skillId;
      final skill = _catalogSkill(skillsCatalog, resolvedReqId);
      final name = skill?.name ?? resolvedReqId;
      int userLevel = _userLevelFor(userLevels, resolvedReqId);
      if (userLevel == 0) {
        userLevel = _legacyUserLevelByName(userData, name);
      }
      final score = skillScoreForLevel(userLevel, req.requiredLevel);
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
        ));
      }
      if (kDebugMode) {
        debugPrint(
          '[GapMatch] req=${req.skillId} resolved=$resolvedReqId user=$userLevel required=${req.requiredLevel} score=${score.toStringAsFixed(2)}',
        );
      }
    }

    final matchScore = SkillsAnalysisService.weightedMatchRatio(
      skillScores,
      weights,
    );
    final matchPercentage = matchScore * 100;
    final weightedMatchPercentage = matchPercentage;

    // Sort missing by importance (high first), then by gap (low score first).
    missingWithMeta.sort((a, b) {
      final impCmp = b.importance.compareTo(a.importance);
      if (impCmp != 0) return impCmp;
      return a.score.compareTo(b.score);
    });
    final missingSkills = missingWithMeta.map((e) => e.name).toList();

    final skillPriorityRanking = <String, int>{};
    for (var i = 0; i < requiredList.length; i++) {
      final req = requiredList[i];
      final skill = _catalogSkill(skillsCatalog, req.skillId);
      final name = skill?.name ?? req.skillId;
      final imp = req.importance.clamp(1, 3);
      skillPriorityRanking[name] = imp * 500 + (requiredList.length - i);
    }

    Map<String, List<String>> skillRecommendations = {};
    final userSkillIds = userLevels.keys.map(canonicalSkillId).toSet();
    if (fetchSmartRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchSmartRecommendations(
          missingSkills,
          userSkillIds,
        );
      } catch (e) {
        debugPrint('Gap analysis smart recommendations error: $e');
      }
    } else if (fetchRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchRecommendations(missingSkills);
      } catch (e) {
        debugPrint('Gap analysis recommendations error: $e');
      }
    }

    Map<String, List<Course>> skillCourseResources = {};
    if (fetchCourseDetails != null && missingSkills.isNotEmpty) {
      try {
        skillCourseResources = await fetchCourseDetails(missingSkills);
      } catch (e) {
        debugPrint('Gap analysis course details error: $e');
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
          suggestedCourseLinks: skillCourseResources[m.name] ?? const [],
        ),
      );
    }

    final skillGapSeverity = <String, String>{};
    for (final m in missingWithMeta) {
      skillGapSeverity[m.name] = m.importance >= 3
          ? 'High Gap'
          : (m.importance >= 2 ? 'Medium Gap' : 'Low Gap');
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
        .where((m) => m.importance >= 3)
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
      skillCourseResources: skillCourseResources,
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
    Future<Map<String, List<Course>>> Function(List<String> missingSkillNames)?
    fetchCourseDetails,
  ) async {
    final user = collectAllUserSkillNames(userData);
    final requiredSkills = getRequiredSkillNames(job);
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
          ? 1000 + orderPriority
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
        weights.add(criticalNormalized.contains(n) ? 10 : 5);
      }
      final m = weightedMatchScore(scores, weights);
      matchPercentage = m * 100;
      weightedMatchPercentage = matchPercentage;
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
      } catch (e) {
        debugPrint('Gap analysis smart recommendations error: $e');
      }
    } else if (fetchRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchRecommendations(missingSkills);
      } catch (e) {
        debugPrint('Gap analysis recommendations error: $e');
      }
    }

    Map<String, List<Course>> skillCourseResources = {};
    if (fetchCourseDetails != null && missingSkills.isNotEmpty) {
      try {
        skillCourseResources = await fetchCourseDetails(missingSkills);
      } catch (e) {
        debugPrint('Gap analysis course details error: $e');
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
          suggestedCourseLinks: skillCourseResources[skill] ?? const [],
        ),
      );
    }

    final nonCriticalRanks =
        requiredSkills
            .where((s) => (skillPriorityRanking[s] ?? 0) < 1000)
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
      if (rank >= 1000) {
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
        .where((s) => (skillPriorityRanking[s] ?? 0) >= 1000)
        .toList();

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
      skillCourseResources: skillCourseResources,
    );
  }
}
