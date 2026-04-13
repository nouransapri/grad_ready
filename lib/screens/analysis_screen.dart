import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/analysis_service.dart';
import '../utils/constants.dart';

/// Academic analysis: GPA (weighted), Firestore course charts, animated progress.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int _refreshTick = 0;

  Future<void> _forceRefresh(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));
    await FirebaseFirestore.instance
        .collection('courses')
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (mounted) {
      setState(() {
        _refreshTick++;
      });
    }
  }

  void _retry() {
    setState(() {
      _refreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Academic Analysis'),
        backgroundColor: const Color(0xFF2A6CFF),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        key: ValueKey('analysis-user-stream-$_refreshTick'),
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
            );
          }
          if (userSnapshot.hasError) {
            return _ErrorPane(
              message: userSnapshot.error.toString(),
              onRetry: _retry,
            );
          }

          final data = userSnapshot.data?.data();
          final transcript = AnalysisService.parseAddedCourses(
            data?[AppConstants.userFieldAddedCourses],
          );
          final validTranscript = transcript.where((r) => r.isValid).toList();
          final computedGpa = AnalysisService.computeWeightedGpa(transcript);
          final profileGpa =
              AnalysisService.parseProfileGpaField(data?[AppConstants.userFieldGpa]);
          final skillList = AnalysisService.parseUserSkillsProgress(
            data?[AppConstants.userFieldSkills],
          );
          final trendRows = AnalysisService.lastCourses(validTranscript, maxCount: 7);
          final lineSpots = AnalysisService.cumulativeGpaSpots(trendRows);

          return RefreshIndicator(
            onRefresh: () => _forceRefresh(user.uid),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _GpaCard(
                  computedGpa: computedGpa,
                  profileGpa: profileGpa,
                  transcriptCount: validTranscript.length,
                ),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.school_outlined,
                  title: 'Your courses (GPA)',
                ),
                const SizedBox(height: 8),
                if (validTranscript.isEmpty)
                  _EmptyHint(
                    text: computedGpa == null && profileGpa == null
                        ? 'Add courses under your profile (added_courses with name, grade, credits) or enter GPA in Academic Information.'
                        : 'Add structured courses for a weighted GPA chart. Profile GPA is shown above if set.',
                  )
                else ...[
                  SizedBox(
                    height: 220,
                    child: lineSpots.isEmpty
                        ? const Center(child: Text('No GPA trend'))
                        : LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 4,
                              gridData: const FlGridData(show: true),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 44,
                                    getTitlesWidget: (v, m) {
                                      final i = v.toInt();
                                      if (i >= 0 && i < trendRows.length) {
                                        final short = trendRows[i].name.length > 7
                                            ? '${trendRows[i].name.substring(0, 6)}…'
                                            : trendRows[i].name;
                                        return SideTitleWidget(
                                          axisSide: m.axisSide,
                                          angle: -0.5,
                                          child: Text(
                                            short,
                                            style: const TextStyle(fontSize: 9),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    getTitlesWidget: (v, m) => Text(
                                      v.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: lineSpots,
                                  isCurved: true,
                                  color: const Color(0xFF9226FF),
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    checkToShowDot: (spot, barData) =>
                                        spot.x == 0 ||
                                        spot.x == lineSpots.last.x ||
                                        lineSpots.length <= 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cumulative GPA by course order (max 4.0)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 24),
                _CoursesCatalogSection(
                  retryTick: _refreshTick,
                  onRetry: _retry,
                ),
                const SizedBox(height: 24),
                _SectionTitle(
                  icon: Icons.star_outline,
                  title: 'Skills progress',
                ),
                const SizedBox(height: 8),
                if (skillList.isEmpty)
                  const _EmptyHint(
                    text: 'No skills on profile yet.',
                  )
                else
                  ...skillList.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AnimatedSkillBar(
                        name: e.label,
                        percent: e.percent,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CoursesCatalogSection extends StatelessWidget {
  final int retryTick;
  final VoidCallback onRetry;

  const _CoursesCatalogSection({
    required this.retryTick,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Course>>(
      key: ValueKey('analysis-catalog-stream-$retryTick'),
      stream: AnalysisService.watchCatalogCourses(),
      builder: (context, courseSnapshot) {
        final catalogLoading = courseSnapshot.connectionState == ConnectionState.waiting;
        final catalog = courseSnapshot.data ?? [];
        final catalogError = courseSnapshot.error;
        final barGroups = AnalysisService.buildAvgRatingBySkillBars(catalog, maxBars: 8);
        final barLabels = AnalysisService.avgRatingBarLabels(catalog, maxBars: 8);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.bar_chart_rounded,
              title: 'Course catalog (avg rating by skill)',
            ),
            const SizedBox(height: 8),
            if (catalogLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
                ),
              )
            else if (catalogError != null)
              _ErrorPane(
                message: catalogError.toString(),
                onRetry: onRetry,
              )
            else if (barGroups.isEmpty)
              const _EmptyHint(
                text: 'No course catalog data in Firestore yet, or ratings could not be grouped.',
              )
            else
              SizedBox(
                height: 240,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 5,
                    gridData: const FlGridData(show: true),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final label =
                              group.x >= 0 && group.x < barLabels.length ? barLabels[group.x] : 'Skill';
                          return BarTooltipItem(
                            '$label\n${rod.toY.toStringAsFixed(1)} / 5',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, m) {
                            final i = v.toInt();
                            if (i >= 0 && i < barLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  barLabels[i],
                                  style: const TextStyle(fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (v, m) => Text(
                            v.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: barGroups,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GpaCard extends StatelessWidget {
  final double? computedGpa;
  final double? profileGpa;
  final int transcriptCount;

  const _GpaCard({
    required this.computedGpa,
    required this.profileGpa,
    required this.transcriptCount,
  });

  @override
  Widget build(BuildContext context) {
    final display = computedGpa ?? profileGpa;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GPA overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (display != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: display.clamp(0.0, 4.0)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A6CFF),
                    ),
                  );
                },
              )
            else
              Text(
                '—',
                style: TextStyle(fontSize: 32, color: Colors.grey[500]),
              ),
            const SizedBox(height: 8),
            Text(
              computedGpa != null
                  ? 'Weighted from $transcriptCount course(s): Σ(grade×credits)/Σcredits'
                  : 'Enter GPA on profile or add courses with grades & credits',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            if (computedGpa != null && profileGpa != null) ...[
              const SizedBox(height: 8),
              Text(
                'Profile field GPA: ${profileGpa!.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A1C1E)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1C1E),
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPane({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linear progress animates from 0 to [percent] (0–100).
class _AnimatedSkillBar extends StatefulWidget {
  final String name;
  final double percent;

  const _AnimatedSkillBar({
    required this.name,
    required this.percent,
  });

  @override
  State<_AnimatedSkillBar> createState() => _AnimatedSkillBarState();
}

class _AnimatedSkillBarState extends State<_AnimatedSkillBar> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _t = widget.percent.clamp(0, 100));
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedSkillBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percent != widget.percent) {
      setState(() => _t = widget.percent.clamp(0, 100));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _t),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) {
                return Text('${v.toStringAsFixed(0)}%');
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: _t / 100.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFF9226FF),
              ),
            );
          },
        ),
      ],
    );
  }
}
