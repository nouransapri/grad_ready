import 'package:flutter/material.dart';

import '../../app_theme.dart';

class AnalysisStatusGuideCard extends StatelessWidget {
  const AnalysisStatusGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
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
          const Text(
            'Status Guide',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 18),
          _StatusRow(
            icon: Icons.check_circle,
            color: AppTheme.success,
            boldLabel: 'Strong',
            description: 'You meet or exceed the requirement',
          ),
          const SizedBox(height: 14),
          _StatusRow(
            icon: Icons.trending_up_rounded,
            color: Theme.of(context).colorScheme.primary,
            boldLabel: 'Developing',
            description: 'Gap is ≤30% - you\'re close!',
          ),
          const SizedBox(height: 14),
          _StatusRow(
            icon: Icons.warning_amber_rounded,
            color: AppTheme.warning,
            boldLabel: 'Critical',
            description: 'Gap is >30% - priority for improvement',
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String boldLabel;
  final String description;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.boldLabel,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$boldLabel: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
