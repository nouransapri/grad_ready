import 'package:flutter/material.dart';
import '../../models/job_role.dart';
import '../../services/firestore_service.dart';

// ألوان صفحة Market (مطابقة للتصميم)
const Color _orangeBorder = Color(0xFFFFCC80);
const Color _orangeText = Color(0xFFFB8C00);
const Color _orangeChipBg = Color(0xFFFFF3E0);
const Color _orangeButtonBg = Color(0xFFFFF3E0);
const Color _greenBorder = Color(0xFF81C784);
const Color _greenText = Color(0xFF2E7D32);
const Color _greenChipBg = Color(0xFFE8F5E9);
const Color _greyChipBg = Color(0xFFF5F5F5);
const Color _greyText = Color(0xFF757575);
const Color _greyButtonBg = Color(0xFFE0E0E0);
const Color _purpleStat = Color(0xFF5B4B9E);
const Color _blueStat = Color(0xFF2196F3);
const Color _insightsGradientStart = Color(0xFF1565C0);
const Color _insightsGradientEnd = Color(0xFF26A69A);

/// بيانات عرض لدور يحتاج مراجعة (أيام + تاريخ آخر تحديث للعرض فقط).
class _ReviewJobDisplay {
  final String id;
  final String title;
  final String category;
  final int daysAgo;
  final int skillsCount;
  final String lastUpdatedLabel;

  const _ReviewJobDisplay({
    required this.id,
    required this.title,
    required this.category,
    required this.daysAgo,
    required this.skillsCount,
    required this.lastUpdatedLabel,
  });
}

const List<_ReviewJobDisplay> _reviewNeededItems = [
  _ReviewJobDisplay(
    id: 'outdated_0',
    title: 'Data Analyst',
    category: 'Data & Analytics',
    daysAgo: 228,
    skillsCount: 8,
    lastUpdatedLabel: 'Jul 18, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_1',
    title: 'Business Intelligence Analyst',
    category: 'Data & Analytics',
    daysAgo: 230,
    skillsCount: 8,
    lastUpdatedLabel: 'Jul 16, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_2',
    title: 'Digital Marketing Specialist',
    category: 'Marketing',
    daysAgo: 198,
    skillsCount: 8,
    lastUpdatedLabel: 'Aug 17, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_3',
    title: 'Social Media Manager',
    category: 'Marketing',
    daysAgo: 263,
    skillsCount: 7,
    lastUpdatedLabel: 'Jun 13, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_4',
    title: 'Product Manager',
    category: 'Management',
    daysAgo: 210,
    skillsCount: 9,
    lastUpdatedLabel: 'Jun 28, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_5',
    title: 'UX Designer',
    category: 'Design',
    daysAgo: 195,
    skillsCount: 7,
    lastUpdatedLabel: 'Jul 2, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_6',
    title: 'Backend Developer',
    category: 'Development',
    daysAgo: 220,
    skillsCount: 10,
    lastUpdatedLabel: 'Jun 20, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_7',
    title: 'Data Scientist',
    category: 'Data & Analytics',
    daysAgo: 245,
    skillsCount: 9,
    lastUpdatedLabel: 'Jun 8, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_8',
    title: 'DevOps Engineer',
    category: 'Development',
    daysAgo: 189,
    skillsCount: 8,
    lastUpdatedLabel: 'Jul 10, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_9',
    title: 'Content Strategist',
    category: 'Marketing',
    daysAgo: 201,
    skillsCount: 6,
    lastUpdatedLabel: 'Jun 25, 2025',
  ),
  _ReviewJobDisplay(
    id: 'outdated_10',
    title: 'QA Engineer',
    category: 'Development',
    daysAgo: 215,
    skillsCount: 7,
    lastUpdatedLabel: 'Jun 15, 2025',
  ),
];

/// محتوى تبويب Market في لوحة الأدمن (تنبيه + إحصائيات + Bulk Actions + أدوار تحتاج مراجعة + محدثة + رؤى السوق).
class AdminMarketContent extends StatefulWidget {
  const AdminMarketContent({super.key});

  @override
  State<AdminMarketContent> createState() => _AdminMarketContentState();
}

class _AdminMarketContentState extends State<AdminMarketContent> {
  final Set<String> _selectedOutdatedIds = {};
  bool _updating = false;

  void _selectAllOutdated() {
    setState(() {
      for (final item in _reviewNeededItems) {
        _selectedOutdatedIds.add(item.id);
      }
    });
  }

  void _toggleOutdated(String id) {
    setState(() {
      if (_selectedOutdatedIds.contains(id)) {
        _selectedOutdatedIds.remove(id);
      } else {
        _selectedOutdatedIds.add(id);
      }
    });
  }

  Future<void> _updateSelected() async {
    if (_selectedOutdatedIds.isEmpty || _updating) return;
    setState(() => _updating = true);
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedOutdatedIds.length} role(s) marked as updated',
          ),
        ),
      );
      setState(() {
        _selectedOutdatedIds.clear();
        _updating = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _updating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  static String _formatLastUpdated(int daysAgo) {
    final d = DateTime.now().subtract(Duration(days: daysAgo));
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JobRole>>(
      stream: FirestoreService().getJobs(),
      builder: (context, snapshot) {
        final jobs = snapshot.data ?? [];
        final upToDateJobs = jobs.take(8).toList();
        const displayCount = 5;
        final needUpdateCount = _reviewNeededItems.length;
        final totalRoles = needUpdateCount + upToDateJobs.length;
        final upToDateCount = upToDateJobs.length;
        final selectedCount = _selectedOutdatedIds.length;
        final canUpdate = selectedCount > 0 && !_updating;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MarketAlertCard(needUpdateCount: needUpdateCount),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _MarketStatCard(
                      value: '$totalRoles',
                      label: 'Total Roles',
                      color: _purpleStat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MarketStatCard(
                      value: '$needUpdateCount',
                      label: 'Need Update',
                      color: _orangeText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MarketStatCard(
                      value: '$upToDateCount',
                      label: 'Up to Date',
                      color: _greenText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MarketStatCard(
                      value: '$selectedCount',
                      label: 'Selected',
                      color: _blueStat,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Bulk Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BulkActionButton(
                      label: 'Select All Outdated',
                      color: _orangeText,
                      backgroundColor: _orangeButtonBg,
                      onTap: _selectAllOutdated,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BulkActionButton(
                      label: 'Update Selected',
                      color: canUpdate ? _purpleStat : _greyText,
                      backgroundColor: _greyButtonBg,
                      onTap: canUpdate ? _updateSelected : null,
                      icon: Icons.refresh_rounded,
                      loading: _updating,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: _orangeText,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Needs Update ($needUpdateCount)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._reviewNeededItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MarketJobCard(
                    title: item.title,
                    category: item.category,
                    daysAgo: item.daysAgo,
                    skillsCount: item.skillsCount,
                    lastUpdatedLabel: item.lastUpdatedLabel,
                    isReviewNeeded: true,
                    isSelected: _selectedOutdatedIds.contains(item.id),
                    onTap: () => _toggleOutdated(item.id),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _greenText,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Up to Date ($upToDateCount)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...upToDateJobs.take(displayCount).map((job) {
                final skillsCount =
                    job.technicalSkillsWithLevel.length +
                    job.softSkillsWithLevel.length;
                final n = skillsCount > 0
                    ? skillsCount
                    : job.requiredSkills.length;
                final daysAgo = 90 + (upToDateJobs.indexOf(job) * 15) % 200;
                final lastUpdated = _formatLastUpdated(daysAgo);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MarketJobCard(
                    title: job.title,
                    category: job.category,
                    daysAgo: daysAgo,
                    skillsCount: n,
                    lastUpdatedLabel: lastUpdated,
                    isReviewNeeded: false,
                  ),
                );
              }),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Showing first ${upToDateJobs.length > displayCount ? displayCount : upToDateJobs.length} of ${upToDateJobs.length} up-to-date roles',
                  style: const TextStyle(color: _greyText, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              _MarketInsightsCard(),
            ],
          ),
        );
      },
    );
  }
}

class _MarketAlertCard extends StatelessWidget {
  final int needUpdateCount;

  const _MarketAlertCard({required this.needUpdateCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _orangeChipBg,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: _orangeText, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _orangeText, size: 22),
              SizedBox(width: 8),
              Text(
                'Market Data Needs Attention',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _orangeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$needUpdateCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _orangeText,
                  ),
                ),
                const TextSpan(
                  text:
                      ' job role(s) haven\'t been updated in over 6 months. Please review and update to ensure accuracy.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MarketStatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: _greyText)),
        ],
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;

  const _BulkActionButton({
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.onTap,
    this.icon,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 18, color: color),
              if (icon != null || loading) const SizedBox(width: 6),
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

class _MarketJobCard extends StatelessWidget {
  final String title;
  final String category;
  final int daysAgo;
  final int skillsCount;
  final String lastUpdatedLabel;
  final bool isReviewNeeded;
  final bool isSelected;
  final VoidCallback? onTap;

  const _MarketJobCard({
    required this.title,
    required this.category,
    required this.daysAgo,
    required this.skillsCount,
    required this.lastUpdatedLabel,
    required this.isReviewNeeded,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isReviewNeeded ? _orangeBorder : _greenBorder;
    final chipBg = isReviewNeeded ? _orangeChipBg : _greenChipBg;
    final accentColor = isReviewNeeded ? _orangeText : _greenText;

    Widget card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isReviewNeeded && onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected ? _orangeText : _greyText,
                      size: 22,
                    ),
                  ),
                Expanded(
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
                      const SizedBox(height: 4),
                      Text(
                        category,
                        style: const TextStyle(fontSize: 13, color: _greyText),
                      ),
                    ],
                  ),
                ),
                if (!isReviewNeeded)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _greenText,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$daysAgo days ago',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _greyChipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$skillsCount skills',
                    style: const TextStyle(fontSize: 12, color: _greyText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last updated: $lastUpdatedLabel',
                  style: const TextStyle(fontSize: 11, color: _greyText),
                ),
                Text(
                  isReviewNeeded ? 'Review needed' : 'Current',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

class _MarketInsightsCard extends StatelessWidget {
  static const _bullets = [
    'Regular updates ensure students receive accurate market information',
    'Review job requirements quarterly to reflect industry trends',
    'Update proficiency levels based on employer feedback',
    'Mark deprecated skills and add emerging technologies',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_insightsGradientStart, _insightsGradientEnd],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _insightsGradientStart.withValues(alpha: 0.3),
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
              Icon(Icons.show_chart_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Market Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._bullets.map(
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
