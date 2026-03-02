/// Skill with required proficiency level (0-100).
class SkillProficiency {
  final String name;
  final int percent;

  const SkillProficiency({required this.name, required this.percent});

  Map<String, dynamic> toFirestore() => {'name': name, 'percent': percent};

  static SkillProficiency fromFirestore(Map<String, dynamic> data) {
    return SkillProficiency(
      name: data['name']?.toString() ?? '',
      percent: (data['percent'] is int) ? data['percent'] as int : int.tryParse(data['percent']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Model for a job role with required skills, courses, and salary.
class JobRole {
  final String id;
  final String title;
  final String description;
  final String category;
  final bool isHighDemand;
  final int salaryMinK;
  final int salaryMaxK;
  final List<String> requiredSkills;
  final List<String> requiredCourses;
  /// Technical skills with required proficiency % (for Job Requirements screen).
  final List<SkillProficiency> technicalSkillsWithLevel;
  /// Soft skills with required proficiency %.
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
    required this.requiredCourses,
    this.technicalSkillsWithLevel = const [],
    this.softSkillsWithLevel = const [],
    this.criticalSkills = const [],
  });

  int get requiredSkillsCount => requiredSkills.length;
  int get requiredCoursesCount => requiredCourses.length;
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
      'requiredSkills': requiredSkills,
      'requiredCourses': requiredCourses,
      'technicalSkillsWithLevel': technicalSkillsWithLevel.map((s) => s.toFirestore()).toList(),
      'softSkillsWithLevel': softSkillsWithLevel.map((s) => s.toFirestore()).toList(),
      'criticalSkills': criticalSkills,
    };
  }

  static JobRole fromFirestore(String id, Map<String, dynamic> data) {
    final techList = data['technicalSkillsWithLevel'] as List<dynamic>?;
    final softList = data['softSkillsWithLevel'] as List<dynamic>?;
    return JobRole(
      id: id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      isHighDemand: data['isHighDemand'] == true,
      salaryMinK: (data['salaryMinK'] is int) ? data['salaryMinK'] as int : int.tryParse(data['salaryMinK']?.toString() ?? '0') ?? 0,
      salaryMaxK: (data['salaryMaxK'] is int) ? data['salaryMaxK'] as int : int.tryParse(data['salaryMaxK']?.toString() ?? '0') ?? 0,
      requiredSkills: List<String>.from(data['requiredSkills'] ?? []),
      requiredCourses: List<String>.from(data['requiredCourses'] ?? []),
      technicalSkillsWithLevel: techList?.map((e) => SkillProficiency.fromFirestore(Map<String, dynamic>.from(e as Map))).toList() ?? [],
      softSkillsWithLevel: softList?.map((e) => SkillProficiency.fromFirestore(Map<String, dynamic>.from(e as Map))).toList() ?? [],
      criticalSkills: List<String>.from(data['criticalSkills'] ?? []),
    );
  }
}
