import 'package:flutter/material.dart';

class HighPrioritySkillViewData {
  final int index;
  final String name;
  final bool isTechnical;
  final int gapPercent;
  final int currentPercent;
  final int requiredPercent;
  final int currentScore;
  final int expectedScore;
  final int improvement;

  const HighPrioritySkillViewData({
    required this.index,
    required this.name,
    required this.isTechnical,
    required this.gapPercent,
    required this.currentPercent,
    required this.requiredPercent,
    required this.currentScore,
    required this.expectedScore,
    required this.improvement,
  });
}

class AnalysisHighPrioritySkillsSection extends StatelessWidget {
  final List<HighPrioritySkillViewData> skills;

  const AnalysisHighPrioritySkillsSection({super.key, required this.skills});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('🔥', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'High Priority Skills',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Focus on these skills first to make the biggest impact on your readiness.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        ...skills.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HighPrioritySkillCard(item: item),
          ),
        ),
      ],
    );
  }
}

class _HighPrioritySkillCard extends StatelessWidget {
  final HighPrioritySkillViewData item;

  const _HighPrioritySkillCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFEE2E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${item.index}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'High Priority',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      item.isTechnical ? '💻 Technical' : '🤝 Soft Skill',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'Gap: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    children: [
                      TextSpan(
                        text: '${item.gapPercent}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      TextSpan(
                        text: ' • Improve from ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextSpan(
                        text: '${item.currentPercent}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' to ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextSpan(
                        text: '${item.requiredPercent}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text:
                                'Expected Impact: Learning this skill will increase your match score from ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                            children: [
                              TextSpan(
                                text: '${item.currentScore}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              const TextSpan(text: ' to '),
                              TextSpan(
                                text: '${item.expectedScore}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              TextSpan(
                                text: ' (+${item.improvement}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
