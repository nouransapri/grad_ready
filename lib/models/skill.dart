/// Master skill from Firestore collection `skills`. Used for canonical id, name, and category.
class Skill {
  final String id;
  final String name;
  final String category;
  final List<String> aliases;
  final bool isVerified;
  final List<String> relatedSkills;
  final String domain;
  final String demandLevel;
  final int totalJobsUsingSkill;

  const Skill({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const [],
    this.isVerified = true,
    this.relatedSkills = const [],
    this.domain = '',
    this.demandLevel = 'Medium',
    this.totalJobsUsingSkill = 0,
  });

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'category': category,
    'aliases': aliases,
    'isVerified': isVerified,
    'relatedSkills': relatedSkills,
    'domain': domain,
    'demandLevel': demandLevel,
    'totalJobsUsingSkill': totalJobsUsingSkill,
  };

  static Skill fromFirestore(String id, Map<String, dynamic> data) {
    final aliases = (data['aliases'] as List?)
        ?.map((e) => e?.toString().trim())
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList() ??
        const <String>[];
    final relatedSkills = (data['relatedSkills'] as List?)
        ?.map((e) => e?.toString().trim())
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toList() ??
        const <String>[];
    return Skill(
      id: id,
      name: data['name']?.toString().trim() ??
          data['skillName']?.toString().trim() ??
          '',
      category: data['category']?.toString().trim() ??
          data['type']?.toString().trim() ??
          'Technical',
      aliases: aliases,
      isVerified: data['isVerified'] != false,
      relatedSkills: relatedSkills,
      domain: data['domain']?.toString().trim() ?? '',
      demandLevel: data['demandLevel']?.toString().trim() ?? 'Medium',
      totalJobsUsingSkill: (data['totalJobsUsingSkill'] is int)
          ? data['totalJobsUsingSkill'] as int
          : int.tryParse(data['totalJobsUsingSkill']?.toString() ?? '0') ?? 0,
    );
  }

  bool get isTechnical {
    final c = category.toLowerCase();
    return c.contains('technical') || c == 'tool' || c == 'tools';
  }
}

/// User skill storage: skillId + level (0–100). Stored in users.skills[].
class UserSkill {
  final String skillId;
  final int level;

  const UserSkill({required this.skillId, required this.level});

  Map<String, dynamic> toFirestore() => {
    'skillId': skillId,
    'level': level.clamp(0, 100),
  };

  static UserSkill? fromFirestore(dynamic item) {
    if (item is! Map) return null;
    final m = Map<String, dynamic>.from(
      item.map((k, v) => MapEntry(k.toString(), v)),
    );
    final id = m['skillId']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    final dynamic rawLevel = m['level'];
    final level = rawLevel is num
        ? rawLevel.toInt().clamp(0, 100)
        : (double.tryParse(m['level']?.toString() ?? '0')?.toInt() ?? 0).clamp(
            0,
            100,
          );
    return UserSkill(skillId: id, level: level);
  }
}

/// Job required skill: skillId + requiredLevel (0–100) + importance (1–3) + [weight] for match %.
/// [weight] defaults from [importance] when absent in Firestore (1–10 scale preferred for jobs).
class JobRequiredSkill {
  final String skillId;
  final int requiredLevel;
  final int importance;
  /// Weight in weighted match: Σ(score×weight)/Σ(weight). Typically 1–10.
  final int weight;

  JobRequiredSkill({
    required this.skillId,
    required this.requiredLevel,
    required this.importance,
    int? weight,
  }) : weight = (weight ?? importance).clamp(1, 10);

  Map<String, dynamic> toFirestore() => {
    'skillId': skillId,
    'requiredLevel': requiredLevel.clamp(0, 100),
    'importance': importance.clamp(1, 3),
    'weight': weight.clamp(1, 10),
  };

  static JobRequiredSkill? fromFirestore(dynamic item) {
    if (item is! Map) return null;
    final m = Map<String, dynamic>.from(
      item.map((k, v) => MapEntry(k.toString(), v)),
    );
    final id = m['skillId']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    final requiredLevel = m['requiredLevel'] is num
        ? (m['requiredLevel'] as num).toInt().clamp(0, 100)
        : (double.tryParse(m['requiredLevel']?.toString() ?? '70')?.toInt() ??
                  70)
              .clamp(
            0,
            100,
          );
    final importance = m['importance'] is num
        ? (m['importance'] as num).toInt().clamp(1, 3)
        : (double.tryParse(m['importance']?.toString() ?? '2')?.toInt() ?? 2)
            .clamp(1, 3);
    final w = m['weight'] is num
        ? (m['weight'] as num).toInt().clamp(1, 10)
        : null;
    return JobRequiredSkill(
      skillId: id,
      requiredLevel: requiredLevel,
      importance: importance,
      weight: w,
    );
  }
}
