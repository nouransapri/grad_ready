import 'package:flutter/material.dart';

class AnalysisReadinessCard extends StatelessWidget {
  final int score;
  final int matchedSkillsCount;
  final int totalSkillsCount;

  const AnalysisReadinessCard({
    super.key,
    required this.score,
    required this.matchedSkillsCount,
    required this.totalSkillsCount,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    String emoji;
    List<Color> gradientColors;
    String message;
    if (score >= 90) {
      label = 'Job Ready';
      emoji = '🎯';
      gradientColors = [const Color(0xFF10B981), const Color(0xFF059669)];
      message =
          'You have strong alignment with this role. Focus on polishing your interview skills and portfolio.';
    } else if (score >= 70) {
      label = 'Beginner';
      emoji = '🚀';
      gradientColors = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      message = 'Start with the priority skills to build a strong foundation.';
    } else if (score >= 50) {
      label = 'Needs Improvement';
      emoji = '📚';
      gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      message =
          'Build foundational skills in the critical gap areas to improve your match.';
    } else {
      label = 'Beginner';
      emoji = '🚀';
      gradientColors = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      message = 'Start with the priority skills to build a strong foundation.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  'Your Current Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'You match ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    children: [
                      TextSpan(
                        text: '$matchedSkillsCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' out of ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      TextSpan(
                        text: '$totalSkillsCount',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' required skills',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
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
