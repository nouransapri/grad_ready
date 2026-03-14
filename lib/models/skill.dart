/// Master skill from Firestore collection `skills`. Used for canonical id, name, and category.
class Skill {
  final String id;
  final String name;
  final String category;

  const Skill({required this.id, required this.name, required this.category});

  Map<String, dynamic> toFirestore() => {'name': name, 'category': category};

  static Skill fromFirestore(String id, Map<String, dynamic> data) {
    return Skill(
      id: id,
      name: data['name']?.toString().trim() ?? '',
      category: data['category']?.toString().trim() ?? 'Technical',
    );
  }

  bool get isTechnical =>
      category.toLowerCase().contains('technical') || category == 'Technical';
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
    final level = m['level'] is int
        ? (m['level'] as int).clamp(0, 100)
        : (int.tryParse(m['level']?.toString() ?? '0') ?? 0).clamp(0, 100);
    return UserSkill(skillId: id, level: level);
  }
}

/// Job required skill: skillId + requiredLevel (0–100) + importance (1–3). Stored in jobs.requiredSkills[].
class JobRequiredSkill {
  final String skillId;
  final int requiredLevel;
  final int importance;

  const JobRequiredSkill({
    required this.skillId,
    required this.requiredLevel,
    required this.importance,
  });

  Map<String, dynamic> toFirestore() => {
    'skillId': skillId,
    'requiredLevel': requiredLevel.clamp(0, 100),
    'importance': importance.clamp(1, 3),
  };

  static JobRequiredSkill? fromFirestore(dynamic item) {
    if (item is! Map) return null;
    final m = Map<String, dynamic>.from(
      item.map((k, v) => MapEntry(k.toString(), v)),
    );
    final id = m['skillId']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    final requiredLevel = m['requiredLevel'] is int
        ? (m['requiredLevel'] as int).clamp(0, 100)
        : (int.tryParse(m['requiredLevel']?.toString() ?? '70') ?? 70).clamp(
            0,
            100,
          );
    final importance = m['importance'] is int
        ? (m['importance'] as int).clamp(1, 3)
        : (int.tryParse(m['importance']?.toString() ?? '2') ?? 2).clamp(1, 3);
    return JobRequiredSkill(
      skillId: id,
      requiredLevel: requiredLevel,
      importance: importance,
    );
  }
}
