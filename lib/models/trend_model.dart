import 'package:flutter/material.dart';

/// Model for a job market trend card — title, growth percentage, icon name, optional subtitle.
class TrendModel {
  final String id;
  final String title;
  final int growthPercentage;
  final String iconName;
  final String? subtitle;

  const TrendModel({
    required this.id,
    required this.title,
    required this.growthPercentage,
    required this.iconName,
    this.subtitle,
  });

  /// Subtitle to display: custom [subtitle] or "+X% growth in 2025".
  String get displaySubtitle =>
      subtitle ?? '+$growthPercentage% growth in 2025';

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'growth_percentage': growthPercentage,
        'icon_name': iconName,
        if (subtitle != null) 'subtitle': subtitle,
      };

  static TrendModel fromFirestore(String id, Map<String, dynamic> data) {
    final gp = data['growth_percentage'];
    final growth = (gp is int)
        ? gp
        : (int.tryParse(gp?.toString() ?? '0') ?? 0);
    return TrendModel(
      id: id,
      title: data['title']?.toString() ?? '',
      growthPercentage: growth,
      iconName: data['icon_name']?.toString() ?? 'trending_up',
      subtitle: data['subtitle']?.toString(),
    );
  }
}

/// Maps icon name strings from Firestore to [IconData].
IconData trendIconFromName(String iconName) {
  switch (iconName.toLowerCase()) {
    case 'trending_up':
      return Icons.trending_up;
    case 'security':
      return Icons.security;
    case 'home_work':
      return Icons.home_work;
    case 'psychology':
      return Icons.psychology;
    case 'code':
      return Icons.code;
    case 'cloud':
      return Icons.cloud;
    default:
      return Icons.trending_up;
  }
}
