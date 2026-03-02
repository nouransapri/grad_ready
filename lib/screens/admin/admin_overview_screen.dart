import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';
import '../login_screen.dart';
import 'admin_jobs_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_market_screen.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  int _selectedTabIndex = 0;
  static const List<({String label, IconData icon})> _tabs = [
    (label: 'Overview', icon: Icons.dashboard_rounded),
    (label: 'Jobs', icon: Icons.work_outline_rounded),
    (label: 'Analytics', icon: Icons.analytics_outlined),
    (label: 'Market', icon: Icons.storage_rounded),
  ];

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
          // الهيدر (ألوان الثيم)
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding + 12, horizontalPadding, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primary,
                  theme.colorScheme.secondary,
                ],
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
                        const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
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
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // التبويبات
                Row(
                  children: List.generate(_tabs.length, (i) {
                    final isSelected = _selectedTabIndex == i;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 6 : 0),
                        child: Material(
                          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
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
                                      color: isSelected ? primary : Colors.white,
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
          // المحتوى
          Expanded(
            child: _selectedTabIndex == 0
                ? SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 20 + bottomPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // بطاقات الملخص 2x2
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.people_outline_rounded,
                                iconColor: primary,
                                label: 'Total Users',
                                value: '1,247',
                                badge: null,
                              ),
                            ),
                            const SizedBox(width: cardSpacing),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.person_add_alt_1_rounded,
                                iconColor: primary,
                                label: 'New This Month',
                                value: '183',
                                badge: '+14.7%',
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
                                label: 'Job Roles',
                                value: '32',
                                badge: null,
                              ),
                            ),
                            const SizedBox(width: cardSpacing),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.assessment_rounded,
                                iconColor: theme.colorScheme.secondary,
                                label: 'Assessments',
                                value: '3,891',
                                badge: null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // أكثر الأدوار اختياراً
                        _SectionCard(
                          title: 'Most Selected Job Roles',
                          child: SizedBox(
                            height: 200,
                            child: _MostSelectedJobRolesChart(screenWidth: screenWidth),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // النشاط الأسبوعي
                        _SectionCard(
                          title: 'Weekly Assessment Activity',
                          child: SizedBox(
                            height: 180,
                            child: _WeeklyActivityChart(screenWidth: screenWidth),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // المستخدمون حسب المستوى الأكاديمي
                        _SectionCard(
                          title: 'Users by Academic Level',
                          child: _AcademicLevelDonut(screenWidth: screenWidth),
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
                        ? const AdminAnalyticsContent()
                        : _selectedTabIndex == 3
                            ? const AdminMarketContent()
                            : Center(
                                child: Text(
                                  '${_tabs[_selectedTabIndex].label} – Coming soon',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? badge;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.badge,
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
                if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
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

  const _MostSelectedJobRolesChart({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    const data = [
      ('Frontend Dev', 330.0),
      ('UX Designer', 280.0),
      ('Product Mgr', 240.0),
    ];
    const maxY = 360.0;

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
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
              interval: 90,
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
                      data[i].$1,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 90,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.$2,
                color: Theme.of(context).colorScheme.primary,
                width: (screenWidth - 32 - 48) / 3 * 0.45,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
  final double screenWidth;

  const _WeeklyActivityChart({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const values = [45.0, 50.0, 45.0, 62.0, 55.0, 38.0, 30.0];

    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 80,
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
              interval: 20,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < days.length) {
                  return Text(
                    days[i],
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
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
  final double screenWidth;

  const _AcademicLevelDonut({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    const segments = [
      (label: 'Bachelor', percent: 45.0, color: Color(0xFF6B5BAE)),
      (label: 'Master', percent: 30.0, color: Color(0xFF2A6CFF)),
      (label: 'PhD', percent: 10.0, color: Color(0xFF1565C0)),
      (label: 'Other', percent: 15.0, color: Color(0xFF2E7D32)),
    ];

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
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
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
                  const Text('• ', style: TextStyle(color: Colors.white, fontSize: 14)),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
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
