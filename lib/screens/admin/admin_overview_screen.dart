import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';
import 'admin_jobs_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_skills_screen.dart';
import 'admin_users_screen.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  int _selectedTabIndex = 0;
  late Future<_AdminOverviewKpis> _kpisFuture;
  late Future<_AdminOverviewCharts> _chartsFuture;
  static const List<({String label, IconData icon})> _tabs = [
    (label: 'Overview', icon: Icons.dashboard_rounded),
    (label: 'Jobs', icon: Icons.work_outline_rounded),
    (label: 'Users', icon: Icons.people_outline_rounded),
    (label: 'Analytics', icon: Icons.analytics_outlined),
    (label: 'Skills', icon: Icons.school_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _kpisFuture = _loadLiveKpis();
    _chartsFuture = _loadLiveCharts();
  }

  Future<_AdminOverviewKpis> _loadLiveKpis() async {
    final usersFuture = FirebaseFirestore.instance.collection('users').get();
    final jobsFuture = FirebaseFirestore.instance.collection('jobs').get();
    final skillsFuture = FirebaseFirestore.instance.collection('skills').get();

    final usersSnap = await usersFuture;
    final jobsSnap = await jobsFuture;
    final skillsSnap = await skillsFuture;

    var highDemandSkills = 0;
    for (final doc in skillsSnap.docs) {
      final demand = doc.data()['demandLevel']?.toString().trim() ?? '';
      if (demand == 'Very High' || demand == 'High') {
        highDemandSkills++;
      }
    }

    return _AdminOverviewKpis(
      totalUsers: usersSnap.size,
      activeJobs: jobsSnap.size,
      totalSkills: skillsSnap.size,
      highDemandSkills: highDemandSkills,
    );
  }

  Future<_AdminOverviewCharts> _loadLiveCharts() async {
    final jobsFuture = FirebaseFirestore.instance.collection('jobs').get();
    final usersFuture = FirebaseFirestore.instance.collection('users').get();

    final jobsSnap = await jobsFuture;
    final usersSnap = await usersFuture;

    final roleCounts = <String, int>{};
    for (final doc in jobsSnap.docs) {
      final title = doc.data()['title']?.toString().trim() ?? '';
      if (title.isEmpty) continue;
      roleCounts[title] = (roleCounts[title] ?? 0) + 1;
    }
    final topRoles = roleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRoleBars = topRoles.take(3).map((e) {
      return _BarDatum(label: e.key, value: e.value.toDouble());
    }).toList();

    final now = DateTime.now();
    final weekDays = List<DateTime>.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)),
    );
    final weekCounts = List<int>.filled(7, 0);
    for (final doc in usersSnap.docs) {
      final raw = doc.data()['last_analysis_at'];
      if (raw is! Timestamp) continue;
      final t = raw.toDate();
      final day = DateTime(t.year, t.month, t.day);
      for (var i = 0; i < weekDays.length; i++) {
        if (day == weekDays[i]) {
          weekCounts[i] += 1;
          break;
        }
      }
    }
    final weekLabels = weekDays
        .map((d) => _weekdayShortLabel(d.weekday))
        .toList();
    final weeklyValues = weekCounts.map((c) => c.toDouble()).toList();

    var bachelor = 0;
    var master = 0;
    var phd = 0;
    var other = 0;
    for (final doc in usersSnap.docs) {
      final y = doc.data()['academic_year']?.toString().trim().toLowerCase() ?? '';
      if (y.contains('bachelor')) {
        bachelor++;
      } else if (y.contains('master')) {
        master++;
      } else if (y.contains('phd') || y.contains('doctor')) {
        phd++;
      } else {
        other++;
      }
    }
    final total = (bachelor + master + phd + other);
    double pct(int c) => total == 0 ? 0 : (c * 100.0 / total);
    final academicSegments = <_PieDatum>[
      _PieDatum(label: 'Bachelor', percent: pct(bachelor), color: const Color(0xFF6B5BAE)),
      _PieDatum(label: 'Master', percent: pct(master), color: const Color(0xFF2A6CFF)),
      _PieDatum(label: 'PhD', percent: pct(phd), color: const Color(0xFF1565C0)),
      _PieDatum(label: 'Other', percent: pct(other), color: const Color(0xFF2E7D32)),
    ];

    return _AdminOverviewCharts(
      topRoles: topRoleBars,
      weeklyLabels: weekLabels,
      weeklyValues: weeklyValues,
      academicSegments: academicSegments,
    );
  }

  static String _weekdayShortLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
        return 'Sun';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0;
    const cardSpacing = 12.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header (theme colors)
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding + 12,
              horizontalPadding,
              14,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary, theme.colorScheme.secondary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'GradReady Management',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () async {
                        await AuthService.signOut();
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Tabs
                Row(
                  children: List.generate(_tabs.length, (i) {
                    final isSelected = _selectedTabIndex == i;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: i < _tabs.length - 1 ? 6 : 0,
                        ),
                        child: Material(
                          color: isSelected
                              ? theme.colorScheme.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => setState(() => _selectedTabIndex = i),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _tabs[i].icon,
                                    size: 20,
                                    color: isSelected ? primary : Colors.white,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _tabs[i].label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? primary
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _selectedTabIndex == 0
                ? SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      20 + bottomPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary stat cards 2x2 (live from Firestore)
                        FutureBuilder<_AdminOverviewKpis>(
                          future: _kpisFuture,
                          builder: (context, snapshot) {
                            final kpis = snapshot.data;
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.people_outline_rounded,
                                        iconColor: primary,
                                        label: 'Total Users',
                                        value: kpis != null
                                            ? _formatCount(kpis.totalUsers)
                                            : '...',
                                      ),
                                    ),
                                    const SizedBox(width: cardSpacing),
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.school_rounded,
                                        iconColor: primary,
                                        label: 'Total Skills',
                                        value: kpis != null
                                            ? _formatCount(kpis.totalSkills)
                                            : '...',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: cardSpacing),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.work_outline_rounded,
                                        iconColor: AppTheme.success,
                                        label: 'Active Jobs',
                                        value: kpis != null
                                            ? _formatCount(kpis.activeJobs)
                                            : '...',
                                      ),
                                    ),
                                    const SizedBox(width: cardSpacing),
                                    Expanded(
                                      child: _StatCard(
                                        icon: Icons.local_fire_department_rounded,
                                        iconColor: theme.colorScheme.secondary,
                                        label: 'High Demand Skills',
                                        value: kpis != null
                                            ? _formatCount(kpis.highDemandSkills)
                                            : '...',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        // Most selected roles
                        _SectionCard(
                          title: 'Most Selected Job Roles',
                          child: FutureBuilder<_AdminOverviewCharts>(
                            future: _chartsFuture,
                            builder: (context, snapshot) {
                              final data = snapshot.data?.topRoles ?? const <_BarDatum>[];
                              return SizedBox(
                                height: 200,
                                child: _MostSelectedJobRolesChart(
                                  screenWidth: screenWidth,
                                  data: data,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Weekly activity
                        _SectionCard(
                          title: 'Weekly Assessment Activity',
                          child: FutureBuilder<_AdminOverviewCharts>(
                            future: _chartsFuture,
                            builder: (context, snapshot) {
                              final labels = snapshot.data?.weeklyLabels ?? const <String>[];
                              final values = snapshot.data?.weeklyValues ?? const <double>[];
                              return SizedBox(
                                height: 180,
                                child: _WeeklyActivityChart(
                                  labels: labels,
                                  values: values,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Users by academic level
                        _SectionCard(
                          title: 'Users by Academic Level',
                          child: FutureBuilder<_AdminOverviewCharts>(
                            future: _chartsFuture,
                            builder: (context, snapshot) {
                              final segments = snapshot.data?.academicSegments ?? const <_PieDatum>[];
                              return _AcademicLevelDonut(segments: segments);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Quick Insights
                        _QuickInsightsCard(),
                      ],
                    ),
                  )
                : _selectedTabIndex == 1
                ? const AdminJobsContent()
                : _selectedTabIndex == 2
                ? const AdminUsersContent()
                : _selectedTabIndex == 3
                ? const AdminAnalyticsContent()
                : const AdminSkillsContent(),
          ),
        ],
      ),
    );
  }

  static String _formatCount(int value) {
    final s = value.toString();
    if (s.length <= 3) return s;
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      out.write(s[i]);
      final remaining = s.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) out.write(',');
    }
    return out.toString();
  }
}

class _AdminOverviewKpis {
  final int totalUsers;
  final int totalSkills;
  final int activeJobs;
  final int highDemandSkills;

  const _AdminOverviewKpis({
    required this.totalUsers,
    required this.totalSkills,
    required this.activeJobs,
    required this.highDemandSkills,
  });
}

class _AdminOverviewCharts {
  final List<_BarDatum> topRoles;
  final List<String> weeklyLabels;
  final List<double> weeklyValues;
  final List<_PieDatum> academicSegments;

  const _AdminOverviewCharts({
    required this.topRoles,
    required this.weeklyLabels,
    required this.weeklyValues,
    required this.academicSegments,
  });
}

class _BarDatum {
  final String label;
  final double value;

  const _BarDatum({
    required this.label,
    required this.value,
  });
}

class _PieDatum {
  final String label;
  final double percent;
  final Color color;

  const _PieDatum({
    required this.label,
    required this.percent,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 26),
            ],
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

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

class _MostSelectedJobRolesChart extends StatelessWidget {
  final double screenWidth;
  final List<_BarDatum> data;

  const _MostSelectedJobRolesChart({
    required this.screenWidth,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('No role selection data yet.'),
      );
    }
    final maxValue = data
        .map((d) => d.value)
        .reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue <= 0 ? 10.0 : maxValue * 1.2);
    final interval = (maxY / 4).clamp(1, 1000000).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              interval: interval,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[i].label,
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: Theme.of(context).colorScheme.primary,
                width: (screenWidth - 32 - 48) / 3 * 0.45,
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
    );
  }
}

class _WeeklyActivityChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;

  const _WeeklyActivityChart({
    required this.labels,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || labels.isEmpty) {
      return const Center(
        child: Text('No weekly activity yet.'),
      );
    }

    final spots = values
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue <= 0 ? 5.0 : maxValue * 1.25);
    final interval = (maxY / 4).clamp(1, 1000000).toDouble();

    return LineChart(
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
                style: const TextStyle(color: Colors.grey, fontSize: 10),
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
                if (i >= 0 && i < labels.length) {
                  return Text(
                    labels[i],
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
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
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 0),
    );
  }
}

class _AcademicLevelDonut extends StatelessWidget {
  final List<_PieDatum> segments;

  const _AcademicLevelDonut({required this.segments});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty || segments.every((s) => s.percent <= 0)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('No academic distribution data yet.'),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 48,
              sections: segments.map((s) {
                return PieChartSectionData(
                  value: s.percent,
                  color: s.color,
                  radius: 44,
                  showTitle: false,
                );
              }).toList(),
            ),
            duration: const Duration(milliseconds: 0),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          alignment: WrapAlignment.center,
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
                  '${s.label}: ${s.percent.toInt()}%',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _QuickInsightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const bullets = [
      'Frontend Developer is the most popular career choice (342 selections)',
      'Machine Learning has the largest skill gap across users (42%)',
      'User engagement peaks on Thursdays with 61 assessments',
      '45% of users hold Bachelor\'s degrees',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Quick Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
