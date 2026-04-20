import 'package:flutter/material.dart';

import '../../app_theme.dart';

class AnalysisGapSummaryHeader extends StatelessWidget {
  final double matchPercentage;
  final int matchedSkillsCount;
  final int missingSkillsCount;
  final int flexMatched;
  final int flexMissing;

  const AnalysisGapSummaryHeader({
    super.key,
    required this.matchPercentage,
    required this.matchedSkillsCount,
    required this.missingSkillsCount,
    required this.flexMatched,
    required this.flexMissing,
  });

  @override
  Widget build(BuildContext context) {
    final totalSkillsCount = matchedSkillsCount + missingSkillsCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile vs Job Match: ${matchPercentage.toStringAsFixed(0)}% ($matchedSkillsCount/$totalSkillsCount skills)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1C1E),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 18,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Matched $matchedSkillsCount · Below requirement $missingSkillsCount',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Expanded(
                flex: flexMatched > 0 ? flexMatched : 1,
                child: Container(height: 10, color: AppTheme.success),
              ),
              Expanded(
                flex: flexMissing > 0 ? flexMissing : 1,
                child: Container(height: 10, color: AppTheme.warning),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
