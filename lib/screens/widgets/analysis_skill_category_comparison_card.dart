import 'package:flutter/material.dart';

class AnalysisSkillCategoryComparisonCard extends StatelessWidget {
  final int technicalMatch;
  final int softMatch;

  const AnalysisSkillCategoryComparisonCard({
    super.key,
    required this.technicalMatch,
    required this.softMatch,
  });

  @override
  Widget build(BuildContext context) {
    final diff = (technicalMatch - softMatch).abs();
    final isBalanced = diff <= 15;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Color(0xFF7C3AED),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill Category Comparison',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Coverage breakdown by skill type',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _CategoryComparisonRow(
            icon: '💻',
            label: 'Technical Skills',
            percent: technicalMatch,
            barColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFDBEAFE),
          ),
          const SizedBox(height: 20),
          _CategoryComparisonRow(
            icon: '🤝',
            label: 'Soft Skills',
            percent: softMatch,
            barColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFEDE9FE),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isBalanced ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBalanced
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFED7AA),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.info_outline,
                  color: isBalanced
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEA580C),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBalanced ? 'Balanced Skill Profile' : 'Skill balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isBalanced
                              ? const Color(0xFF166534)
                              : const Color(0xFF9A3412),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBalanced
                            ? 'Great balance! Both technical and soft skills are well-developed.'
                            : (technicalMatch >= softMatch + 15)
                            ? 'Your technical skills ($technicalMatch%) are stronger than soft skills ($softMatch%). Consider developing soft skills for better job readiness.'
                            : 'Your soft skills ($softMatch%) are stronger than technical skills ($technicalMatch%). Consider strengthening technical skills for this role.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isBalanced
                              ? const Color(0xFF166534)
                              : const Color(0xFF9A3412),
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

class _CategoryComparisonRow extends StatelessWidget {
  final String icon;
  final String label;
  final int percent;
  final Color barColor;
  final Color bgColor;

  const _CategoryComparisonRow({
    required this.icon,
    required this.label,
    required this.percent,
    required this.barColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1C1E),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: barColor,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Current Coverage',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${100 - percent}% gap remaining',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
