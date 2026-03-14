import 'skill.dart';

/// Skill with required proficiency level (0-100). Legacy structure for technical/soft lists.
class SkillProficiency {
  final String name;
  final int percent;

  const SkillProficiency({required this.name, required this.percent});

  Map<String, dynamic> toFirestore() => {'name': name, 'percent': percent};

  static SkillProficiency fromFirestore(Map<String, dynamic> data) {
    return SkillProficiency(
      name: data['name']?.toString() ?? '',
      percent: (data['percent'] is int)
          ? data['percent'] as int
          : int.tryParse(data['percent']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Model for a job role with required skills and salary. Course-related fields removed.
class JobRole {
  final String id;
  final String title;
  final String description;
  final String category;
  final bool isHighDemand;
  final int salaryMinK;
  final int salaryMaxK;

  /// Legacy: list of skill names. Used when [requiredSkillsWithLevel] is empty.
  final List<String> requiredSkills;

  /// New: skillId + requiredLevel + importance (1–3). When non-empty, used for level-based weighted match.
  final List<JobRequiredSkill> requiredSkillsWithLevel;

  /// Technical skills with required proficiency % (for Job Requirements screen). Legacy.
  final List<SkillProficiency> technicalSkillsWithLevel;

  /// Soft skills with required proficiency %. Legacy.
  final List<SkillProficiency> softSkillsWithLevel;

  /// Critical/high-priority skill names for the orange tags section.
  final List<String> criticalSkills;

  const JobRole({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.isHighDemand = true,
    required this.salaryMinK,
    required this.salaryMaxK,
    required this.requiredSkills,
    this.requiredSkillsWithLevel = const [],
    this.technicalSkillsWithLevel = const [],
    this.softSkillsWithLevel = const [],
    this.criticalSkills = const [],
  });

  int get requiredSkillsCount => requiredSkillsWithLevel.isNotEmpty
      ? requiredSkillsWithLevel.length
      : requiredSkills.length;
  String get salaryRange => '\$${salaryMinK}K - \$${salaryMaxK}K /year';
  String get salaryRangeShort => '\$${salaryMinK}K - \$${salaryMaxK}K';

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'isHighDemand': isHighDemand,
      'salaryMinK': salaryMinK,
      'salaryMaxK': salaryMaxK,
      'requiredSkills': requiredSkillsWithLevel.isNotEmpty
          ? requiredSkillsWithLevel.map((s) => s.toFirestore()).toList()
          : requiredSkills,
      'technicalSkillsWithLevel': technicalSkillsWithLevel
          .map((s) => s.toFirestore())
          .toList(),
      'softSkillsWithLevel': softSkillsWithLevel
          .map((s) => s.toFirestore())
          .toList(),
      'criticalSkills': criticalSkills,
    };
  }

  static JobRole fromFirestore(String id, Map<String, dynamic> data) {
    final techList = data['technicalSkillsWithLevel'] as List<dynamic>?;
    final softList = data['softSkillsWithLevel'] as List<dynamic>?;
    final rawRequired = data['requiredSkills'];
    List<String> legacyRequired = [];
    List<JobRequiredSkill> detailed = [];
    if (rawRequired is List && rawRequired.isNotEmpty) {
      final first = rawRequired.first;
      if (first is Map && first.containsKey('skillId')) {
        for (final e in rawRequired) {
          final rs = JobRequiredSkill.fromFirestore(e);
          if (rs != null) detailed.add(rs);
        }
      } else {
        legacyRequired = rawRequired
            .map((e) => e?.toString().trim())
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList();
      }
    }
    return JobRole(
      id: id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      isHighDemand: data['isHighDemand'] == true,
      salaryMinK: (data['salaryMinK'] is int)
          ? data['salaryMinK'] as int
          : int.tryParse(data['salaryMinK']?.toString() ?? '0') ?? 0,
      salaryMaxK: (data['salaryMaxK'] is int)
          ? data['salaryMaxK'] as int
          : int.tryParse(data['salaryMaxK']?.toString() ?? '0') ?? 0,
      requiredSkills: legacyRequired,
      requiredSkillsWithLevel: detailed,
      technicalSkillsWithLevel:
          techList
              ?.map(
                (e) => SkillProficiency.fromFirestore(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
      softSkillsWithLevel:
          softList
              ?.map(
                (e) => SkillProficiency.fromFirestore(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
      criticalSkills: List<String>.from(data['criticalSkills'] ?? []),
    );
  }
}
