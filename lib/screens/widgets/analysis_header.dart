import 'package:flutter/material.dart';

import '../../app_theme.dart';

class AnalysisHeader extends StatelessWidget {
  final String title;
  final int matchPercent;
  final String matchLabel;
  final int strongCount;
  final int developingCount;
  final int criticalCount;
  final VoidCallback onBackTap;

  const AnalysisHeader({
    super.key,
    required this.title,
    required this.matchPercent,
    required this.matchLabel,
    required this.strongCount,
    required this.developingCount,
    required this.criticalCount,
    required this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPadding + 10,
          left: 20,
          right: 20,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryDark,
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onBackTap,
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Back to Requirements',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Target Role',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  TweenAnimationBuilder<double>(
                    key: ValueKey(matchPercent),
                    tween: Tween(begin: 0, end: matchPercent / 100),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: value.clamp(0.0, 1.0),
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(value * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              matchLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(matchPercent),
                      tween: Tween(begin: 0, end: matchPercent / 100),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _HeaderStatCard(
                          count: '$strongCount',
                          label: 'Strong',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderStatCard(
                          count: '$developingCount',
                          label: 'Developing',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _HeaderStatCard(
                          count: '$criticalCount',
                          label: 'Critical Gaps',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStatCard extends StatelessWidget {
  final String count;
  final String label;

  const _HeaderStatCard({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
