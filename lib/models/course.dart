/// Course from Firestore collection `courses`. Used for skill recommendations.
class Course {
  final String skillName;
  final String skillId;
  final String title;
  final String platform;
  final String url;
  final String duration;
  final String cost;
  final String? estimatedPrice;
  final double rating;
  final String level;
  final String description;
  final int priority;
  final double relevanceScore;

  const Course({
    required this.skillName,
    this.skillId = '',
    required this.title,
    required this.platform,
    required this.url,
    required this.duration,
    required this.cost,
    this.estimatedPrice,
    required this.rating,
    required this.level,
    required this.description,
    this.priority = 1,
    this.relevanceScore = 0.0,
  });

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'skillName': skillName,
      'skillId': skillId,
      'title': title,
      'platform': platform,
      'url': url,
      'duration': duration,
      'cost': cost,
      'rating': rating,
      'level': level,
      'description': description,
      'priority': priority.clamp(1, 10),
      'relevanceScore': relevanceScore.clamp(0.0, 1.0),
    };
    if (estimatedPrice != null && estimatedPrice!.isNotEmpty) {
      map['estimatedPrice'] = estimatedPrice;
    }
    return map;
  }

  static Course fromFirestore(Map<String, dynamic> data) {
    return Course(
      skillName: data['skillName']?.toString().trim() ?? '',
      skillId: data['skillId']?.toString().trim() ?? '',
      title: data['title']?.toString().trim() ?? '',
      platform: data['platform']?.toString().trim() ?? '',
      url: data['url']?.toString().trim() ?? '',
      duration: data['duration']?.toString().trim() ?? '',
      cost: data['cost']?.toString().trim() ?? 'Free',
      estimatedPrice: data['estimatedPrice']?.toString().trim(),
      rating: (data['rating'] is num)
          ? (data['rating'] as num).toDouble().clamp(0.0, 5.0)
          : (double.tryParse(data['rating']?.toString() ?? '0') ?? 0).clamp(0.0, 5.0),
      level: data['level']?.toString().trim() ?? 'Beginner',
      description: data['description']?.toString().trim() ?? '',
      priority: (data['priority'] is int)
          ? (data['priority'] as int).clamp(1, 10)
          : (int.tryParse(data['priority']?.toString() ?? '1') ?? 1).clamp(
              1,
              10,
            ),
      relevanceScore: (data['relevanceScore'] is num)
          ? (data['relevanceScore'] as num).toDouble().clamp(0.0, 1.0)
          : (double.tryParse(data['relevanceScore']?.toString() ?? '0') ?? 0)
                .clamp(0.0, 1.0),
    );
  }
}
