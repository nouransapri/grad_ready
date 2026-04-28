import 'package:flutter/material.dart';

import '../../app_theme.dart';

import '../../models/skill_model.dart';
import '../../utils/skill_utils.dart';

class AnalysisMissingSkillsSection extends StatelessWidget {
  final List<String> missingSkills;
  final Set<String> highPrioritySkills;
  /// Skills that are mandatory gate-blockers; shown with a red "Mandatory" badge.
  final Set<String> mandatorySkillNames;
  final Map<String, List<String>> skillRecommendations;

  final Map<String, String> skillGapSeverity;
  final Map<String, SkillModel>? skillModelsCache;
  final ValueChanged<String> onOpenCourseUrl;

  const AnalysisMissingSkillsSection({
    super.key,
    required this.missingSkills,
    required this.highPrioritySkills,
    this.mandatorySkillNames = const {},
    required this.skillRecommendations,

    required this.skillGapSeverity,
    this.skillModelsCache,
    required this.onOpenCourseUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (missingSkills.isEmpty) {
      return const SizedBox.shrink();
    }

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
          final isMandatory = mandatorySkillNames.contains(skillName);
          final isHigh = !isMandatory && highPrioritySkills.contains(skillName);
          final courses = skillRecommendations[skillName] ?? [];

          final severity = skillGapSeverity[skillName];
          final normalizedSearchKey = smartNormalize(skillName);
          final skillModel = skillModelsCache?[normalizedSearchKey];
          final hasCourseModel = skillModel != null && skillModel.courseUrl != null && skillModel.courseUrl!.trim().isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isMandatory)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Mandatory',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      )
                    else if (isHigh)
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
                    if (hasCourseModel)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 12, color: Theme.of(context).colorScheme.onPrimaryContainer),
                            const SizedBox(width: 4),
                            Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
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
                if (courses.isNotEmpty) ...[
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
                if (hasCourseModel) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final url = skillModel.courseUrl ?? '';
                        if (url.trim().isNotEmpty) onOpenCourseUrl(url);
                      },
                      icon: const Icon(Icons.school_rounded, size: 16),
                      label: const Text('Learn & Grow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 12, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Resource Hunt in Progress…',
                          style: TextStyle(fontSize: 10, color: Colors.amber.shade800),
                        ),
                      ],
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
