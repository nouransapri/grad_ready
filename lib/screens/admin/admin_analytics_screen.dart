import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';
import '../../models/job_role.dart';
import '../../services/firestore_service.dart';
import '../../services/gap_analysis_service.dart';

// ألوان من الثيم + ثابتة للعناصر
const Color _segmentSelectedBg = Color(0xFF5B4B9E);
const Color _segmentUnselectedBg = Color(0xFFF5F5F5);
const Color _trendBoxBg = Color(0xFFE8E4F5);
const Color _chartPrimary = Color(0xFF5B4B9E);
const Color _pdfBlue = Color(0xFF2196F3);

/// Fixed palette for academic level segments (by index).
const _academicColors = [
  Color(0xFF6B5BAE),
  Color(0xFF5B4B9E),
  Color(0xFF2196F3),
  Color(0xFF2E7D32),
  Color(0xFFFF9800),
];

// --- Dynamic analytics from Firestore (no hardcoded values) ---

/// 1. Most Selected Job Roles: count users whose last_analysis matches each job title.
List<(String, double)> computeMostSelectedJobRoles(
  List<Map<String, dynamic>> users,
  List<JobRole> jobs, {
  int top = 7,
}) {
  final countByTitle = <String, int>{};
  for (final j in jobs) {
    countByTitle[j.title] = 0;
  }
  for (final u in users) {
    final last = u['last_analysis']?.toString().trim();
    if (last != null && last.isNotEmpty && countByTitle.containsKey(last)) {
      countByTitle[last] = (countByTitle[last] ?? 0) + 1;
    }
  }
  final sorted = countByTitle.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(top).map((e) => (e.key, e.value.toDouble())).toList();
}

double computeTotalSelections(List<Map<String, dynamic>> users) {
  int n = 0;
  for (final u in users) {
    final last = u['last_analysis']?.toString().trim();
    if (last != null && last.isNotEmpty) n++;
  }
  return n.toDouble();
}

/// 2. Users by Academic Level: group users by academic_year, count and percent.
List<({String label, double percent, int count, Color color})>
computeAcademicSegments(List<Map<String, dynamic>> users) {
  final byLevel = <String, int>{};
  for (final u in users) {
    final level = u['academic_year']?.toString().trim() ?? 'Other';
    final key = level.isEmpty ? 'Other' : level;
    byLevel[key] = (byLevel[key] ?? 0) + 1;
  }
  final total = users.isEmpty ? 1 : users.length;
  final entries = byLevel.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.asMap().entries.map((e) {
    final i = e.key;
    final entry = e.value;
    final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
    return (
      label: entry.key,
      percent: pct,
      count: entry.value,
      color: _academicColors[i % _academicColors.length],
    );
  }).toList();
}

/// 3. Most Frequently Added Skills: count each skill name across all users (from users.skills).
List<(String, int)> computeMostFrequentSkills(
  List<Map<String, dynamic>> users, {
  int top = 5,
}) {
  final count = <String, int>{};
  for (final u in users) {
    final skills = u['skills'] as List<dynamic>?;
    if (skills == null) continue;
    for (final s in skills) {
      final name = s is String
          ? s.toString().trim()
          : (s is Map ? (s['name']?.toString() ?? '').trim() : '');
      if (name.isEmpty) continue;
      final norm = GapAnalysisService.normalize(name);
      if (norm.isEmpty) continue;
      count[norm] = (count[norm] ?? 0) + 1;
    }
  }
  final sorted = count.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(top).map((e) => (e.key, e.value)).toList();
}

/// 4. Job Category Distribution: from jobs collection, group by category, percent of total.
List<(String, int)> computeCategoryDistribution(List<JobRole> jobs) {
  final byCat = <String, int>{};
  for (final j in jobs) {
    final cat = j.category.trim().isEmpty ? 'Other' : j.category;
    byCat[cat] = (byCat[cat] ?? 0) + 1;
  }
  final total = jobs.isEmpty ? 1 : jobs.length;
  return byCat.entries
      .map((e) => (e.key, total > 0 ? ((e.value / total) * 100).round() : 0))
      .toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));
}

/// 5. Assessment Activity Trend: count users per week by last_analysis_at (last 4 weeks).
List<FlSpot> computeActivitySpots(
  List<Map<String, dynamic>> users, {
  int weeks = 4,
}) {
  final now = DateTime.now();
  final buckets = List<int>.filled(weeks, 0);
  for (final u in users) {
    final t = u['last_analysis_at'];
    if (t == null) continue;
    DateTime? dt;
    if (t is Timestamp) dt = t.toDate();
    if (dt == null) continue;
    final diff = now.difference(dt).inDays;
    if (diff < 0) continue;
    final weekIndex = (diff / 7).floor();
    if (weekIndex >= weeks) continue;
    buckets[weeks - 1 - weekIndex]++;
  }
  return buckets
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
      .toList();
}

String computeActivityTrendMessage(
  List<Map<String, dynamic>> users,
  int weeks,
) {
  final spots = computeActivitySpots(users, weeks: weeks);
  if (spots.length < 2) return 'Not enough data for trend.';
  final firstHalf = spots
      .take(spots.length ~/ 2)
      .fold<double>(0, (s, sp) => s + sp.y);
  final secondHalf = spots
      .skip(spots.length ~/ 2)
      .fold<double>(0, (s, sp) => s + sp.y);
  if (firstHalf == 0) return 'Assessment activity is growing.';
  final pct = ((secondHalf - firstHalf) / firstHalf * 100).round();
  if (pct >= 0) {
    return 'Assessment activity increased by $pct% over the last $weeks weeks.';
  }
  return 'Assessment activity decreased by ${-pct}% over the last $weeks weeks.';
}

/// 6. Key Insights Summary: generated from real analytics.
List<String> computeKeyInsights({
  required List<Map<String, dynamic>> users,
  required List<JobRole> jobs,
  required List<(String, double)> jobRolesBarData,
  required double totalSelections,
  required List<({String label, double percent, int count, Color color})>
  academicSegments,
  required List<(String, int)> topSkills,
  required List<(String, int)> categoryDistribution,
  required String activityTrendMessage,
}) {
  final insights = <String>[];
  if (jobRolesBarData.isNotEmpty && totalSelections > 0) {
    final top = jobRolesBarData.first;
    final pct = ((top.$2 / totalSelections) * 100).toStringAsFixed(0);
    insights.add('${top.$1} is the most selected role ($pct% of analyses).');
  }
  if (academicSegments.isNotEmpty) {
    final top = academicSegments.first;
    insights.add(
      '${top.label} is the largest academic segment (${top.count} users, ${top.percent.toStringAsFixed(0)}%).',
    );
  }
  if (topSkills.isNotEmpty) {
    insights.add(
      '${topSkills.first.$1} is the most frequently added skill (${topSkills.first.$2} users).',
    );
  }
  if (categoryDistribution.isNotEmpty) {
    final top = categoryDistribution.first;
    insights.add('${top.$1} has the most job roles (${top.$2}% of catalog).');
  }
  insights.add(activityTrendMessage);
  if (insights.length < 4 && users.isNotEmpty) {
    insights.add('Total registered users: ${users.length}.');
  }
  return insights;
}

/// محتوى تبويب Analytics في لوحة الأدمن.
class AdminAnalyticsContent extends StatefulWidget {
  const AdminAnalyticsContent({super.key});

  @override
  State<AdminAnalyticsContent> createState() => _AdminAnalyticsContentState();
}

class _AdminAnalyticsContentState extends State<AdminAnalyticsContent>
    with SingleTickerProviderStateMixin {
  int _periodIndex = 0; // 0=Week, 1=Month, 2=Year
  late AnimationController _chartAnimController;
  late Animation<double> _chartAnim;

  @override
  void initState() {
    super.initState();
    _chartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _chartAnim = CurvedAnimation(
      parent: _chartAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _chartAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const horizontalPadding = 16.0;
    final firestore = FirestoreService();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        20 + bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // All analytics from Firestore: users (with academic_year, last_analysis, last_analysis_at, skills) + jobs
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: firestore.streamUsersForAnalytics(),
            builder: (context, usersSnap) {
              if (!usersSnap.hasData) {
                return const _AnalyticsCard(
                  title: 'Analytics',
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  ),
                );
              }
              return StreamBuilder<List<JobRole>>(
                stream: firestore.getJobs(),
                builder: (context, jobsSnap) {
                  if (!jobsSnap.hasData) {
                    return const _AnalyticsCard(
                      title: 'Analytics',
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    );
                  }
                  final users = usersSnap.data!;
                  final jobs = jobsSnap.data!;

                  // Compute all 6 analytics from Firestore (no hardcoded values)
                  final jobRolesBarData = computeMostSelectedJobRoles(
                    users,
                    jobs,
                  );
                  final totalSelections = computeTotalSelections(users);
                  final academicSegments = computeAcademicSegments(users);
                  final topSkills = computeMostFrequentSkills(users);
                  final categoryDistribution = computeCategoryDistribution(
                    jobs,
                  );
                  final activitySpots = computeActivitySpots(users);
                  final activityTrendMessage = computeActivityTrendMessage(
                    users,
                    4,
                  );
                  final keyInsights = computeKeyInsights(
                    users: users,
                    jobs: jobs,
                    jobRolesBarData: jobRolesBarData,
                    totalSelections: totalSelections,
                    academicSegments: academicSegments,
                    topSkills: topSkills,
                    categoryDistribution: categoryDistribution,
                    activityTrendMessage: activityTrendMessage,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkillsGapAnalyticsSection(
                        users: users,
                        jobs: jobs,
                        screenWidth: screenWidth,
                        chartAnim: _chartAnim,
                        onChartReady: () {
                          if (!_chartAnimController.isAnimating &&
                              !_chartAnimController.isCompleted) {
                            _chartAnimController.forward();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _AnalyticsOverviewCard(
                        periodIndex: _periodIndex,
                        onPeriodChanged: (i) =>
                            setState(() => _periodIndex = i),
                      ),
                      const SizedBox(height: 16),
                      _MostSelectedJobRolesAnalyticsCard(
                        screenWidth: screenWidth,
                        barData: jobRolesBarData,
                        totalSelections: totalSelections,
                      ),
                      const SizedBox(height: 16),
                      _AssessmentActivityTrendCard(
                        screenWidth: screenWidth,
                        spots: activitySpots,
                        trendMessage: activityTrendMessage,
                      ),
                      const SizedBox(height: 16),
                      _UsersByAcademicLevelAnalyticsCard(
                        screenWidth: screenWidth,
                        segments: academicSegments,
                      ),
                      const SizedBox(height: 16),
                      _MostFrequentlyAddedSkillsCard(topSkills: topSkills),
                      const SizedBox(height: 16),
                      _JobCategoryDistributionCard(
                        distribution: categoryDistribution,
                      ),
                      const SizedBox(height: 16),
                      _KeyInsightsSummaryCard(insights: keyInsights),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _AnalyticsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Match % for one user vs one job: (matchedSkills / requiredSkills.length) * 100.
double _matchPercent(List<dynamic> userSkills, List<String> requiredSkills) {
  if (requiredSkills.isEmpty) return 100.0;
  final userSet = userSkills
      .map(
        (s) => GapAnalysisService.normalize(
          s is String
              ? s
              : s is Map
              ? (s['name']?.toString() ?? '')
              : '',
        ),
      )
      .where((s) => s.isNotEmpty)
      .toSet();
  int matched = 0;
  for (final r in requiredSkills) {
    if (userSet.contains(GapAnalysisService.normalize(r))) matched++;
  }
  return (matched / requiredSkills.length) * 100.0;
}

List<String> _userSkillStrings(Map<String, dynamic> user) {
  final raw = user['skills'] as List?;
  if (raw == null) return [];
  return raw
      .map(
        (s) => s is String
            ? s
            : (s is Map ? (s['name']?.toString() ?? '') : '').toString().trim(),
      )
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Real-time Skills Gap Analytics: average match %, most missing skill, users per job.
class _SkillsGapAnalyticsSection extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final List<JobRole> jobs;
  final double screenWidth;
  final Animation<double> chartAnim;
  final VoidCallback onChartReady;

  const _SkillsGapAnalyticsSection({
    required this.users,
    required this.jobs,
    required this.screenWidth,
    required this.chartAnim,
    required this.onChartReady,
  });

  @override
  State<_SkillsGapAnalyticsSection> createState() =>
      _SkillsGapAnalyticsSectionState();
}

class _SkillsGapAnalyticsSectionState
    extends State<_SkillsGapAnalyticsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChartReady());
  }

  @override
  void didUpdateWidget(covariant _SkillsGapAnalyticsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users != widget.users || oldWidget.jobs != widget.jobs) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onChartReady(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;

    // Average match % across users (average of each user's average match across all jobs)
    double totalMatch = 0;
    int pairCount = 0;
    for (final user in widget.users) {
      final skills = _userSkillStrings(user);
      for (final job in widget.jobs) {
        totalMatch += _matchPercent(skills, job.requiredSkills);
        pairCount++;
      }
    }
    final avgMatch = pairCount > 0 ? totalMatch / pairCount : 0.0;

    // Most missing skill: among all required skills, which is missing for the most users
    final allRequired = <String>{};
    for (final job in widget.jobs) {
      for (final s in job.requiredSkills) {
        final n = GapAnalysisService.normalize(s);
        if (n.isNotEmpty) allRequired.add(n);
      }
    }
    final displayNames = <String, String>{};
    for (final job in widget.jobs) {
      for (final s in job.requiredSkills) {
        final n = GapAnalysisService.normalize(s);
        if (n.isNotEmpty) displayNames[n] = s.trim();
      }
    }
    int maxMissing = 0;
    String mostMissingSkill = '—';
    for (final skillNorm in allRequired) {
      int missing = 0;
      for (final user in widget.users) {
        final userSet = _userSkillStrings(
          user,
        ).map((s) => GapAnalysisService.normalize(s)).toSet();
        if (!userSet.contains(skillNorm)) missing++;
      }
      if (missing > maxMissing) {
        maxMissing = missing;
        mostMissingSkill = displayNames[skillNorm] ?? skillNorm;
      }
    }

    // Number of users matching each job (match % > 0)
    final usersPerJob = <String, int>{};
    for (final job in widget.jobs) {
      int count = 0;
      for (final user in widget.users) {
        final skills = _userSkillStrings(user);
        if (_matchPercent(skills, job.requiredSkills) > 0) count++;
      }
      usersPerJob[job.title] = count;
    }
    final jobTitles = widget.jobs.map((j) => j.title).toList();
    final sortedByCount = List<String>.from(jobTitles)
      ..sort((a, b) => (usersPerJob[b] ?? 0).compareTo(usersPerJob[a] ?? 0));
    final topJobs = sortedByCount.take(8).toList();
    final maxUsers = widget.users.isEmpty ? 1 : widget.users.length.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnalyticsCard(
          title: 'Skills Gap Analytics (live)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: widget.chartAnim,
                      builder: (_, __) {
                        final v = avgMatch * widget.chartAnim.value;
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.percent_rounded,
                                    color: primary,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Avg match %',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${v.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                              Text(
                                'across ${widget.users.length} users',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: widget.chartAnim,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppTheme.warning,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Most missing skill',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mostMissingSkill,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1C1E),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$maxMissing users missing',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Users matching each job',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: widget.chartAnim,
                builder: (_, __) {
                  return SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (maxUsers * 1.1 * widget.chartAnim.value).clamp(
                          1.0,
                          double.infinity,
                        ),
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                ),
                              ),
                              interval: (maxUsers / 4).clamp(1.0, 1e6),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i >= 0 && i < topJobs.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Transform.rotate(
                                      angle: -0.5,
                                      child: Text(
                                        topJobs[i].length > 12
                                            ? '${topJobs[i].substring(0, 12)}…'
                                            : topJobs[i],
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 9,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withValues(alpha: 0.2),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: topJobs.asMap().entries.map((e) {
                          final count =
                              (usersPerJob[e.value] ?? 0).toDouble() *
                              widget.chartAnim.value;
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: count,
                                color: secondary,
                                width: 18,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ],
                            showingTooltipIndicators: [],
                          );
                        }).toList(),
                      ),
                      duration: Duration.zero,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyticsOverviewCard extends StatelessWidget {
  final int periodIndex;
  final ValueChanged<int> onPeriodChanged;

  const _AnalyticsOverviewCard({
    required this.periodIndex,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Analytics Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              _DownloadChip(
                label: 'CSV',
                color: AppTheme.success,
                icon: Icons.download_rounded,
              ),
              SizedBox(width: 8),
              _DownloadChip(
                label: 'PDF',
                color: _pdfBlue,
                icon: Icons.download_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PeriodSegment(
                label: 'Week',
                isSelected: periodIndex == 0,
                onTap: () => onPeriodChanged(0),
              ),
              const SizedBox(width: 8),
              _PeriodSegment(
                label: 'Month',
                isSelected: periodIndex == 1,
                onTap: () => onPeriodChanged(1),
              ),
              const SizedBox(width: 8),
              _PeriodSegment(
                label: 'Year',
                isSelected: periodIndex == 2,
                onTap: () => onPeriodChanged(2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _DownloadChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodSegment({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _segmentSelectedBg : _segmentUnselectedBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _MostSelectedJobRolesAnalyticsCard extends StatelessWidget {
  final double screenWidth;
  final List<(String, double)> barData;
  final double totalSelections;

  const _MostSelectedJobRolesAnalyticsCard({
    required this.screenWidth,
    required this.barData,
    required this.totalSelections,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = barData.isEmpty
        ? 100.0
        : (barData.map((e) => e.$2).fold<double>(0, (a, b) => a > b ? a : b) *
                  1.1)
              .clamp(20.0, 500.0);
    final count = barData.length.clamp(1, 10);
    final barWidth = (screenWidth - 32 - 32 - 56) / count * 0.5;

    return _AnalyticsCard(
      title: 'Most Selected Job Roles',
      child: barData.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No job role selections yet. Data is from users\' last_analysis.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                            interval: maxY / 4,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i >= 0 && i < barData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Transform.rotate(
                                    angle: -0.5,
                                    child: Text(
                                      barData[i].$1,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 9,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barData.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.$2,
                              color: _chartPrimary,
                              width: barWidth.clamp(12.0, 24.0),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                          showingTooltipIndicators: [],
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 0),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(barData.length < 3 ? barData.length : 3, (i) {
                  final item = barData[i];
                  final pct = totalSelections > 0
                      ? ((item.$2 / totalSelections) * 100).toStringAsFixed(1)
                      : '0';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: _chartPrimary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          '${item.$2.toInt()} ($pct%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _AssessmentActivityTrendCard extends StatelessWidget {
  final double screenWidth;
  final List<FlSpot> spots;
  final String trendMessage;

  const _AssessmentActivityTrendCard({
    required this.screenWidth,
    required this.spots,
    required this.trendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = spots.isEmpty
        ? 10.0
        : (spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b) * 1.2)
              .clamp(10.0, 500.0);
    final labels = List.generate(spots.length, (i) => 'Week ${i + 1}');

    return _AnalyticsCard(
      title: 'Assessment Activity Trend',
      child: spots.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No assessment activity by week yet. Data from users\' last_analysis_at (last 4 weeks).',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      lineTouchData: const LineTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                            interval: maxY / 4,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i >= 0 && i < labels.length) {
                                return Text(
                                  labels[i],
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 10,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: _chartPrimary,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 0),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _trendBoxBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trendMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3E3A6E),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UsersByAcademicLevelAnalyticsCard extends StatelessWidget {
  final double screenWidth;
  final List<({String label, double percent, int count, Color color})> segments;

  const _UsersByAcademicLevelAnalyticsCard({
    required this.screenWidth,
    required this.segments,
  });

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Users by Academic Level',
      child: segments.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No academic level data yet. Data from users\' academic_year.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 48,
                      sections: segments.map((s) {
                        return PieChartSectionData(
                          value: s.percent.clamp(0.1, 100),
                          color: s.color,
                          radius: 44,
                          showTitle: false,
                        );
                      }).toList(),
                    ),
                    duration: const Duration(milliseconds: 0),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: segments.map((s) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.label}: ${s.count}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

class _MostFrequentlyAddedSkillsCard extends StatelessWidget {
  final List<(String, int)> topSkills;

  const _MostFrequentlyAddedSkillsCard({required this.topSkills});

  @override
  Widget build(BuildContext context) {
    final maxCount = topSkills.isEmpty
        ? 1
        : topSkills.map((e) => e.$2).fold(0, (a, b) => a > b ? a : b);

    return _AnalyticsCard(
      title: 'Most Frequently Added Skills',
      child: topSkills.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No skills data yet. Data from users\' skills lists.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: topSkills.asMap().entries.map((e) {
                final name = e.value.$1;
                final count = e.value.$2;
                final progress = count / maxCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: _chartPrimary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _chartPrimary,
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _chartPrimary,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _JobCategoryDistributionCard extends StatelessWidget {
  final List<(String, int)> distribution;

  const _JobCategoryDistributionCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Category Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          ...(distribution.isEmpty
              ? [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No job categories yet. Data from jobs collection.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ]
              : distribution.map((e) {
                  final label = e.$1;
                  final percent = e.$2;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (percent / 100).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _chartPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()),
        ],
      ),
    );
  }
}

class _KeyInsightsSummaryCard extends StatelessWidget {
  final List<String> insights;

  const _KeyInsightsSummaryCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B4B9E), Color(0xFF3949AB)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _chartPrimary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: Colors.white.withValues(alpha: 0.95),
                size: 22,
              ),
              const SizedBox(width: 8),
              const Text(
                'Key Insights Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...(insights.isEmpty
              ? [
                  Text(
                    'Complete analyses and user data to see insights here.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.4,
                    ),
                  ),
                ]
              : insights.map((String insight) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            insight,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.95),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()),
        ],
      ),
    );
  }
}
