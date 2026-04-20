import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// Single skill card in Skills Breakdown tab (Critical label + improvement text).
class BreakdownSkillTile extends StatelessWidget {
  final String name;
  final int currentPercent;
  final int requiredPercent;
  final int gapPercent;
  final bool isCriticalGap;
  final bool isStrong;
  final bool isDeveloping;

  const BreakdownSkillTile({
    super.key,
    required this.name,
    required this.currentPercent,
    required this.requiredPercent,
    required this.gapPercent,
    required this.isCriticalGap,
    required this.isStrong,
    required this.isDeveloping,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.show_chart_rounded,
                color: AppTheme.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
              if (isCriticalGap)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'Critical',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current: $currentPercent%',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Required: $requiredPercent%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (requiredPercent > 0)
                  ? (currentPercent / requiredPercent).clamp(0.0, 1.0)
                  : 0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                isStrong
                    ? AppTheme.success
                    : isDeveloping
                        ? AppTheme.primary
                        : AppTheme.warning,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gap: $gapPercent% improvement needed',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
