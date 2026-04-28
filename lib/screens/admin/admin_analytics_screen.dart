import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';
import '../../models/job_document.dart';
import '../../services/firestore_service.dart';
import '../../services/gap_analysis_service.dart';
import '../../widgets/error_boundary.dart';

// Theme colors + fixed accent colors (mock-aligned)
const Color _pageBg = Color(0xFFF5F7F9);
const Color _segmentSelectedBg = Color(0xFF5B4B9E);
const Color _segmentUnselectedBg = Color(0xFFF0F0F0);
const Color _trendBoxBg = Color(0xFFE8EEF9);
const Color _chartPrimary = Color(0xFF5B4B9E);
const Color _lineChartBlue = Color(0xFF2196F3);
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

/// 1. Most Selected Job Roles: count users by [last_analysis] title (any value, not only catalog jobs).
String _analysisTitle(Map<String, dynamic> user) {
  final last = user['last_analysis'];
  if (last is Map) {
    final title = last['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
  }
  final legacy = user['last_analysis_title']?.toString().trim();
  if (legacy != null && legacy.isNotEmpty) return legacy;
  return last?.toString().trim() ?? '';
}

List<(String, double)> computeMostSelectedJobRoles(
  List<Map<String, dynamic>> users,
  List<JobDocument> jobs, {
  int top = 7,
}) {
  final countByTitle = <String, int>{};
  for (final u in users) {
    final last = _analysisTitle(u);
    if (last.isEmpty) continue;
    countByTitle[last] = (countByTitle[last] ?? 0) + 1;
  }
  if (countByTitle.isEmpty && jobs.isNotEmpty) {
    for (final j in jobs) {
      countByTitle[j.title] = 0;
    }
  }
  final sorted = countByTitle.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(top).map((e) => (e.key, e.value.toDouble())).toList();
}

double computeTotalSelections(List<Map<String, dynamic>> users) {
  int n = 0;
  for (final u in users) {
    if (_analysisTitle(u).isNotEmpty) n++;
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
      final name = _skillNameOrId(s);
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

String _skillNameOrId(dynamic raw) {
  if (raw is String) return raw.trim();
  if (raw is! Map) return '';
  final name = (raw['name']?.toString() ?? '').trim();
  if (name.isNotEmpty) return name;
  return (raw['skillId']?.toString() ?? '').trim();
}

double computeUserSuccessRate(List<Map<String, dynamic>> users) {
  int qualifiedCount = 0;
  int totalWithAnalysis = 0;
  for (final u in users) {
    final last = u['last_analysis'];
    if (last is Map) {
      totalWithAnalysis++;
      if (last['isQualified'] == true) {
        qualifiedCount++;
      }
    }
  }
  if (totalWithAnalysis == 0) return 0.0;
  return (qualifiedCount / totalWithAnalysis) * 100;
}

List<(String, int)> computeMostMissingMandatorySkills(
  List<Map<String, dynamic>> users, {
  int top = 5,
}) {
  final count = <String, int>{};
  for (final u in users) {
    final last = u['last_analysis'];
    if (last is Map) {
      final missing = last['missingMandatorySkills'] as List?;
      if (missing != null) {
        for (final m in missing) {
          final s = m.toString().trim();
          if (s.isNotEmpty) {
            count[s] = (count[s] ?? 0) + 1;
          }
        }
      }
    }
  }
  final sorted = count.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(top).map((e) => (e.key, e.value)).toList();
}

List<(String, int)> computeTopDemandedSkills(
  List<JobDocument> jobs, {
  int top = 5,
}) {
  final count = <String, int>{};
  for (final j in jobs) {
    for (final s in j.technicalSkills) {
      if (s.priority == 'Critical') {
        count[s.name] = (count[s.name] ?? 0) + 1;
      }
    }
    for (final s in j.softSkills) {
      if (s.priority == 'Critical') {
        count[s.name] = (count[s.name] ?? 0) + 1;
      }
    }
    for (final s in j.tools) {
      if (s.priority == 'Critical') {
        count[s.name] = (count[s.name] ?? 0) + 1;
      }
    }
  }
  final sorted = count.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(top).map((e) => (e.key, e.value)).toList();
}

/// 4. Job Category Distribution: from jobs collection, group by category, percent of total.
List<(String, int)> computeCategoryDistribution(List<JobDocument> jobs) {
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

DateTime? _analysisAt(Map<String, dynamic> u) {
  final t = u['last_analysis_at'];
  if (t is Timestamp) return t.toDate();
  return null;
}

/// 5. Assessment activity buckets by period: 0=week (8 buckets), 1=month (6), 2=year (12 months).
({List<FlSpot> spots, List<String> labels}) computeActivityTrendSeries(
  List<Map<String, dynamic>> users,
  int periodIndex,
) {
  final now = DateTime.now();
  if (periodIndex == 0) {
    const weeks = 8;
    final buckets = List<int>.filled(weeks, 0);
    for (final u in users) {
      final dt = _analysisAt(u);
      if (dt == null) continue;
      final diff = now.difference(dt).inDays;
      if (diff < 0) continue;
      final weekIndex = (diff / 7).floor();
      if (weekIndex >= weeks) continue;
      buckets[weeks - 1 - weekIndex]++;
    }
    final spots = List.generate(
      weeks,
      (i) => FlSpot(i.toDouble(), buckets[i].toDouble()),
    );
    final labels = List.generate(weeks, (i) => 'Week ${i + 1}');
    return (spots: spots, labels: labels);
  }
  if (periodIndex == 1) {
    const months = 6;
    final buckets = List<int>.filled(months, 0);
    for (final u in users) {
      final dt = _analysisAt(u);
      if (dt == null) continue;
      final diffMonth = (now.year - dt.year) * 12 + now.month - dt.month;
      if (diffMonth < 0 || diffMonth >= months) continue;
      buckets[months - 1 - diffMonth]++;
    }
    final spots = List.generate(
      months,
      (i) => FlSpot(i.toDouble(), buckets[i].toDouble()),
    );
    final labels = List.generate(months, (i) {
      final d = DateTime(now.year, now.month - (months - 1 - i), 1);
      return '${d.month}/${d.year % 100}';
    });
    return (spots: spots, labels: labels);
  }
  final buckets = List<int>.filled(12, 0);
  for (final u in users) {
    final dt = _analysisAt(u);
    if (dt == null) continue;
    final diffMonth = (now.year - dt.year) * 12 + now.month - dt.month;
    if (diffMonth < 0 || diffMonth >= 12) continue;
    buckets[11 - diffMonth]++;
  }
  final spots = List.generate(
    12,
    (i) => FlSpot(i.toDouble(), buckets[i].toDouble()),
  );
  final labels = List.generate(12, (i) {
    final d = DateTime(now.year, now.month - (11 - i), 1);
    return _monthShort(d.month);
  });
  return (spots: spots, labels: labels);
}

String _monthShort(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[(m - 1).clamp(0, 11)];
}

String computeActivityTrendMessage(
  List<FlSpot> spots,
  int periodIndex,
) {
  if (spots.length < 2) {
    return 'Trend: Add more activity data to see trends.';
  }
  final firstHalf = spots.take(spots.length ~/ 2).fold<double>(0, (s, sp) => s + sp.y);
  final secondHalf = spots.skip(spots.length ~/ 2).fold<double>(0, (s, sp) => s + sp.y);
  final span = periodIndex == 0
      ? '${spots.length} weeks'
      : periodIndex == 1
          ? '${spots.length} months'
          : '12 months';
  if (firstHalf == 0 && secondHalf == 0) {
    return 'Trend: No assessment activity in this period yet.';
  }
  if (firstHalf == 0) {
    return 'Trend: Assessment activity increased over the last $span.';
  }
  final pct = ((secondHalf - firstHalf) / firstHalf * 100).round();
  if (pct >= 0) {
    return 'Trend: Assessment activity increased by $pct% over the last $span.';
  }
  return 'Trend: Assessment activity decreased by ${-pct}% over the last $span.';
}

/// 6. Key Insights Summary: generated from real analytics.
List<String> computeKeyInsights({
  required List<Map<String, dynamic>> users,
  required List<JobDocument> jobs,
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

/// Admin Analytics tab content.
class AdminAnalyticsContent extends StatefulWidget {
  const AdminAnalyticsContent({super.key});

  @override
  State<AdminAnalyticsContent> createState() => _AdminAnalyticsContentState();
}

class _AdminAnalyticsContentState extends State<AdminAnalyticsContent> {
  int _periodIndex = 0; // 0=Week, 1=Month, 2=Year

  final FirestoreService _firestore = FirestoreService();
  List<Map<String, dynamic>>? _users;
  List<JobDocument>? _jobs;
  Object? _usersError;
  Object? _jobsError;

  StreamSubscription<List<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<List<JobDocument>>? _jobsSub;

  @override
  void initState() {
    super.initState();
    _usersSub = _firestore.streamUsersForAnalytics().listen(
      (list) {
        if (mounted) {
          setState(() {
            _users = list;
            _usersError = null;
          });
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _users = <Map<String, dynamic>>[];
            _usersError = e;
          });
        }
      },
    );
    _jobsSub = _firestore.getJobDocuments().listen(
      (list) {
        if (mounted) {
          setState(() {
            _jobs = list;
            _jobsError = null;
          });
        }
      },
      onError: (Object e) {
        if (mounted) {
          setState(() {
            _jobs = <JobDocument>[];
            _jobsError = e;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _jobsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const horizontalPadding = 16.0;

    if (_users == null || _jobs == null) {
      return const ColoredBox(
        color: _pageBg,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      );
    }

    final users = _users!;
    final jobs = _jobs!;

    final jobRolesBarData = computeMostSelectedJobRoles(users, jobs);
    final totalSelections = computeTotalSelections(users);
    final academicSegments = computeAcademicSegments(users);
    final topSkills = computeMostFrequentSkills(users);
    Object? categoryDistributionError;
    List<(String, int)> categoryDistribution;
    try {
      categoryDistribution = computeCategoryDistribution(jobs);
    } catch (e) {
      categoryDistributionError = e;
      categoryDistribution = [];
    }
    final activitySeries = computeActivityTrendSeries(users, _periodIndex);
    final activityTrendMessage = computeActivityTrendMessage(
      activitySeries.spots,
      _periodIndex,
    );

    final userSuccessRate = computeUserSuccessRate(users);
    final mostMissingMandatorySkills = computeMostMissingMandatorySkills(users);
    final topDemandedSkills = computeTopDemandedSkills(jobs);

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

    return ColoredBox(
      color: _pageBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          14,
          horizontalPadding,
          20 + bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_usersError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AnalyticsPermissionBanner(
                  label: 'Users',
                  error: _usersError,
                ),
              ),
            if (_jobsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AnalyticsPermissionBanner(
                  label: 'Jobs',
                  error: _jobsError,
                ),
              ),
            _AnalyticsPeriodFilterCard(
              periodIndex: _periodIndex,
              onPeriodChanged: (i) {
                if (_periodIndex == i) return;
                setState(() => _periodIndex = i);
              },
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
              spots: activitySeries.spots,
              bottomLabels: activitySeries.labels,
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
            ErrorBoundary(
              error: categoryDistributionError,
              errorBuilder: (_) => Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Data loading...',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ),
              child: _JobCategoryDistributionCard(
                distribution: categoryDistribution,
              ),
            ),
            const SizedBox(height: 16),
            _UserSuccessRateCard(successRate: userSuccessRate),
            const SizedBox(height: 16),
            _TopDemandedSkillsCard(skills: topDemandedSkills),
            const SizedBox(height: 16),
            _MostMissingMandatorySkillsCard(skills: mostMissingMandatorySkills),
            const SizedBox(height: 16),
            _KeyInsightsSummaryCard(insights: keyInsights),
          ],
        ),
      ),
    );
  }
}

/// Shown when the users or jobs stream fails; partial analytics may still load.
class _AnalyticsPermissionBanner extends StatelessWidget {
  final String label;
  final Object? error;

  const _AnalyticsPermissionBanner({
    required this.label,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final msg = error?.toString() ?? 'Unknown error';
    final isPermission =
        msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED');
    final border = theme.colorScheme.error.withValues(alpha: 0.4);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPermission
                      ? 'Cannot load $label (Firestore permission denied)'
                      : 'Could not load $label',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            msg.length > 320 ? '${msg.substring(0, 320)}…' : msg,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isPermission) ...[
            const SizedBox(height: 12),
            Text(
              'To fix admin access:\n'
              '• In Firebase Console → Firestore, create collection `admins` and a document whose ID is your user UID (from Authentication).\n'
              '• Deploy rules: `firebase deploy --only firestore:rules`\n'
              '• Sign out and sign in so the client refreshes. Or use the `makeAdmin` callable function if another admin exists.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
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
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Week / Month / Year filter (mock: white bar, purple selected).
class _AnalyticsPeriodFilterCard extends StatelessWidget {
  final int periodIndex;
  final ValueChanged<int> onPeriodChanged;

  const _AnalyticsPeriodFilterCard({
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _PeriodSegment(
              label: 'Week',
              isSelected: periodIndex == 0,
              onTap: () => onPeriodChanged(0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PeriodSegment(
              label: 'Month',
              isSelected: periodIndex == 1,
              onTap: () => onPeriodChanged(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PeriodSegment(
              label: 'Year',
              isSelected: periodIndex == 2,
              onTap: () => onPeriodChanged(2),
            ),
          ),
        ],
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
                      barTouchData: BarTouchData(enabled: true),
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
  final List<String> bottomLabels;
  final String trendMessage;

  const _AssessmentActivityTrendCard({
    required this.screenWidth,
    required this.spots,
    required this.bottomLabels,
    required this.trendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = spots.isEmpty
        ? 10.0
        : (spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b) * 1.15)
              .clamp(10.0, 500.0);
    final interval = maxY > 0 ? (maxY / 4).clamp(1.0, 1e6) : 1.0;

    return _AnalyticsCard(
      title: 'Assessment Activity Trend',
      child: spots.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No assessment activity in this period. Data uses users\' last_analysis_at.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      lineTouchData: const LineTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                            interval: interval,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i >= 0 &&
                                  i < bottomLabels.length &&
                                  i < spots.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    bottomLabels[i],
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 10,
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
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.withValues(alpha: 0.25),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: _lineChartBlue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (s, p, bar, i) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: _lineChartBlue,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
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
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _trendBoxBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _TrendRichText(message: trendMessage),
                ),
              ],
            ),
    );
  }
}

class _TrendRichText extends StatelessWidget {
  final String message;

  const _TrendRichText({required this.message});

  @override
  Widget build(BuildContext context) {
    const prefix = 'Trend:';
    if (message.startsWith(prefix)) {
      final rest = message.substring(prefix.length).trimLeft();
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: Color(0xFF1565C0),
          ),
          children: [
            const TextSpan(
              text: '$prefix ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: rest),
        ],
        ),
      );
    }
    return Text(
      message,
      style: const TextStyle(
        fontSize: 13,
        height: 1.4,
        color: Color(0xFF1565C0),
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
                ...List.generate((segments.length / 2).ceil(), (row) {
                  final i0 = row * 2;
                  final i1 = i0 + 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _AcademicLegendItem(segment: segments[i0]),
                        ),
                        if (i1 < segments.length)
                          Expanded(
                            child: _AcademicLegendItem(segment: segments[i1]),
                          )
                        else
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _AcademicLegendItem extends StatelessWidget {
  final ({String label, double percent, int count, Color color}) segment;

  const _AcademicLegendItem({required this.segment});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: segment.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${segment.label}: ${segment.percent.toStringAsFixed(0)}% (${segment.count})',
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Colors.black87,
            ),
          ),
        ),
      ],
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
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
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
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _chartPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            _chartPrimary,
                          ),
                          minHeight: 10,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
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
              color: Color(0xFF1A1C1E),
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

class _UserSuccessRateCard extends StatelessWidget {
  final double successRate;

  const _UserSuccessRateCard({required this.successRate});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'User Success Rate (Qualified)',
      child: Center(
        child: Column(
          children: [
            Text(
              '${successRate.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Percentage of users meeting mandatory requirements',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopDemandedSkillsCard extends StatelessWidget {
  final List<(String, int)> skills;

  const _TopDemandedSkillsCard({required this.skills});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Top Demanded Critical Skills',
      child: skills.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No critical skills found in jobs.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: skills.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.$1,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${e.$2} jobs',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _MostMissingMandatorySkillsCard extends StatelessWidget {
  final List<(String, int)> skills;

  const _MostMissingMandatorySkillsCard({required this.skills});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Most Missing Mandatory Skills',
      child: skills.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No missing mandatory skills data yet.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              children: skills.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[400], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.$1,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${e.$2} users',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
