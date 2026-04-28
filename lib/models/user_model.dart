import '../utils/skill_utils.dart';

int _profileProficiencyToLevel(String value) {
  final v = value.trim().toLowerCase();
  if (v == 'advanced') return 95;
  if (v == 'intermediate') return 65;
  if (v == 'basic') return 35;
  return (double.tryParse(value)?.toInt() ?? 35).clamp(0, 100);
}

class UserSkillModel {
  final String skillId;
  final String name;
  final String type;
  final int level;
  final String levelLabel;

  const UserSkillModel({
    required this.skillId,
    required this.name,
    required this.type,
    required this.level,
    required this.levelLabel,
  });

  factory UserSkillModel.fromMap(Map<String, dynamic> map) {
    final name = map['name']?.toString().trim() ?? '';
    final type = map['type']?.toString().trim().isNotEmpty == true
        ? map['type'].toString().trim()
        : 'Technical';
    final levelLabel = map['levelLabel']?.toString().trim().isNotEmpty == true
        ? map['levelLabel'].toString().trim()
        : map['level']?.toString().trim().isNotEmpty == true
            ? map['level'].toString().trim()
            : 'Basic';
    final parsedLevel = map['level'] is num
        ? (map['level'] as num).toInt()
        : int.tryParse(map['level']?.toString() ?? '');
    final level = (parsedLevel ?? _profileProficiencyToLevel(levelLabel)).clamp(
      0,
      100,
    );
    return UserSkillModel(
      skillId: map['skillId']?.toString().trim().isNotEmpty == true
          ? map['skillId'].toString().trim()
          : skillNameToSkillId(name),
      name: name,
      type: type,
      level: level,
      levelLabel: levelLabel,
    );
  }

  Map<String, dynamic> toMap() => {
        'skillId': skillId.isNotEmpty ? skillId : skillNameToSkillId(name),
        'name': name,
        'type': type,
        'level': level.clamp(0, 100),
        'levelLabel': levelLabel,
      };
}

class InternshipModel {
  final String title;
  final String company;
  final String duration;

  const InternshipModel({
    required this.title,
    required this.company,
    required this.duration,
  });

  factory InternshipModel.fromMap(Map<String, dynamic> map) {
    return InternshipModel(
      title: map['title']?.toString().trim() ?? '',
      company: map['company']?.toString().trim() ?? '',
      duration: map['duration']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'company': company,
        'duration': duration,
      };
}

class ClubModel {
  final String name;
  final String role;

  const ClubModel({
    required this.name,
    required this.role,
  });

  factory ClubModel.fromMap(Map<String, dynamic> map) {
    return ClubModel(
      name: map['name']?.toString().trim() ?? '',
      role: map['role']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role,
      };
}

class ProjectModel {
  final String name;
  final String description;

  const ProjectModel({
    required this.name,
    required this.description,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      name: map['name']?.toString().trim() ?? '',
      description: map['description']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
      };
}

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String university;
  final String major;
  final String academicYear;
  final String gpa;
  final String photoUrl;
  final List<UserSkillModel> skills;
  final List<InternshipModel> internships;
  final List<ClubModel> clubs;
  final List<ProjectModel> projects;
  final bool profileCompleted;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.university,
    required this.major,
    required this.academicYear,
    required this.gpa,
    this.photoUrl = '',
    this.skills = const [],
    this.internships = const [],
    this.clubs = const [],
    this.projects = const [],
    this.profileCompleted = false,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(String uid, Map<String, dynamic> map) {
    final rawSkills = map['skills'] as List?;
    final rawInternships = map['internships'] as List?;
    final rawClubs = map['clubs'] as List?;
    final rawProjects = map['projects'] as List?;
    return UserModel(
      uid: uid,
      email: map['email']?.toString().trim() ?? '',
      fullName: map['full_name']?.toString().trim() ?? '',
      university: map['university']?.toString().trim() ?? '',
      major: map['major']?.toString().trim() ?? '',
      academicYear: map['academic_year']?.toString().trim() ?? '',
      gpa: map['gpa']?.toString().trim() ?? '',
      photoUrl: map['photoUrl']?.toString().trim() ?? '',
      skills: _parseSkills(rawSkills),
      internships: rawInternships == null
          ? const []
          : rawInternships
              .whereType<Map>()
              .map((e) => InternshipModel.fromMap(
                    Map<String, dynamic>.from(
                      e.map((k, v) => MapEntry(k.toString(), v)),
                    ),
                  ))
              .where((i) => i.title.isNotEmpty || i.company.isNotEmpty)
              .toList(),
      clubs: rawClubs == null
          ? const []
          : rawClubs
              .whereType<Map>()
              .map((e) => ClubModel.fromMap(
                    Map<String, dynamic>.from(
                      e.map((k, v) => MapEntry(k.toString(), v)),
                    ),
                  ))
              .where((c) => c.name.isNotEmpty || c.role.isNotEmpty)
              .toList(),
      projects: rawProjects == null
          ? const []
          : rawProjects
              .whereType<Map>()
              .map((e) => ProjectModel.fromMap(
                    Map<String, dynamic>.from(
                      e.map((k, v) => MapEntry(k.toString(), v)),
                    ),
                  ))
              .where((p) => p.name.isNotEmpty || p.description.isNotEmpty)
              .toList(),
      profileCompleted: map['profile_completed'] == true,
      isActive: map['isSuspended'] != true,
    );
  }

  static List<UserSkillModel> _parseSkills(List<dynamic>? rawSkills) {
    if (rawSkills == null) return const [];
    final out = <UserSkillModel>[];
    for (final s in rawSkills) {
      if (s is String) {
        final name = s.trim();
        if (name.isEmpty) continue;
        out.add(
          UserSkillModel(
            skillId: skillNameToSkillId(name),
            name: name,
            type: 'Technical',
            level: 35,
            levelLabel: 'Basic',
          ),
        );
        continue;
      }
      if (s is! Map) continue;
      final parsed = UserSkillModel.fromMap(
        Map<String, dynamic>.from(
          s.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
      if (parsed.name.isNotEmpty) out.add(parsed);
    }
    return out;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'full_name': fullName,
      'university': university,
      'major': major,
      'academic_year': academicYear,
      'gpa': gpa,
      'photoUrl': photoUrl,
      'skills': skills.map((e) => e.toMap()).toList(),
      'internships': internships.map((e) => e.toMap()).toList(),
      'clubs': clubs.map((e) => e.toMap()).toList(),
      'projects': projects.map((e) => e.toMap()).toList(),
      'profile_completed': profileCompleted,
      'isSuspended': !isActive,
    };
  }
}
