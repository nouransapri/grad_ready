import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/course.dart';

class AnalysisMissingSkillsSection extends StatelessWidget {
  final List<String> missingSkills;
  final Set<String> highPrioritySkills;
  final Map<String, List<String>> skillRecommendations;
  final Map<String, List<Course>> skillCourseResources;
  final Map<String, String> skillGapSeverity;
  final ValueChanged<String> onOpenCourseUrl;

  const AnalysisMissingSkillsSection({
    super.key,
    required this.missingSkills,
    required this.highPrioritySkills,
    required this.skillRecommendations,
    required this.skillCourseResources,
    required this.skillGapSeverity,
    required this.onOpenCourseUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (missingSkills.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Skills below job requirement — suggested courses',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        ...missingSkills.map((skillName) {
          final isHigh = highPrioritySkills.contains(skillName);
          final courses = skillRecommendations[skillName] ?? [];
          final courseLinks = skillCourseResources[skillName] ?? [];
          final severity = skillGapSeverity[skillName];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isHigh)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'High priority',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warning,
                          ),
                        ),
                      ),
                    if (severity != null)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          severity,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        skillName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (courseLinks.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Suggested courses (tap to open)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: courseLinks
                        .take(3)
                        .map(
                          (course) => InkWell(
                            onTap: course.url.trim().isEmpty
                                ? null
                                : () => onOpenCourseUrl(course.url),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 2,
                              ),
                              child: Text(
                                course.title.isNotEmpty
                                    ? course.title
                                    : course.platform,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else if (courses.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: Text(
                      'Suggested courses: ${courses.take(3).join(', ')}${courses.length > 3 ? '...' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
