import '../models/job_role.dart';
import '../models/skill.dart';
import '../utils/skill_utils.dart';

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
  });

  bool isHighPriority(String skillName) {
    final rank = skillPriorityRanking[skillName] ?? 0;
    return rank >= 1000;
  }
}

/// Service for gap analysis between user profile and job requirements. Skills only.
/// Uses level-based weighted scoring when job has [JobRequiredSkill] and skills catalog is provided.
class GapAnalysisService {
  /// Level-based skill score: min(userLevel / requiredLevel, 1). Same formula used in UI.
  static double skillScoreForLevel(int userLevel, int requiredLevel) {
    if (requiredLevel <= 0) return 1.0;
    final ratio = userLevel / requiredLevel;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  /// Weighted match score: sum(skillScore × importance) / sum(importance). Same formula used in UI.
  static double weightedMatchScore(
    List<double> skillScores,
    List<int> importances,
  ) {
    if (importances.isEmpty) return 0.0;
    double sumWeighted = 0.0;
    int sumImportance = 0;
    for (var i = 0; i < skillScores.length && i < importances.length; i++) {
      final w = importances[i].clamp(1, 3);
      sumWeighted += skillScores[i] * w;
      sumImportance += w;
    }
    return sumImportance > 0 ? sumWeighted / sumImportance : 0.0;
  }

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
        if (level > (result[us.skillId] ?? 0)) result[us.skillId] = level;
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
        if (str == 'advanced') {
          level = 95;
        } else if (str == 'intermediate')
          level = 65;
        else if (str == 'basic')
          level = 35;
        else
          level = (int.tryParse(str) ?? 35).clamp(0, 100);
      }
      if (skillsCatalog != null && skillsCatalog.isNotEmpty) {
        final n = normalizeSkillName(name);
        for (final skill in skillsCatalog.values) {
          if (normalizeSkillName(skill.name) == n) {
            if (level > (result[skill.id] ?? 0)) result[skill.id] = level;
            break;
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
  /// When [skillsCatalog] is provided and job has [requiredSkillsWithLevel], uses level-based weighted formula:
  /// skillScore = min(userLevel/requiredLevel, 1), matchScore = sum(skillScore×importance)/sum(importance).
  /// Otherwise uses legacy binary match.
  static Future<GapAnalysisResult> runGapAnalysis(
    Map<String, dynamic> userData,
    JobRole job, {
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
    Map<String, Skill>? skillsCatalog,
  }) async {
    if (job.requiredSkillsWithLevel.isNotEmpty &&
        skillsCatalog != null &&
        skillsCatalog.isNotEmpty) {
      return _runLevelBasedGapAnalysis(
        userData,
        job,
        skillsCatalog,
        fetchRecommendations,
      );
    }
    return _runLegacyGapAnalysis(userData, job, fetchRecommendations);
  }

  static Future<GapAnalysisResult> _runLevelBasedGapAnalysis(
    Map<String, dynamic> userData,
    JobRole job,
    Map<String, Skill> skillsCatalog,
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
  ) async {
    final userLevels = collectUserLevelsBySkillId(userData, skillsCatalog);
    final requiredList = job.requiredSkillsWithLevel;
    final skillScores = <double>[];
    final importances = <int>[];
    final matchedNames = <String>[];
    final missingWithMeta =
        <({String skillId, String name, int importance, double score})>[];

    for (final req in requiredList) {
      final skill = skillsCatalog[req.skillId];
      final name = skill?.name ?? req.skillId;
      final userLevel = userLevels[req.skillId] ?? 0;
      final score = skillScoreForLevel(userLevel, req.requiredLevel);
      final imp = req.importance.clamp(1, 3);
      skillScores.add(score);
      importances.add(imp);
      if (score >= 1.0) {
        matchedNames.add(name);
      } else {
        missingWithMeta.add((
          skillId: req.skillId,
          name: name,
          importance: imp,
          score: score,
        ));
      }
    }

    final matchScore = weightedMatchScore(skillScores, importances);
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
      final skill = skillsCatalog[req.skillId];
      final name = skill?.name ?? req.skillId;
      final imp = req.importance.clamp(1, 3);
      skillPriorityRanking[name] = imp * 500 + (requiredList.length - i);
    }

    Map<String, List<String>> skillRecommendations = {};
    if (fetchRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchRecommendations(missingSkills);
      } catch (_) {}
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
      skillGapSeverity[m.name] = m.importance >= 3
          ? 'High Gap'
          : (m.importance >= 2 ? 'Medium Gap' : 'Low Gap');
    }

    final technicalIds = skillsCatalog.values
        .where((s) => s.isTechnical)
        .map((s) => s.id)
        .toSet();
    int technicalMatched = 0,
        technicalTotal = 0,
        softMatched = 0,
        softTotal = 0;
    for (var i = 0; i < requiredList.length; i++) {
      final req = requiredList[i];
      final isTech = technicalIds.contains(req.skillId);
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
    );
  }

  static Future<GapAnalysisResult> _runLegacyGapAnalysis(
    Map<String, dynamic> userData,
    JobRole job,
    Future<Map<String, List<String>>> Function(List<String> missingSkillNames)?
    fetchRecommendations,
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

    int technicalMatchCount = technicalNormalized
        .where((s) => userSkillNormalized.contains(s))
        .length;
    int softMatchCount = softNormalized
        .where((s) => userSkillNormalized.contains(s))
        .length;

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
      if (userSkillNormalized.contains(n)) {
        matchedSkills.add(skill);
      } else {
        missingSkills.add(skill);
      }
    }
    missingSkills.sort(
      (a, b) => (skillPriorityRanking[b] ?? 0).compareTo(
        skillPriorityRanking[a] ?? 0,
      ),
    );

    // Match score = (matched skills / total required skills) * 100. Based on required job skills only; missing skills => score < 100%.
    final int requiredCount = requiredSkills.length;
    double matchPercentage = requiredCount > 0
        ? (matchedSkills.length / requiredCount) * 100
        : 0.0;
    double weightedMatchPercentage = matchPercentage;

    Map<String, List<String>> skillRecommendations = {};
    if (fetchRecommendations != null && missingSkills.isNotEmpty) {
      try {
        skillRecommendations = await fetchRecommendations(missingSkills);
      } catch (_) {}
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
    );
  }
}
