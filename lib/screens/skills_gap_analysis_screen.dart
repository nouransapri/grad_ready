import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/job_role.dart';
import '../services/firestore_service.dart';
import '../services/gap_analysis_service.dart';
import 'create_profile.dart';

/// Single skill gap result: job requirement vs user level.
class SkillGapItem {
  final String name;
  final bool isTechnical;
  final int requiredPercent;
  final int currentPercent;
  final bool isCritical; // from job.criticalSkills

  SkillGapItem({
    required this.name,
    required this.isTechnical,
    required this.requiredPercent,
    required this.currentPercent,
    required this.isCritical,
  });

  int get gapPercent => (requiredPercent - currentPercent).clamp(0, 100);
  /// Completion = (current / required * 100), can exceed 100.
  int get completionPercent => requiredPercent > 0 ? ((currentPercent / requiredPercent) * 100).round() : 100;

  /// Strong: meet or exceed. Developing: gap ≤ 30%. Critical: gap > 30%.
  String get status {
    if (currentPercent >= requiredPercent) return 'Strong';
    if (gapPercent <= 30) return 'Developing';
    return 'Critical';
  }

  bool get isStrong => status == 'Strong';
  bool get isDeveloping => status == 'Developing';
  bool get isCriticalGap => status == 'Critical';
}

class SkillsGapAnalysisScreen extends StatefulWidget {
  final JobRole job;

  const SkillsGapAnalysisScreen({super.key, required this.job});

  @override
  State<SkillsGapAnalysisScreen> createState() => _SkillsGapAnalysisScreenState();
}

class _SkillsGapAnalysisScreenState extends State<SkillsGapAnalysisScreen> with SingleTickerProviderStateMixin {
  List<SkillGapItem> _items = [];
  GapAnalysisResult? _gapResult;
  late JobRole _currentJob;
  DocumentSnapshot<Map<String, dynamic>>? _userSnap;
  bool _loading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<JobRole?>? _jobSub;
  final FirestoreService _firestore = FirestoreService();

  List<SkillProficiency> get _technicalSkills {
    if (_currentJob.technicalSkillsWithLevel.isNotEmpty) return _currentJob.technicalSkillsWithLevel;
    final n = (_currentJob.requiredSkills.length / 2).ceil();
    return _currentJob.requiredSkills.take(n).map((s) => SkillProficiency(name: s, percent: 70)).toList();
  }

  List<SkillProficiency> get _softSkills {
    if (_currentJob.softSkillsWithLevel.isNotEmpty) return _currentJob.softSkillsWithLevel;
    final n = (_currentJob.requiredSkills.length / 2).ceil();
    return _currentJob.requiredSkills.skip(n).map((s) => SkillProficiency(name: s, percent: 70)).toList();
  }

  /// من مستوى البروفايل (Basic/Intermediate/Advanced) إلى نسبة مئوية — مطابق لـ create_profile
  static int _levelToPercent(dynamic level) {
    if (level == null) return 0;
    if (level is int) return level.clamp(0, 100);
    if (level is double) return level.round().clamp(0, 100);
    final s = level.toString().trim();
    if (s.isEmpty) return 0;
    switch (s.toLowerCase()) {
      case 'advanced':
        return 95;
      case 'intermediate':
        return 65;
      case 'basic':
        return 35;
      default:
        final num = int.tryParse(s);
        return num != null ? num.clamp(0, 100) : 35;
    }
  }

  /// تطبيع اسم المهارة للمقارنة (حذف فراغات زائدة، lowercase)
  static String _normalizeSkillName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// استخراج نسبة المستخدم لمهارة من خريطة مهارات البروفايل (مع مطابقة مرنة للأسماء)
  static int _userPercentForSkill(String jobSkillName, Map<String, int> userSkillPercent) {
    final jobLower = _normalizeSkillName(jobSkillName);
    final exact = userSkillPercent[jobLower];
    if (exact != null) return exact;
    for (final e in userSkillPercent.entries) {
      final userKey = _normalizeSkillName(e.key);
      if (userKey == jobLower) return e.value;
      if (userKey.contains(jobLower) || jobLower.contains(userKey)) return e.value;
    }
    return 0;
  }

  void _updateAnalysis() {
    if (_userSnap == null) return;
    final userData = _userSnap!.data();
    final technical = _technicalSkills;
    final soft = _softSkills;
    final criticalNames = _currentJob.criticalSkills.map((e) => _normalizeSkillName(e)).toSet();
    Map<String, int> userSkillPercent = {};
    final skills = userData?['skills'] as List?;
    if (skills != null) {
      for (final s in skills) {
        final m = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
        final name = (m['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final percent = _levelToPercent(m['level']);
        final key = _normalizeSkillName(name);
        if (percent > (userSkillPercent[key] ?? 0)) userSkillPercent[key] = percent;
      }
    }
    final List<SkillGapItem> items = [];
    for (final s in technical) {
      final nameLower = _normalizeSkillName(s.name);
      final current = _userPercentForSkill(s.name, userSkillPercent);
      items.add(SkillGapItem(
        name: s.name,
        isTechnical: true,
        requiredPercent: s.percent,
        currentPercent: current,
        isCritical: criticalNames.contains(nameLower) || criticalNames.any((c) => nameLower.contains(c) || c.contains(nameLower)),
      ));
    }
    for (final s in soft) {
      final nameLower = _normalizeSkillName(s.name);
      final current = _userPercentForSkill(s.name, userSkillPercent);
      items.add(SkillGapItem(
        name: s.name,
        isTechnical: false,
        requiredPercent: s.percent,
        currentPercent: current,
        isCritical: criticalNames.contains(nameLower) || criticalNames.any((c) => nameLower.contains(c) || c.contains(nameLower)),
      ));
    }
    GapAnalysisResult? gapResult;
    if (userData != null) gapResult = GapAnalysisService.runGapAnalysis(userData, _currentJob);
    if (mounted) {
      setState(() {
        _items = items;
        _gapResult = gapResult;
        _loading = false;
        _error = null;
      });
      _animController.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentJob = widget.job;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> s) {
        if (!mounted) return;
        setState(() {
          _userSnap = s;
          _updateAnalysis();
        });
      });
      _jobSub = _firestore.getJobStream(widget.job.id).listen((JobRole? job) {
        if (!mounted) return;
        setState(() {
          if (job != null) _currentJob = job;
          _updateAnalysis();
        });
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _jobSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // Level-based counts (disabled as primary source; kept for fallback only).
  int get _strongCount => _items.where((e) => e.isStrong).length;
  int get _developingCount => _items.where((e) => e.isDeveloping).length;
  int get _criticalCount => _items.where((e) => e.isCriticalGap).length;

  /// Single source of truth: match percentage from GapAnalysisService (skill existence only).
  /// Level-based calculation is disabled temporarily for clarity.
  int get _displayMatchPercent {
    if (_gapResult == null) return 0;
    return _gapResult!.matchPercentage.round();
  }

  /// Strong count from gap result: number of required skills the user has.
  int get _displayStrongCount {
    if (_gapResult == null) return _strongCount;
    final required = GapAnalysisService.getRequiredSkillNames(_currentJob).length;
    return (required - _gapResult!.missingSkills.length).clamp(0, required);
  }

  /// Developing: not used when we only care about skill existence; always 0 from service.
  int get _displayDevelopingCount {
    if (_gapResult == null) return _developingCount;
    return 0;
  }

  /// Critical gaps from gap result: number of missing required skills.
  int get _displayCriticalCount {
    if (_gapResult == null) return _criticalCount;
    return _gapResult!.missingSkills.length;
  }

  String get _displayLabel {
    final p = _displayMatchPercent;
    if (p >= 80) return 'Strong Match';
    if (p >= 50) return 'Moderate Gap';
    if (p >= 30) return 'Significant Gap';
    return 'Large Gap';
  }

  /// Category match for Technical/Soft cards. When gap result exists we use the same unified match %
  /// (level-based calculation disabled temporarily; skill existence only).
  int _categoryMatch(bool technical) {
    if (_gapResult != null) {
      return _displayMatchPercent;
    }
    final list = _items.where((e) => e.isTechnical == technical).toList();
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(0, (s, i) => s + (i.completionPercent > 100 ? 100 : i.completionPercent));
    return (sum / list.length).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primary),
              const SizedBox(height: 16),
              Text('Analyzing your skills...', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: primary, foregroundColor: Colors.white),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Something went wrong', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _error = null);
                    _updateAnalysis();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildHeader(context),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(left: 0, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        isScrollable: true,
                        labelColor: theme.colorScheme.primary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        unselectedLabelColor: Colors.grey.shade600,
                        unselectedLabelStyle: const TextStyle(fontSize: 14),
                        indicatorColor: theme.colorScheme.primary,
                        indicatorWeight: 3,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.only(left: 0, right: 16),
                        tabs: const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Skills Breakdown'),
                          Tab(text: 'Recommendations'),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade300),
                  ],
                ),
              ),
            ),
          ],
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: TabBarView(
              children: [
                _buildOverviewTab(),
                _buildSkillsBreakdownTab(),
                _buildRecommendationsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
              onTap: () => Navigator.pop(context),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('Back to Requirements', style: TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Target Role', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _currentJob.title,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // بطاقة ملخص الفجوة (بداخل كارد بتدرج)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
              ),
              child: Column(
                children: [
                  // Single source of truth: GapAnalysisService — animated from 0 to value
                  TweenAnimationBuilder<double>(
                    key: ValueKey(_displayMatchPercent),
                    tween: Tween(begin: 0, end: _displayMatchPercent / 100),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(value * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _displayLabel,
                          style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: value.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _headerStatCard('$_displayStrongCount', 'Strong', Colors.white.withValues(alpha: 0.25)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _headerStatCard('$_displayDevelopingCount', 'Developing', Colors.white.withValues(alpha: 0.25)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _headerStatCard('$_displayCriticalCount', 'Critical Gaps', Colors.white.withValues(alpha: 0.25)),
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

  Widget _headerStatCard(String count, String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final theme = Theme.of(context);
    final technicalMatch = _categoryMatch(true);
    final softMatch = _categoryMatch(false);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _matchScoreCard('Technical', technicalMatch, theme.colorScheme.secondary, Icons.bar_chart_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _matchScoreCard('Soft Skills', softMatch, theme.colorScheme.primary, Icons.bolt_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'All Skills Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
            ),
            const SizedBox(height: 14),
            ..._items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SkillAnalysisCard(item: item),
                )),
            const SizedBox(height: 24),
            _buildStatusGuide(),
          ],
        ),
      ),
    );
  }

  Widget _matchScoreCard(String label, int percent, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
          const SizedBox(height: 14),
          Text('$percent%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 2),
          Text('Match Score', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildSkillsBreakdownTab() {
    final technicalMatch = _categoryMatch(true);
    final softMatch = _categoryMatch(false);
    final technicalItems = _items.where((e) => e.isTechnical).toList();
    final softItems = _items.where((e) => !e.isTechnical).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _breakdownSummaryCard('Technical Skills', technicalMatch, const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _breakdownSummaryCard('Soft Skills', softMatch, const Color(0xFF7C3AED)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (technicalItems.isNotEmpty) ...[
              const Text(
                'Technical Skills',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
              ),
              const SizedBox(height: 12),
              ...technicalItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BreakdownSkillTile(item: item),
                  )),
              const SizedBox(height: 24),
            ],
            if (softItems.isNotEmpty) ...[
              const Text(
                'Soft Skills',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
              ),
              const SizedBox(height: 12),
              ...softItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BreakdownSkillTile(item: item),
                  )),
              const SizedBox(height: 24),
            ],
            _buildStatusGuide(),
          ],
        ),
      ),
    );
  }

  Widget _breakdownSummaryCard(String label, int percent, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Average Match',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    final critical = _items.where((e) => e.isCriticalGap).toList();
    final developing = _items.where((e) => e.isDeveloping).toList();
    final prioritySkills = [...critical, ...developing];
    final shortTerm = developing.length;
    final mediumTerm = (critical.length * 0.4).round();
    final longTerm = critical.length - mediumTerm;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _recommendationsIntroCard(),
            if (_gapResult != null) ...[
              const SizedBox(height: 24),
              _buildGapSummaryCard(),
            ],
            const SizedBox(height: 24),
            _buildPriorityFocusAreas(prioritySkills),
            const SizedBox(height: 24),
            _buildLearningResources(),
            const SizedBox(height: 24),
            _buildEstimatedTimeline(shortTerm, mediumTerm, longTerm),
            const SizedBox(height: 24),
            _buildStatusGuide(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateProfileScreen(isEditMode: true),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Update Your Skills Assessment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendationsIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
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
          const Text(
            'Your Personalized Recommendations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Based on your current skills and target role, here\'s a strategic plan to help you bridge the gap and achieve your career goals.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.95), height: 1.5),
          ),
        ],
      ),
    );
  }

  /// Same source of truth as top card: GapAnalysisService.runGapAnalysis (matchPercentage, missingSkills, missingCourses).
  Widget _buildGapSummaryCard() {
    final r = _gapResult!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Text(
                'Profile vs Job Match: ${r.matchPercentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
            ],
          ),
          if (r.missingSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Missing skills (${r.missingSkills.length})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.missingSkills.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              )).toList(),
            ),
          ],
          if (r.missingCourses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Missing courses (${r.missingCourses.length})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.missingCourses.map((c) => Chip(
                label: Text(c, style: const TextStyle(fontSize: 12)),
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriorityFocusAreas(List<SkillGapItem> prioritySkills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up_rounded, color: AppTheme.warning, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Priority Focus Areas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Focus on these skills first to make the biggest impact on your readiness score',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
        ),
        const SizedBox(height: 16),
        ...prioritySkills.take(5).toList().asMap().entries.map((entry) {
          final i = entry.key + 1;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _prioritySkillCard(i, item.name, item.currentPercent, item.requiredPercent, item.gapPercent),
          );
        }),
      ],
    );
  }

  Widget _prioritySkillCard(int index, String skillName, int current, int required, int gapPercent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppTheme.warning,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skillName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gap: $gapPercent%',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                Text(
                  'Improve from $current% to $required%',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningResources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Learning Resources',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
        ),
        const SizedBox(height: 14),
        _learningResourceCard(
          Icons.menu_book_rounded,
          const Color(0xFF2563EB),
          'Online Courses',
          'Platforms like Coursera, Udemy, and LinkedIn Learning offer targeted courses for your skill gaps.',
        ),
        const SizedBox(height: 12),
        _learningResourceCard(
          Icons.workspace_premium_rounded,
          const Color(0xFF7C3AED),
          'Certifications',
          'Industry-recognized certifications can validate your skills and boost your resume.',
        ),
        const SizedBox(height: 12),
        _learningResourceCard(
          Icons.code_rounded,
          const Color(0xFF059669),
          'Practice Projects',
          'Build real-world projects to demonstrate your skills and build a portfolio.',
        ),
      ],
    );
  }

  Widget _learningResourceCard(IconData icon, Color color, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstimatedTimeline(int short, int medium, int long) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimated Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
          ),
          const SizedBox(height: 16),
          _timelineRow('Short Term (1-3 months)', short, Theme.of(context).colorScheme.primary, 'Focus on developing skills that are close to target'),
          const SizedBox(height: 12),
          _timelineRow('Medium Term (3-6 months)', medium, Theme.of(context).colorScheme.secondary, 'Address priority gaps with structured learning'),
          const SizedBox(height: 12),
          _timelineRow('Long Term (6-12 months)', long, AppTheme.warning, 'Build expertise in advanced or specialized areas'),
        ],
      ),
    );
  }

  Widget _timelineRow(String period, int count, Color color, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$count Skills',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E)),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Guide',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
          ),
          const SizedBox(height: 18),
          _statusRow(Icons.check_circle, AppTheme.success, 'Strong', 'You meet or exceed the requirement'),
          const SizedBox(height: 14),
          _statusRow(Icons.trending_up_rounded, Theme.of(context).colorScheme.primary, 'Developing', 'Gap is ≤30% - you\'re close!'),
          const SizedBox(height: 14),
          _statusRow(Icons.warning_amber_rounded, AppTheme.warning, 'Critical', 'Gap is >30% - priority for improvement'),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, Color color, String boldLabel, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.4),
              children: [
                TextSpan(
                  text: '$boldLabel: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// بطاقة مهارة واحدة داخل تبويب Skills Breakdown (مع تسمية Critical ونص "improvement needed")
class _BreakdownSkillTile extends StatelessWidget {
  final SkillGapItem item;

  const _BreakdownSkillTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Icon(Icons.show_chart_rounded, color: AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
              if (item.isCriticalGap)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'Critical',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current: ${item.currentPercent}%',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Required: ${item.requiredPercent}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (item.requiredPercent > 0)
                  ? (item.currentPercent / item.requiredPercent).clamp(0.0, 1.0)
                  : 0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                item.isStrong ? AppTheme.success : item.isDeveloping ? AppTheme.primary : AppTheme.warning,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gap: ${item.gapPercent}% improvement needed',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}

class _SkillAnalysisCard extends StatelessWidget {
  final SkillGapItem item;

  const _SkillAnalysisCard({required this.item});

  Color get _progressColor {
    if (item.isStrong) return AppTheme.success;
    if (item.isDeveloping) return AppTheme.primary;
    return AppTheme.warning;
  }

  Widget get _statusIcon {
    if (item.isStrong) return Icon(Icons.check_circle, color: AppTheme.success, size: 22);
    if (item.isDeveloping) return Icon(Icons.trending_up_rounded, color: AppTheme.primary, size: 22);
    return Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 22);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
              _statusIcon,
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                item.isTechnical ? Icons.bar_chart_rounded : Icons.shield_rounded,
                size: 16,
                color: item.isTechnical ? Theme.of(context).colorScheme.secondary : AppTheme.warning,
              ),
              const SizedBox(width: 6),
              Text(
                item.isTechnical ? 'Technical' : 'Soft Skill',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current: ${item.currentPercent}%',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              Text(
                'Required: ${item.requiredPercent}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (item.requiredPercent > 0)
                  ? (item.currentPercent / item.requiredPercent).clamp(0.0, 1.0)
                  : 0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gap: ${item.gapPercent}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
