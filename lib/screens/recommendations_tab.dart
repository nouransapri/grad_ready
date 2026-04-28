import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/skill_model.dart';
import '../services/firestore_service.dart';
import '../utils/skill_utils.dart';

/// Recommendations tab: shows a card for every skill in [skillNames].
/// Skills found in the Firestore cache with a valid courseUrl get a full course card;
/// the rest show a "Resource Hunt in Progress…" placeholder so the count always
/// matches the "Critical Gaps" count on the Analysis screen.
class RecommendationsTab extends StatefulWidget {
  /// All missing skill names (by priority), unfiltered.
  final List<String> skillNames;

  /// Which of [skillNames] should show the "Critical Gap" badge.
  final Set<String> criticalGapNames;

  /// Which of [skillNames] are mandatory gate-blockers; shown with a red "Mandatory" badge.
  final Set<String> mandatorySkillNames;

  const RecommendationsTab({
    super.key,
    required this.skillNames,
    this.criticalGapNames = const {},
    this.mandatorySkillNames = const {},
  });

  @override
  State<RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<RecommendationsTab>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  Map<String, SkillModel> _allSkillsCache = {};
  bool _isLoading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadCourses();
  }

  @override
  void didUpdateWidget(covariant RecommendationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listEquals(widget.skillNames, oldWidget.skillNames) ||
        !_setEquals(widget.criticalGapNames, oldWidget.criticalGapNames) ||
        !_setEquals(widget.mandatorySkillNames, oldWidget.mandatorySkillNames)) {
      _loadCourses();
    }
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final allSkillsList = await _firestore.getSkillModelsOnce();
      final allSkillsMap = <String, SkillModel>{};
      for (final m in allSkillsList) {
        allSkillsMap[smartNormalize(m.skillName)] = m;
      }
      if (!mounted) return;
      setState(() {
        _allSkillsCache = allSkillsMap;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load recommendations.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadCourses,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.skillNames.isEmpty) {
      return Container(
        color: const Color(0xFFF8FAFC),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Complete your skills assessment to see personalized course recommendations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    // Deduplicate while preserving priority order.
    final seen = <String>{};
    final allSkills = widget.skillNames
        .where((s) => s.trim().isNotEmpty && seen.add(smartNormalize(s)))
        .toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(allSkills.length),
              const SizedBox(height: 20),
              ...allSkills.asMap().entries.map((e) {
                final index = e.key;
                final skillName = e.value;
                final cacheKey = smartNormalize(skillName);
                final skillModel = _allSkillsCache[cacheKey];
                final courseUrl = skillModel?.courseUrl?.trim() ?? '';
                final hasUrl = courseUrl.isNotEmpty;
                final normalizedName = normalizeSkillName(skillName);
                final isMandatory =
                    widget.mandatorySkillNames.contains(normalizedName);
                final isCritical = !isMandatory &&
                    widget.criticalGapNames.contains(normalizedName);
                // Cap stagger so the 53rd card doesn't wait 5+ seconds.
                final animDelay = index.clamp(0, 10) * 100;

                return TweenAnimationBuilder<double>(
                  key: ValueKey('skill_${skillName}_$index'),
                  tween: Tween(begin: 0.2, end: 0),
                  duration: Duration(milliseconds: 400 + animDelay),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value == 0 ? 1 : 0,
                      child: Transform.translate(
                        offset: Offset(0, 20 * value),
                        child: child,
                      ),
                    );
                  },
                  child: hasUrl
                      ? _buildSkillSection(
                          skillName, skillModel!, isCritical, isMandatory)
                      : _buildPlaceholderSection(
                          skillName, isCritical, isMandatory),
                );
              }),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, child) =>
                    Opacity(opacity: value, child: child),
                child: _buildTipSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int skillCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Recommended Courses for Your Missing Skills',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Showing $skillCount missing skill${skillCount == 1 ? '' : 's'} — courses linked where available, placeholders for the rest',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSkillSection(
    String skillName,
    SkillModel skillModel,
    bool isCritical,
    bool isMandatory,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMandatory
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFC7D2FE),
          width: 2,
        ),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isMandatory
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: isMandatory
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF4F46E5),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  skillName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Mandatory',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Critical Gap',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCourseCard(skillModel),
        ],
      ),
    );
  }

  /// Shown for skills not yet in the Firestore course cache.
  Widget _buildPlaceholderSection(
      String skillName, bool isCritical, bool isMandatory) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMandatory
              ? const Color(0xFFFCA5A5)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isMandatory
                      ? const Color(0xFFFEE2E2)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: isMandatory
                      ? const Color(0xFFDC2626)
                      : Colors.grey.shade400,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  skillName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Mandatory',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Critical Gap',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB91C1C),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_top_rounded,
                  size: 16,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resource Hunt in Progress…',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(SkillModel skill) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openUrl(skill.courseUrl!),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF9FAFB), Color(0xFFEEF2FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.fiber_manual_record,
                          size: 8,
                          color: Color(0xFF2A6CFF),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          skill.skillName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (skill.platform != null && skill.platform!.isNotEmpty)
                        _platformBadge(skill.platform!),
                      _categoryBadge(skill.category),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn the fundamentals of ${skill.skillName} to close your skill gap.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up_rounded,
                        size: 14,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Demand: ${skill.demandLevel ?? 'Medium'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _platformBadge(String platform) {
    final color = _platformColor(platform);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        platform,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _platformColor(String platform) {
    switch (platform) {
      case 'Coursera':
        return const Color(0xFF3B82F6);
      case 'Udemy':
        return const Color(0xFF8B5CF6);
      case 'LinkedIn Learning':
        return const Color(0xFF2563EB);
      case 'edX':
        return const Color(0xFFEF4444);
      case 'Udacity':
        return const Color(0xFF14B8A6);
      case 'Pluralsight':
        return const Color(0xFFEC4899);
      case 'FreeCodeCamp':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _categoryBadge(String? category) {
    if (category == null || category.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.2)),
      ),
      child: Text(
        category,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey.shade700,
        ),
      ),
    );
  }

  Widget _buildTipSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFF4F46E5),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: Click on any course card to open it on the platform. Most platforms offer free trials or audit options!',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF312E81),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid course link.')),
      );
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this course link.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this course link.')),
      );
    }
  }
}
