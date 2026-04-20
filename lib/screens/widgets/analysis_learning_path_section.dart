import 'package:flutter/material.dart';

import '../../services/gap_analysis_service.dart';

class AnalysisLearningPathSection extends StatelessWidget {
  final List<LearningStep> steps;
  final ValueChanged<String> onOpenCourseUrl;

  const AnalysisLearningPathSection({
    super.key,
    required this.steps,
    required this.onOpenCourseUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'Learning path (by priority)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        ...steps.map(
          (step) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${step.stepNumber}: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.skillName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (step.suggestedCourseLinks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: step.suggestedCourseLinks
                              .take(3)
                              .map(
                                (c) => InkWell(
                                  onTap: c.url.trim().isEmpty
                                      ? null
                                      : () => onOpenCourseUrl(c.url),
                                  child: Text(
                                    c.title.isNotEmpty ? c.title : c.platform,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ] else if (step.suggestedCourses.isNotEmpty)
                        Text(
                          'Resources: ${step.suggestedCourses.take(2).join(', ')}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
