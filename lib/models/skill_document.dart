/// Phase 1: Centralized skills database – Firestore document structure only.
/// Do not use for UI in Phase 1. Existing [Skill] in skill.dart remains unchanged.

import 'package:cloud_firestore/cloud_firestore.dart';

// --- Nested types for skills collection ---

class SkillUsedInJob {
  final String jobId;
  final String jobTitle;
  final int requiredLevel;
  final String priority;
  final int weight;

  const SkillUsedInJob({
    required this.jobId,
    required this.jobTitle,
    required this.requiredLevel,
    required this.priority,
    required this.weight,
  });

  Map<String, dynamic> toFirestore() => {
        'jobId': jobId,
        'jobTitle': jobTitle,
        'requiredLevel': requiredLevel,
        'priority': priority,
        'weight': weight,
      };

  static SkillUsedInJob? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    return SkillUsedInJob(
      jobId: data['jobId'] as String? ?? '',
      jobTitle: data['jobTitle'] as String? ?? '',
      requiredLevel: (data['requiredLevel'] as num?)?.toInt() ?? 0,
      priority: data['priority'] as String? ?? 'Important',
      weight: (data['weight'] as num?)?.toInt() ?? 5,
    );
  }
}

class SkillCourse {
  final String courseId;
  final String title;
  final String platform;
  final String url;
  final double rating;
  final String level;
  final bool isPrimary;

  const SkillCourse({
    required this.courseId,
    required this.title,
    required this.platform,
    required this.url,
    required this.rating,
    required this.level,
    this.isPrimary = false,
  });

  Map<String, dynamic> toFirestore() => {
        'courseId': courseId,
        'title': title,
        'platform': platform,
        'url': url,
        'rating': rating,
        'level': level,
        'isPrimary': isPrimary,
      };

  static SkillCourse? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    return SkillCourse(
      courseId: data['courseId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      platform: data['platform'] as String? ?? '',
      url: data['url'] as String? ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      level: data['level'] as String? ?? 'Beginner',
      isPrimary: data['isPrimary'] as bool? ?? false,
    );
  }
}

class SkillCertification {
  final String certId;
  final String name;
  final String provider;
  final String url;
  final String cost;
  final int validityYears;
  final String difficulty;

  const SkillCertification({
    required this.certId,
    required this.name,
    required this.provider,
    required this.url,
    required this.cost,
    required this.validityYears,
    required this.difficulty,
  });

  Map<String, dynamic> toFirestore() => {
        'certId': certId,
        'name': name,
        'provider': provider,
        'url': url,
        'cost': cost,
        'validityYears': validityYears,
        'difficulty': difficulty,
      };

  static SkillCertification? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    return SkillCertification(
      certId: data['certId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      provider: data['provider'] as String? ?? '',
      url: data['url'] as String? ?? '',
      cost: data['cost'] as String? ?? '',
      validityYears: (data['validityYears'] as num?)?.toInt() ?? 0,
      difficulty: data['difficulty'] as String? ?? 'Intermediate',
    );
  }
}

class SkillLearningResource {
  final String type;
  final String title;
  final String url;
  final String source;
  final bool isFree;

  const SkillLearningResource({
    required this.type,
    required this.title,
    required this.url,
    required this.source,
    this.isFree = true,
  });

  Map<String, dynamic> toFirestore() => {
        'type': type,
        'title': title,
        'url': url,
        'source': source,
        'isFree': isFree,
      };

  static SkillLearningResource? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    return SkillLearningResource(
      type: data['type'] as String? ?? 'Article',
      title: data['title'] as String? ?? '',
      url: data['url'] as String? ?? '',
      source: data['source'] as String? ?? '',
      isFree: data['isFree'] as bool? ?? true,
    );
  }
}

class SkillPracticeProject {
  final String title;
  final String description;
  final String difficulty;
  final int estimatedHours;
  final String? githubUrl;
  final String? tutorialUrl;

  const SkillPracticeProject({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedHours,
    this.githubUrl,
    this.tutorialUrl,
  });

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'description': description,
        'difficulty': difficulty,
        'estimatedHours': estimatedHours,
        if (githubUrl != null && githubUrl!.isNotEmpty) 'githubUrl': githubUrl,
        if (tutorialUrl != null && tutorialUrl!.isNotEmpty) 'tutorialUrl': tutorialUrl,
      };

  static SkillPracticeProject? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    return SkillPracticeProject(
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      difficulty: data['difficulty'] as String? ?? 'Beginner',
      estimatedHours: (data['estimatedHours'] as num?)?.toInt() ?? 0,
      githubUrl: data['githubUrl'] as String?,
      tutorialUrl: data['tutorialUrl'] as String?,
    );
  }
}

/// Time-to-learn per level (e.g. "2 weeks", "3 months").
class AverageTimeToLearn {
  final String beginner;
  final String intermediate;
  final String advanced;

  const AverageTimeToLearn({
    required this.beginner,
    required this.intermediate,
    required this.advanced,
  });

  Map<String, dynamic> toFirestore() => {
        'beginner': beginner,
        'intermediate': intermediate,
        'advanced': advanced,
      };

  static AverageTimeToLearn? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    return AverageTimeToLearn(
      beginner: data['beginner'] as String? ?? '',
      intermediate: data['intermediate'] as String? ?? '',
      advanced: data['advanced'] as String? ?? '',
    );
  }
}

/// Full skill document for Firestore collection "skills" (Phase 1 structure).
class SkillDocument {
  final String skillId;
  final String skillName;
  final List<String> aliases;
  final String type; // Technical / Soft / Tool
  final String category;
  final String subCategory;
  final String description;
  final String? difficultyLevel;
  final String? learningCurve;
  final AverageTimeToLearn? averageTimeToLearn;
  final List<String> prerequisites;
  final List<String> relatedSkills;
  final List<String> advancedSkills;
  final String? demandLevel;
  final bool? trending;
  final String? growthRate;
  final String? averageSalaryImpact;
  final List<SkillUsedInJob> usedInJobs;
  final List<SkillCourse> courses;
  final List<SkillCertification> certifications;
  final List<SkillLearningResource> learningResources;
  final List<SkillPracticeProject> practiceProjects;
  final int totalJobsUsingSkill;
  final double averageRequiredLevel;
  final String? mostCommonPriority;
  final String? icon;
  final String? color;
  final bool isActive;
  final String? replacedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SkillDocument({
    required this.skillId,
    required this.skillName,
    this.aliases = const [],
    required this.type,
    this.category = '',
    this.subCategory = '',
    this.description = '',
    this.difficultyLevel,
    this.learningCurve,
    this.averageTimeToLearn,
    this.prerequisites = const [],
    this.relatedSkills = const [],
    this.advancedSkills = const [],
    this.demandLevel,
    this.trending,
    this.growthRate,
    this.averageSalaryImpact,
    this.usedInJobs = const [],
    this.courses = const [],
    this.certifications = const [],
    this.learningResources = const [],
    this.practiceProjects = const [],
    this.totalJobsUsingSkill = 0,
    this.averageRequiredLevel = 0,
    this.mostCommonPriority,
    this.icon,
    this.color,
    this.isActive = true,
    this.replacedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Serialize to Firestore. Includes 'name' and 'category' for backward compatibility with existing Skill.fromFirestore.
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'skillId': skillId,
      'skillName': skillName,
      'name': skillName,
      'aliases': aliases,
      'type': type,
      'category': category,
      'subCategory': subCategory,
      'description': description,
      'prerequisites': prerequisites,
      'relatedSkills': relatedSkills,
      'advancedSkills': advancedSkills,
      'usedInJobs': usedInJobs.map((e) => e.toFirestore()).toList(),
      'courses': courses.map((e) => e.toFirestore()).toList(),
      'certifications': certifications.map((e) => e.toFirestore()).toList(),
      'learningResources': learningResources.map((e) => e.toFirestore()).toList(),
      'practiceProjects': practiceProjects.map((e) => e.toFirestore()).toList(),
      'totalJobsUsingSkill': totalJobsUsingSkill,
      'averageRequiredLevel': averageRequiredLevel,
      'isActive': isActive,
    };
    if (difficultyLevel != null) map['difficultyLevel'] = difficultyLevel;
    if (learningCurve != null) map['learningCurve'] = learningCurve;
    if (averageTimeToLearn != null) map['averageTimeToLearn'] = averageTimeToLearn!.toFirestore();
    if (demandLevel != null) map['demandLevel'] = demandLevel;
    if (trending != null) map['trending'] = trending;
    if (growthRate != null) map['growthRate'] = growthRate;
    if (averageSalaryImpact != null) map['averageSalaryImpact'] = averageSalaryImpact;
    if (mostCommonPriority != null) map['mostCommonPriority'] = mostCommonPriority;
    if (icon != null) map['icon'] = icon;
    if (color != null) map['color'] = color;
    if (replacedBy != null) map['replacedBy'] = replacedBy;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    return map;
  }

  /// Parse from Firestore document data.
  static SkillDocument? fromFirestore(Map<String, dynamic>? data, [String? docId]) {
    if (data == null) return null;
    final id = docId ?? data['skillId'] as String? ?? '';
    final usedInJobsRaw = data['usedInJobs'] as List?;
    final coursesRaw = data['courses'] as List?;
    final certsRaw = data['certifications'] as List?;
    final resourcesRaw = data['learningResources'] as List?;
    final projectsRaw = data['practiceProjects'] as List?;
    final aliasesRaw = data['aliases'];
    final prereqRaw = data['prerequisites'];
    final relatedRaw = data['relatedSkills'];
    final advancedRaw = data['advancedSkills'];

    return SkillDocument(
      skillId: id,
      skillName: data['skillName'] as String? ?? data['name'] as String? ?? '',
      aliases: aliasesRaw is List ? (aliasesRaw).map((e) => e.toString()).toList() : const [],
      type: data['type'] as String? ?? 'Technical',
      category: data['category'] as String? ?? '',
      subCategory: data['subCategory'] as String? ?? '',
      description: data['description'] as String? ?? '',
      difficultyLevel: data['difficultyLevel'] as String?,
      learningCurve: data['learningCurve'] as String?,
      averageTimeToLearn: AverageTimeToLearn.fromFirestore(data['averageTimeToLearn'] is Map ? data['averageTimeToLearn'] as Map<String, dynamic> : null),
      prerequisites: prereqRaw is List ? (prereqRaw).map((e) => e.toString()).toList() : const [],
      relatedSkills: relatedRaw is List ? (relatedRaw).map((e) => e.toString()).toList() : const [],
      advancedSkills: advancedRaw is List ? (advancedRaw).map((e) => e.toString()).toList() : const [],
      demandLevel: data['demandLevel'] as String?,
      trending: data['trending'] as bool?,
      growthRate: data['growthRate'] as String?,
      averageSalaryImpact: data['averageSalaryImpact'] as String?,
      usedInJobs: usedInJobsRaw != null
          ? usedInJobsRaw.map((e) => SkillUsedInJob.fromFirestore(e is Map ? e as Map<String, dynamic> : null)).whereType<SkillUsedInJob>().toList()
          : const [],
      courses: coursesRaw != null
          ? coursesRaw.map((e) => SkillCourse.fromFirestore(e is Map ? e as Map<String, dynamic> : null)).whereType<SkillCourse>().toList()
          : const [],
      certifications: certsRaw != null
          ? certsRaw.map((e) => SkillCertification.fromFirestore(e is Map ? e as Map<String, dynamic> : null)).whereType<SkillCertification>().toList()
          : const [],
      learningResources: resourcesRaw != null
          ? resourcesRaw.map((e) => SkillLearningResource.fromFirestore(e is Map ? e as Map<String, dynamic> : null)).whereType<SkillLearningResource>().toList()
          : const [],
      practiceProjects: projectsRaw != null
          ? projectsRaw.map((e) => SkillPracticeProject.fromFirestore(e is Map ? e as Map<String, dynamic> : null)).whereType<SkillPracticeProject>().toList()
          : const [],
      totalJobsUsingSkill: (data['totalJobsUsingSkill'] as num?)?.toInt() ?? 0,
      averageRequiredLevel: (data['averageRequiredLevel'] as num?)?.toDouble() ?? 0,
      mostCommonPriority: data['mostCommonPriority'] as String?,
      icon: data['icon'] as String?,
      color: data['color'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      replacedBy: data['replacedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
