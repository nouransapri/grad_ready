import 'package:cloud_firestore/cloud_firestore.dart';

import 'job_role.dart';
import 'skill.dart';
import '../utils/skill_utils.dart';

/// Single skill/tool entry in a job (technical, soft, or tool).
class JobSkillItem {
  final String skillId; // reference to /skills/{skillId}
  final String name;
  final int requiredLevel; // 0-100
  final String priority; // Critical | Important | Nice-to-Have
  final int weight; // 1-10
  final String category; // for technical: Programming, Framework, Database, etc.

  const JobSkillItem({
    this.skillId = '',
    required this.name,
    required this.requiredLevel,
    required this.priority,
    required this.weight,
    this.category = '',
  });

  Map<String, dynamic> toFirestore() => {
        'skillId': skillId.trim().isNotEmpty ? skillId.trim() : skillNameToSkillId(name),
        'name': name,
        'requiredLevel': requiredLevel.clamp(0, 100),
        'priority': priority,
        'weight': weight.clamp(1, 10),
        'category': category,
      };

  static JobSkillItem? fromFirestore(dynamic e) {
    if (e is! Map) return null;
    final m = Map<String, dynamic>.from(
      e.map((k, v) => MapEntry(k.toString(), v)),
    );
    final name = m['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    final skillId = m['skillId']?.toString().trim() ?? '';
    return JobSkillItem(
      skillId: skillId.isNotEmpty ? skillId : skillNameToSkillId(name),
      name: name,
      requiredLevel: (m['requiredLevel'] is int)
          ? (m['requiredLevel'] as int).clamp(0, 100)
          : (int.tryParse(m['requiredLevel']?.toString() ?? '50') ?? 50).clamp(0, 100),
      priority: _parsePriority(m['priority']),
      weight: (m['weight'] is int)
          ? (m['weight'] as int).clamp(1, 10)
          : (int.tryParse(m['weight']?.toString() ?? '5') ?? 5).clamp(1, 10),
      category: m['category']?.toString().trim() ?? '',
    );
  }

  static String _parsePriority(dynamic v) {
    final s = v?.toString().trim() ?? '';
    if (s.toLowerCase() == 'critical') return 'Critical';
    if (s.toLowerCase() == 'important') return 'Important';
    if (s.toLowerCase() == 'nice-to-have') return 'Nice-to-Have';
    return s.isNotEmpty ? s : 'Important';
  }
}

/// Certification entry.
class CertificationItem {
  final String name;
  final bool required;
  final List<String> alternatives;

  const CertificationItem({
    required this.name,
    this.required = false,
    this.alternatives = const [],
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'required': required,
        'alternatives': alternatives,
      };

  static CertificationItem? fromFirestore(dynamic e) {
    if (e is! Map) return null;
    final m = Map<String, dynamic>.from(
      e.map((k, v) => MapEntry(k.toString(), v)),
    );
    final name = m['name']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    final alt = m['alternatives'];
    final list = alt is List
        ? alt.map((x) => x?.toString().trim()).where((x) => x != null && x.isNotEmpty).cast<String>().toList()
        : <String>[];
    return CertificationItem(
      name: name,
      required: m['required'] == true,
      alternatives: list,
    );
  }
}

/// Education requirement.
class EducationRequirement {
  final String minimumDegree; // Bachelor, Master, PhD, Diploma, None
  final List<String> preferredMajors;
  final bool experienceReplacesDegree;

  const EducationRequirement({
    this.minimumDegree = 'Bachelor',
    this.preferredMajors = const [],
    this.experienceReplacesDegree = false,
  });

  Map<String, dynamic> toFirestore() => {
        'minimumDegree': minimumDegree,
        'preferredMajors': preferredMajors,
        'experienceReplacesDegree': experienceReplacesDegree,
        'experienceCanReplaceDegree': experienceReplacesDegree,
      };

  static EducationRequirement fromFirestore(Map<String, dynamic>? m) {
    if (m == null) return const EducationRequirement();
    final majors = m['preferredMajors'];
    final replace = m['experienceCanReplaceDegree'] ?? m['experienceReplacesDegree'];
    return EducationRequirement(
      minimumDegree: m['minimumDegree']?.toString().trim() ?? 'Bachelor',
      preferredMajors: majors is List
          ? majors.map((x) => x?.toString().trim()).where((x) => x != null && x.isNotEmpty).cast<String>().toList()
          : [],
      experienceReplacesDegree: replace == true,
    );
  }
}

/// Experience requirement.
class ExperienceRequirement {
  final int minimumYears;
  final int preferredYears;
  final List<String> relevantDomains;

  const ExperienceRequirement({
    this.minimumYears = 0,
    this.preferredYears = 0,
    this.relevantDomains = const [],
  });

  Map<String, dynamic> toFirestore() => {
        'minimumYears': minimumYears,
        'preferredYears': preferredYears,
        'relevantDomains': relevantDomains,
      };

  static ExperienceRequirement fromFirestore(Map<String, dynamic>? m) {
    if (m == null) return const ExperienceRequirement();
    final domains = m['relevantDomains'];
    return ExperienceRequirement(
      minimumYears: (m['minimumYears'] is int)
          ? (m['minimumYears'] as int).clamp(0, 50)
          : (int.tryParse(m['minimumYears']?.toString() ?? '0') ?? 0).clamp(0, 50),
      preferredYears: (m['preferredYears'] is int)
          ? (m['preferredYears'] as int).clamp(0, 50)
          : (int.tryParse(m['preferredYears']?.toString() ?? '0') ?? 0).clamp(0, 50),
      relevantDomains: domains is List
          ? domains.map((x) => x?.toString().trim()).where((x) => x != null && x.isNotEmpty).cast<String>().toList()
          : [],
    );
  }
}

/// Salary info.
class SalaryInfo {
  final String currency;
  final int minimum;
  final int maximum;
  final String period; // Yearly, Monthly, Hourly

  const SalaryInfo({
    this.currency = 'USD',
    this.minimum = 0,
    this.maximum = 0,
    this.period = 'Yearly',
  });

  Map<String, dynamic> toFirestore() => {
        'currency': currency,
        'minimum': minimum,
        'maximum': maximum,
        'period': period,
      };

  static SalaryInfo fromFirestore(Map<String, dynamic>? m) {
    if (m == null) return const SalaryInfo();
    return SalaryInfo(
      currency: m['currency']?.toString().trim() ?? 'USD',
      minimum: (m['minimum'] is int) ? m['minimum'] as int : (int.tryParse(m['minimum']?.toString() ?? '0') ?? 0),
      maximum: (m['maximum'] is int) ? m['maximum'] as int : (int.tryParse(m['maximum']?.toString() ?? '0') ?? 0),
      period: m['period']?.toString().trim() ?? 'Yearly',
    );
  }
}

/// Full job document as stored in Firestore (comprehensive structure).
class JobDocument {
  final String id;
  final String jobId; // unique slug e.g. "frontend-dev-001"
  final String title;
  final String category;
  final String industry;
  final String experienceLevel; // Entry Level, Junior, Mid-Level, Senior, Lead
  final String description;
  final List<JobSkillItem> technicalSkills;
  final List<JobSkillItem> softSkills;
  final List<JobSkillItem> tools;
  final List<CertificationItem> certifications;
  final EducationRequirement education;
  final ExperienceRequirement experience;
  final SalaryInfo salary;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final int totalSkillsCount;
  final double averageRequiredLevel;

  const JobDocument({
    required this.id,
    required this.jobId,
    required this.title,
    required this.category,
    this.industry = '',
    this.experienceLevel = 'Mid-Level',
    required this.description,
    this.technicalSkills = const [],
    this.softSkills = const [],
    this.tools = const [],
    this.certifications = const [],
    this.education = const EducationRequirement(),
    this.experience = const ExperienceRequirement(),
    this.salary = const SalaryInfo(),
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.totalSkillsCount = 0,
    this.averageRequiredLevel = 0,
  });

  /// Converts to legacy JobRole for gap analysis and existing UI.
  JobRole toJobRole() {
    final allSkills = <JobRequiredSkill>[];
    final criticalNames = <String>[];
    for (final s in technicalSkills) {
      allSkills.add(JobRequiredSkill(
        skillId: s.skillId.trim().isNotEmpty ? s.skillId.trim() : skillNameToSkillId(s.name),
        requiredLevel: s.requiredLevel,
        importance: _weightToImportance(s.weight),
        weight: s.weight.clamp(1, 10),
      ));
      if (s.priority == 'Critical') criticalNames.add(s.name);
    }
    for (final s in softSkills) {
      allSkills.add(JobRequiredSkill(
        skillId: s.skillId.trim().isNotEmpty ? s.skillId.trim() : skillNameToSkillId(s.name),
        requiredLevel: s.requiredLevel,
        importance: _weightToImportance(s.weight),
        weight: s.weight.clamp(1, 10),
      ));
      if (s.priority == 'Critical') criticalNames.add(s.name);
    }
    for (final s in tools) {
      allSkills.add(JobRequiredSkill(
        skillId: s.skillId.trim().isNotEmpty ? s.skillId.trim() : skillNameToSkillId(s.name),
        requiredLevel: s.requiredLevel,
        importance: _weightToImportance(s.weight),
        weight: s.weight.clamp(1, 10),
      ));
      if (s.priority == 'Critical') criticalNames.add(s.name);
    }
    final salaryMinK = salary.maximum > 0 ? (salary.minimum / 1000).round() : 0;
    final salaryMaxK = salary.maximum > 0 ? (salary.maximum / 1000).round() : 0;
    final techWithLevel = technicalSkills
        .map((s) => SkillProficiency(name: s.name, percent: s.requiredLevel))
        .toList();
    final softWithLevel = softSkills
        .map((s) => SkillProficiency(name: s.name, percent: s.requiredLevel))
        .toList();
    return JobRole(
      id: id,
      title: title,
      description: description,
      category: category,
      isHighDemand: isActive,
      salaryMinK: salaryMinK,
      salaryMaxK: salaryMaxK,
      requiredSkills: allSkills.map((r) => r.skillId).toList(),
      requiredSkillsWithLevel: allSkills,
      technicalSkillsWithLevel: techWithLevel,
      softSkillsWithLevel: softWithLevel,
      criticalSkills: criticalNames,
    );
  }

  static int _weightToImportance(int weight) {
    if (weight >= 8) return 3;
    if (weight >= 4) return 2;
    return 1;
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'jobId': jobId,
      'title': title,
      'category': category,
      'industry': industry,
      'experienceLevel': experienceLevel,
      'description': description,
      'technicalSkills': technicalSkills.map((s) => s.toFirestore()).toList(),
      'softSkills': softSkills.map((s) => s.toFirestore()).toList(),
      'tools': tools.map((s) => s.toFirestore()).toList(),
      'certifications': certifications.map((c) => c.toFirestore()).toList(),
      'education': education.toFirestore(),
      'experience': experience.toFirestore(),
      'salary': salary.toFirestore(),
      'isActive': isActive,
      'totalSkillsCount': totalSkillsCount,
      'averageRequiredLevel': averageRequiredLevel,
    };
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    return map;
  }

  static JobDocument fromFirestore(String id, Map<String, dynamic> data) {
    final techRaw = data['technicalSkills'] as List<dynamic>?;
    final softRaw = data['softSkills'] as List<dynamic>?;
    final toolsRaw = data['tools'] as List<dynamic>?;
    final certRaw = data['certifications'] as List<dynamic>?;
    final technicalSkills = techRaw
            ?.map((e) => JobSkillItem.fromFirestore(e))
            .whereType<JobSkillItem>()
            .toList() ??
        [];
    final softSkills = softRaw
            ?.map((e) => JobSkillItem.fromFirestore(e))
            .whereType<JobSkillItem>()
            .toList() ??
        [];
    final tools = toolsRaw
            ?.map((e) => JobSkillItem.fromFirestore(e))
            .whereType<JobSkillItem>()
            .toList() ??
        [];
    final certifications = certRaw
            ?.map((e) => CertificationItem.fromFirestore(e))
            .whereType<CertificationItem>()
            .toList() ??
        [];
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    return JobDocument(
      id: id,
      jobId: data['jobId']?.toString().trim() ?? id,
      title: data['title']?.toString().trim() ?? '',
      category: data['category']?.toString().trim() ?? '',
      industry: data['industry']?.toString().trim() ?? '',
      experienceLevel: data['experienceLevel']?.toString().trim() ?? 'Mid-Level',
      description: data['description']?.toString().trim() ?? '',
      technicalSkills: technicalSkills,
      softSkills: softSkills,
      tools: tools,
      certifications: certifications,
      education: EducationRequirement.fromFirestore(
        data['education'] is Map ? Map<String, dynamic>.from(data['education']) : null,
      ),
      experience: ExperienceRequirement.fromFirestore(
        data['experience'] is Map ? Map<String, dynamic>.from(data['experience']) : null,
      ),
      salary: SalaryInfo.fromFirestore(
        data['salary'] is Map ? Map<String, dynamic>.from(data['salary']) : null,
      ),
      createdAt: created is Timestamp ? created.toDate() : null,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
      isActive: data['isActive'] != false,
      totalSkillsCount: (data['totalSkillsCount'] is int)
          ? data['totalSkillsCount'] as int
          : (technicalSkills.length + softSkills.length + tools.length),
      averageRequiredLevel: (data['averageRequiredLevel'] is num)
          ? (data['averageRequiredLevel'] as num).toDouble()
          : _calcAvgLevel(technicalSkills, softSkills, tools),
    );
  }

  static double _calcAvgLevel(
    List<JobSkillItem> tech,
    List<JobSkillItem> soft,
    List<JobSkillItem> tools,
  ) {
    final all = [...tech, ...soft, ...tools];
    if (all.isEmpty) return 0;
    final sum = all.fold<int>(0, (a, s) => a + s.requiredLevel);
    return sum / all.length;
  }

  /// Returns whether this document uses the new comprehensive structure.
  static bool isNewFormat(Map<String, dynamic> data) {
    return data['technicalSkills'] is List && data['title'] != null;
  }
}
