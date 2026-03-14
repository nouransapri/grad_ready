/// Model for a skill insight (Latest Insights section) — skill name and progress percentage.
class InsightModel {
  final String id;
  final String skillName;
  final int percentage;

  const InsightModel({
    required this.id,
    required this.skillName,
    required this.percentage,
  });

  /// Progress as fraction 0.0–1.0 for LinearProgressIndicator.
  double get progress => (percentage.clamp(0, 100) / 100).toDouble();

  Map<String, dynamic> toFirestore() => {
    'skill_name': skillName,
    'percentage': percentage,
  };

  static InsightModel fromFirestore(String id, Map<String, dynamic> data) {
    final p = data['percentage'];
    final percent = (p is int)
        ? p
        : (int.tryParse(p?.toString() ?? '0') ?? 0).clamp(0, 100);
    return InsightModel(
      id: id,
      skillName: data['skill_name']?.toString() ?? '',
      percentage: percent,
    );
  }
}
