import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../app_theme.dart';

// ألوان من الثيم + ثابتة للعناصر
const Color _segmentSelectedBg = Color(0xFF5B4B9E);
const Color _segmentUnselectedBg = Color(0xFFF5F5F5);
const Color _trendBoxBg = Color(0xFFE8E4F5);
const Color _chartPrimary = Color(0xFF5B4B9E);
const Color _pdfBlue = Color(0xFF2196F3);

/// محتوى تبويب Analytics في لوحة الأدمن.
class AdminAnalyticsContent extends StatefulWidget {
  const AdminAnalyticsContent({super.key});

  @override
  State<AdminAnalyticsContent> createState() => _AdminAnalyticsContentState();
}

class _AdminAnalyticsContentState extends State<AdminAnalyticsContent> {
  int _periodIndex = 0; // 0=Week, 1=Month, 2=Year

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const horizontalPadding = 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 14, horizontalPadding, 20 + bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Analytics Overview
          _AnalyticsOverviewCard(
            periodIndex: _periodIndex,
            onPeriodChanged: (i) => setState(() => _periodIndex = i),
          ),
          const SizedBox(height: 16),
          // Most Selected Job Roles
          _MostSelectedJobRolesAnalyticsCard(screenWidth: screenWidth),
          const SizedBox(height: 16),
          // Assessment Activity Trend
          _AssessmentActivityTrendCard(screenWidth: screenWidth),
          const SizedBox(height: 16),
          // Users by Academic Level (Analytics version with legend counts)
          _UsersByAcademicLevelAnalyticsCard(screenWidth: screenWidth),
          const SizedBox(height: 16),
          // Most Frequently Added Skills
          _MostFrequentlyAddedSkillsCard(),
          const SizedBox(height: 16),
          // Job Category Distribution
          _JobCategoryDistributionCard(),
          const SizedBox(height: 16),
          // Key Insights Summary
          _KeyInsightsSummaryCard(),
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
          Row(
            children: [
              const Text(
                'Analytics Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              _DownloadChip(label: 'CSV', color: AppTheme.success, icon: Icons.download_rounded),
              const SizedBox(width: 8),
              _DownloadChip(label: 'PDF', color: _pdfBlue, icon: Icons.download_rounded),
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

  const _DownloadChip({required this.label, required this.color, required this.icon});

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
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
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

  const _PeriodSegment({required this.label, required this.isSelected, required this.onTap});

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

// بيانات أدوار الأكثر اختياراً (7 أدوار + قائمة مصنفة)
const _jobRolesBarData = [
  ('Frontend Developer', 342.0),
  ('Data Analyst', 298.0),
  ('UX Designer', 267.0),
  ('Backend Developer', 245.0),
  ('Product Manager', 228.0),
  ('Full Stack Dev', 210.0),
  ('Data Scientist', 195.0),
];
const _totalSelections = 2247.0;

class _MostSelectedJobRolesAnalyticsCard extends StatelessWidget {
  final double screenWidth;

  const _MostSelectedJobRolesAnalyticsCard({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final maxY = 360.0;
    final barWidth = (screenWidth - 32 - 32 - 56) / 7 * 0.5;

    return _AnalyticsCard(
      title: 'Most Selected Job Roles',
      child: Column(
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                      interval: 90,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= 0 && i < _jobRolesBarData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                _jobRolesBarData[i].$1,
                                style: TextStyle(color: Colors.grey[700], fontSize: 9),
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
                barGroups: _jobRolesBarData.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.$2,
                        color: _chartPrimary,
                        width: barWidth.clamp(12.0, 24.0),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
          // Top 3 ranked list
          ...List.generate(3, (i) {
            final item = _jobRolesBarData[i];
            final pct = ((item.$2 / _totalSelections) * 100).toStringAsFixed(1);
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
                    '${item.$2.toInt()} (${pct}%)',
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

// Assessment Activity Trend: line chart + trend summary
final _activitySpots = [
  FlSpot(0, 85),
  FlSpot(1, 110),
  FlSpot(2, 145),
  FlSpot(3, 195),
];

class _AssessmentActivityTrendCard extends StatelessWidget {
  final double screenWidth;

  const _AssessmentActivityTrendCard({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Assessment Activity Trend',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 220,
                lineTouchData: LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                      ),
                      interval: 55,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Week 2', 'Week 4', 'Week 6', 'Week 8'];
                        final i = value.toInt();
                        if (i >= 0 && i < labels.length) {
                          return Text(
                            labels[i],
                            style: TextStyle(color: Colors.grey[700], fontSize: 10),
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
                  horizontalInterval: 55,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _activitySpots,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _trendBoxBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Trend: Assessment activity increased by 47% over the last 8 weeks',
              style: TextStyle(
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

const _academicSegments = [
  (label: "Bachelor's", percent: 30.0, count: 561, color: Color(0xFF6B5BAE)),
  (label: "Master's", percent: 25.0, count: 374, color: Color(0xFF5B4B9E)),
  (label: "PhD", percent: 10.0, count: 125, color: Color(0xFF2196F3)),
  (label: "Diploma", percent: 10.0, count: 125, color: Color(0xFF2E7D32)),
  (label: "Other", percent: 5.0, count: 62, color: Color(0xFFFF9800)),
];

class _UsersByAcademicLevelAnalyticsCard extends StatelessWidget {
  final double screenWidth;

  const _UsersByAcademicLevelAnalyticsCard({required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    return _AnalyticsCard(
      title: 'Users by Academic Level',
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 48,
                sections: _academicSegments.map((s) {
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: _academicSegments.map((s) {
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

const _topSkills = [
  ('JavaScript', 512),
  ('Python', 487),
  ('Communication', 456),
  ('React', 398),
  ('Problem Solving', 387),
];

class _MostFrequentlyAddedSkillsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final maxCount = _topSkills.first.$2;

    return _AnalyticsCard(
      title: 'Most Frequently Added Skills',
      child: Column(
        children: _topSkills.asMap().entries.map((e) {
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
                      valueColor: const AlwaysStoppedAnimation<Color>(_chartPrimary),
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

// Job Category Distribution: category name, percentage, purple progress bar
const _categoryDistribution = [
  ('Development', 35),
  ('Data & Analytics', 22),
  ('Design', 15),
  ('Marketing', 12),
  ('Management', 10),
  ('Other', 6),
];

class _JobCategoryDistributionCard extends StatelessWidget {
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
          ..._categoryDistribution.map((e) {
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
                      value: percent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(_chartPrimary),
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

const _keyInsights = [
  'Development roles (Frontend, Backend, Full Stack) account for 34% of total selections',
  'Cloud Computing and Machine Learning are the top skill gaps requiring attention',
  'User engagement has grown consistently, with 47% increase in assessments',
  '45% of users hold Bachelor\'s degrees, indicating strong undergraduate adoption',
  'JavaScript and Python are the most commonly added technical skills',
];

class _KeyInsightsSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5B4B9E),
            Color(0xFF3949AB),
          ],
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
          ..._keyInsights.map((insight) {
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
          }),
        ],
      ),
    );
  }
}
