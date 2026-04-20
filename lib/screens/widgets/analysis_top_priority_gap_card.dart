import 'package:flutter/material.dart';

class AnalysisTopPriorityGapCard extends StatelessWidget {
  final String skillName;
  final int requiredPercent;
  final int currentPercent;
  final int gapPercent;

  const AnalysisTopPriorityGapCard({
    super.key,
    required this.skillName,
    required this.requiredPercent,
    required this.currentPercent,
    required this.gapPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDBA74), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFFEA580C),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Top Priority Skill Gap',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            skillName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'High Priority',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'This skill is required at ',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    children: [
                      TextSpan(
                        text: '$requiredPercent%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      TextSpan(
                        text: ' but you currently have ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      TextSpan(
                        text: '$currentPercent%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Gap: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    children: [
                      TextSpan(
                        text: '$gapPercent%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const TextSpan(text: ' improvement needed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
