class SkillModel {
  final String id;
  final String skillName;
  final String? category;
  final String? courseUrl;
  final String? platform;
  final int? jobCount;
  final String? demandLevel;

  const SkillModel({
    required this.id,
    required this.skillName,
    this.category,
    this.courseUrl,
    this.platform,
    this.jobCount,
    this.demandLevel,
  });

  factory SkillModel.fromFirestore(String docId, Map<String, dynamic> data) {
    return SkillModel(
      id: docId,
      skillName: data['skillName']?.toString() ?? '',
      category: data['category']?.toString(),
      courseUrl: data['courseUrl']?.toString(),
      platform: data['platform']?.toString(),
      jobCount: (data['jobCount'] as num?)?.toInt() ?? 0,
      demandLevel: data['demandLevel']?.toString() ?? 'Medium',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'skillName': skillName,
      'category': category,
      'courseUrl': courseUrl,
      'platform': platform,
      'jobCount': jobCount ?? 0,
      'demandLevel': demandLevel ?? 'Medium',
    };
  }

  @override
  String toString() => 'SkillModel(id: $id, skillName: $skillName, category: $category)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is SkillModel &&
      other.skillName.trim().toLowerCase() == skillName.trim().toLowerCase();
  }

  @override
  int get hashCode => skillName.trim().toLowerCase().hashCode;
}
