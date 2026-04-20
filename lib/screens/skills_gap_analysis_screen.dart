import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/job_document.dart';
import '../models/job_role.dart' show SkillProficiency;
import '../models/skill.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/gap_analysis_service.dart';
import '../utils/skill_utils.dart';
import 'recommendations_tab.dart';
import 'widgets/analysis_header.dart';
import 'widgets/analysis_gap_summary_header.dart';
import 'widgets/analysis_high_priority_skills_section.dart';
import 'widgets/analysis_learning_path_section.dart';
import 'widgets/analysis_market_demand_card.dart';
import 'widgets/analysis_match_score_card.dart';
import 'widgets/analysis_medium_priority_skills_section.dart';
import 'widgets/analysis_missing_skills_section.dart';
import 'widgets/analysis_readiness_card.dart';
import 'widgets/analysis_skill_category_comparison_card.dart';
import 'widgets/analysis_status_guide_card.dart';
import 'widgets/analysis_top_priority_gap_card.dart';
import 'widgets/breakdown_skill_tile.dart';
import 'widgets/skills_list_section.dart';

/// One row in the UI: required level vs the user’s current level for a single skill name.
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
  int get completionPercent => requiredPercent > 0
      ? ((currentPercent / requiredPercent) * 100).round()
      : 100;

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

/// Live gap analysis for a job: listens to `users/{uid}` and `jobs/{jobId}` so admin edits
/// and profile updates refresh scores without leaving the screen.
class SkillsGapAnalysisScreen extends StatefulWidget {
  final JobDocument job;

  const SkillsGapAnalysisScreen({super.key, required this.job});

  @override
  State<SkillsGapAnalysisScreen> createState() =>
      _SkillsGapAnalysisScreenState();
}

/// Coordinates Firestore listeners, skills catalog fetch, and [GapAnalysisService.runGapAnalysis].
class _SkillsGapAnalysisScreenState extends State<SkillsGapAnalysisScreen>
    with SingleTickerProviderStateMixin {
  List<SkillGapItem> _items = [];
  GapAnalysisResult? _gapResult;
  late JobDocument _currentJob;
  late String _jobId;
  DocumentSnapshot<Map<String, dynamic>>? _userSnap;
  bool _loading = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<JobDocument?>? _jobSub;
  final FirestoreService _firestore = FirestoreService();
  String? _lastAnalysisSignature;
  Map<String, Skill>? _skillsCatalog;
  int _updateAnalysisVersion = 0;

  List<SkillProficiency> get _technicalSkills {
    final tech = _currentJob.gapTechnicalProficiencies;
    if (tech.isNotEmpty) return tech;
    final names = _currentJob.gapOrderedRequiredNames;
    if (names.isEmpty) return [];
    final n = (names.length / 2).ceil();
    return names
        .take(n)
        .map((s) => SkillProficiency(name: s, percent: 70))
        .toList();
  }

  List<SkillProficiency> get _softSkills {
    final soft = _currentJob.gapSoftProficiencies;
    if (soft.isNotEmpty) return soft;
    final names = _currentJob.gapOrderedRequiredNames;
    if (names.isEmpty) return [];
    final n = (names.length / 2).ceil();
    return names
        .skip(n)
        .map((s) => SkillProficiency(name: s, percent: 70))
        .toList();
  }

  /// Resolves user percent for a job skill name from profile skill map (flexible name match).
  static int _userPercentForSkill(
    String jobSkillName,
    Map<String, int> userSkillPercent,
  ) {
    final jobLower = normalizeSkillName(jobSkillName);
    final exact = userSkillPercent[jobLower];
    if (exact != null) return exact;
    for (final e in userSkillPercent.entries) {
      final userKey = normalizeSkillName(e.key);
      if (userKey == jobLower) return e.value;
      if (userKey.contains(jobLower) || jobLower.contains(userKey)) {
        return e.value;
      }
    }
    return 0;
  }

  static int _userLevelForSkillId(String skillId, Map<String, int> userLevels) {
    final canonical = canonicalSkillId(skillId);
    return userLevels[canonical] ?? userLevels[skillId] ?? 0;
  }

  static Skill? _catalogSkillById(Map<String, Skill> catalog, String skillId) {
    final canonical = canonicalSkillId(skillId);
    final byKey = catalog[canonical] ?? catalog[skillId];
    if (byKey != null) return byKey;
    for (final s in catalog.values) {
      if (canonicalSkillId(s.id) == canonical) return s;
    }
    return null;
  }

  static Map<String, int> _userSkillPercentByName(Map<String, dynamic>? userData) {
    if (userData == null) return {};
    final model = UserModel.fromFirestore('', userData);
    final out = <String, int>{};
    for (final s in model.skills) {
      final key = normalizeSkillName(s.name);
      if (key.isEmpty) continue;
      if (s.level > (out[key] ?? 0)) {
        out[key] = s.level.clamp(0, 100);
      }
    }
    return out;
  }

  static int _userLevelFallbackByName(
    Map<String, int> userSkillPercent,
    String skillName,
  ) {
    final target = normalizeSkillName(skillName);
    int best = 0;
    for (final e in userSkillPercent.entries) {
      final n = normalizeSkillName(e.key);
      if (!(n == target || n.contains(target) || target.contains(n))) continue;
      final percent = e.value;
      if (percent > best) best = percent;
    }
    return best;
  }

  Future<void> _updateAnalysis() async {
    if (_userSnap == null) return;
    final version = ++_updateAnalysisVersion;
    final userData = _userSnap!.data();
    final userSkillPercent = _userSkillPercentByName(userData);
    final mergedCatalog = GapAnalysisService.mergeJobRequiredSkillsCatalog(
      _currentJob,
      _skillsCatalog,
    );
    final useLevelBased =
        _currentJob.gapRequiredSkillsWithLevel.isNotEmpty && userData != null;

    List<SkillGapItem> items = [];
    GapAnalysisResult? gapResult;

    if (useLevelBased) {
      final userLevels = GapAnalysisService.collectUserLevelsBySkillId(
        userData,
        mergedCatalog,
      );
      final requiredSorted = List<JobRequiredSkill>.from(
        _currentJob.gapRequiredSkillsWithLevel,
      )..sort((a, b) => b.importance.compareTo(a.importance));
      for (final req in requiredSorted) {
        final skill = _catalogSkillById(mergedCatalog, req.skillId);
        final name = skill?.name ?? req.skillId;
        final requiredPercent = req.requiredLevel.clamp(0, 100);
        int currentPercent = _userLevelForSkillId(req.skillId, userLevels);
        if (currentPercent == 0) {
          currentPercent = _userLevelFallbackByName(userSkillPercent, name);
        }
        final isTechnical = skill?.isTechnical ?? true;
        final isCritical = req.importance >= 3;
        items.add(
          SkillGapItem(
            name: name,
            isTechnical: isTechnical,
            requiredPercent: requiredPercent,
            currentPercent: currentPercent,
            isCritical: isCritical,
          ),
        );
      }
      gapResult = await GapAnalysisService.runGapAnalysis(
        userData,
        _currentJob,
        fetchRecommendations: (names) =>
            _firestore.getSuggestedCoursesForSkills(names),
        fetchSmartRecommendations: (names, userSkillIds) =>
            _firestore.getSmartRecommendationsForSkills(
              names,
              userSkillIds,
              verifiedOnly: true,
            ),
        fetchCourseDetails: (names) => _firestore.getCoursesForSkills(names, 3),
        skillsCatalog: _skillsCatalog,
      );
    } else {
      final technical = _technicalSkills;
      final soft = _softSkills;
      final criticalNames = _currentJob.gapCriticalSkillNames
          .map((e) => normalizeSkillName(e))
          .toSet();
      for (final s in technical) {
        final nameLower = normalizeSkillName(s.name);
        final current = _userPercentForSkill(s.name, userSkillPercent);
        items.add(
          SkillGapItem(
            name: s.name,
            isTechnical: true,
            requiredPercent: s.percent,
            currentPercent: current,
            isCritical:
                criticalNames.contains(nameLower) ||
                criticalNames.any(
                  (c) => nameLower.contains(c) || c.contains(nameLower),
                ),
          ),
        );
      }
      for (final s in soft) {
        final nameLower = normalizeSkillName(s.name);
        final current = _userPercentForSkill(s.name, userSkillPercent);
        items.add(
          SkillGapItem(
            name: s.name,
            isTechnical: false,
            requiredPercent: s.percent,
            currentPercent: current,
            isCritical:
                criticalNames.contains(nameLower) ||
                criticalNames.any(
                  (c) => nameLower.contains(c) || c.contains(nameLower),
                ),
          ),
        );
      }
      if (userData != null) {
        gapResult = await GapAnalysisService.runGapAnalysis(
          userData,
          _currentJob,
          fetchRecommendations: (names) =>
              _firestore.getSuggestedCoursesForSkills(names),
          fetchSmartRecommendations: (names, userSkillIds) =>
              _firestore.getSmartRecommendationsForSkills(
                names,
                userSkillIds,
                verifiedOnly: true,
              ),
          fetchCourseDetails: (names) =>
              _firestore.getCoursesForSkills(names, 3),
        );
      }
    }

    if (mounted && version == _updateAnalysisVersion) {
      final dedupedItems = _dedupeSkillGapItems(items);
      setState(() {
        _items = dedupedItems;
        _gapResult = gapResult;
        _loading = false;
        _error = null;
      });
      _animController.forward();
      _saveLastAnalysisIfNeeded();
    }
  }

  List<SkillGapItem> _dedupeSkillGapItems(List<SkillGapItem> input) {
    final bySkill = <String, SkillGapItem>{};
    for (final item in input) {
      final key = normalizeSkillName(item.name);
      if (key.isEmpty) continue;
      final existing = bySkill[key];
      if (existing == null) {
        bySkill[key] = item;
        continue;
      }
      bySkill[key] = SkillGapItem(
        name: existing.name.length >= item.name.length ? existing.name : item.name,
        isTechnical: existing.isTechnical || item.isTechnical,
        requiredPercent: existing.requiredPercent > item.requiredPercent
            ? existing.requiredPercent
            : item.requiredPercent,
        currentPercent: existing.currentPercent > item.currentPercent
            ? existing.currentPercent
            : item.currentPercent,
        isCritical: existing.isCritical || item.isCritical,
      );
    }
    return bySkill.values.toList();
  }

  /// Updates user profile `last_analysis` when analysis payload changes.
  void _saveLastAnalysisIfNeeded() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _currentJob.id.isEmpty) return;
    final coverage = (_gapResult?.matchPercentage ?? 0).round().clamp(0, 100);
    List<String> uniqueNames(Iterable<SkillGapItem> source) {
      final seen = <String>{};
      final out = <String>[];
      for (final item in source) {
        final key = normalizeSkillName(item.name);
        if (key.isEmpty || !seen.add(key)) continue;
        out.add(item.name.trim());
      }
      return out;
    }
    final strongSkills = uniqueNames(_items.where((e) => e.isStrong));
    final developingSkills = uniqueNames(_items.where((e) => e.isDeveloping));
    final criticalSkills = uniqueNames(_items.where((e) => e.isCriticalGap));
    final analysisDetails = <String, dynamic>{
      'jobId': _currentJob.id,
      'title': _currentJob.title,
      'coverage': coverage,
      'strongSkills': strongSkills,
      'developingSkills': developingSkills,
      'criticalSkills': criticalSkills,
      'generatedAt': FieldValue.serverTimestamp(),
    };
    final signature = [
      _currentJob.id,
      coverage,
      strongSkills.join('|'),
      developingSkills.join('|'),
      criticalSkills.join('|'),
    ].join('::');
    if (_lastAnalysisSignature == signature) return;
    _lastAnalysisSignature = signature;
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'last_analysis': analysisDetails,
          'last_analysis_title': _currentJob.title,
          'last_analysis_at': FieldValue.serverTimestamp(),
        })
        .catchError((e, st) {
          developer.log(
            '_saveLastAnalysisIfNeeded failed: $e',
            name: 'SkillsGapAnalysisScreen',
            error: e,
            stackTrace: st,
          );
        });
  }

  Future<void> _openCourseUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
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

  @override
  void initState() {
    super.initState();
    _jobId = widget.job.id;
    _currentJob = widget.job;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _firestore
        .getSkills()
        .then((map) {
          if (mounted) {
            setState(() => _skillsCatalog = map.isNotEmpty ? map : null);
            // Re-run once catalog is loaded so level-based matching uses canonical ids.
            _updateAnalysis();
          }
        })
        .catchError((e, st) {
          developer.log(
            'getSkills failed: $e',
            name: 'SkillsGapAnalysisScreen',
            error: e,
            stackTrace: st,
          );
        });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((DocumentSnapshot<Map<String, dynamic>> s) {
            if (!mounted) return;
            _userSnap = s;
            _updateAnalysis();
            setState(() {});
          });
      _jobSub = _firestore.getJobStream(_jobId).listen((JobDocument? job) {
        if (!mounted) return;
        setState(() {
          if (job != null) _currentJob = job;
        });
        _updateAnalysis();
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

  /// Single source of truth: weighted match % (high-priority skills count more).
  int get _displayMatchPercent {
    if (_gapResult == null) return 0;
    return _gapResult!.weightedMatchPercentage.round();
  }

  /// Strong count from gap result: number of matched required skills.
  int get _displayStrongCount {
    if (_gapResult == null) return _strongCount;
    return _gapResult!.matchedSkills.length;
  }

  /// Developing: not used when we only care about skill existence; always 0 from service.
  int get _displayDevelopingCount {
    if (_gapResult == null) return _developingCount;
    final developing = _items.where((e) => e.isDeveloping).length;
    return developing;
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
  /// fallback only when no detailed category distribution is available.
  int _categoryMatch(bool technical) {
    if (_gapResult != null) {
      final d = _gapResult!.skillMatchDistribution;
      final matched = technical ? d.technicalMatched : d.softMatched;
      final total = technical ? d.technicalTotal : d.softTotal;
      if (total > 0) {
        return ((matched / total) * 100).round().clamp(0, 100);
      }
    }
    final list = _items.where((e) => e.isTechnical == technical).toList();
    if (list.isEmpty) return 0;
    final sum = list.fold<int>(
      0,
      (s, i) => s + (i.completionPercent > 100 ? 100 : i.completionPercent),
    );
    return (sum / list.length).round();
  }

  /// Simulated market demand % (0–100) for a skill. Used for Market Demand Insight card.
  static int _marketDemandForSkill(String name, bool isTechnical) {
    final n = normalizeSkillName(name);
    const technicalDemand = <String, int>{
      'data analysis': 84,
      'data visualization': 79,
      'sql': 80,
      'python': 85,
      'javascript': 82,
      'statistics': 76,
      'programming': 85,
      'database management': 78,
      'business analysis': 72,
      'excel': 77,
      'tableau': 75,
    };
    const softDemand = <String, int>{
      'communication': 90,
      'problem solving': 82,
      'critical thinking': 80,
      'leadership': 85,
      'teamwork': 86,
      'attention to detail': 75,
      'collaboration': 84,
    };
    final lookup = isTechnical ? technicalDemand : softDemand;
    if (lookup[n] != null) return lookup[n]!;
    for (final e in lookup.entries) {
      if (n.contains(e.key) || e.key.contains(n)) return e.value;
    }
    return isTechnical ? 65 : 70;
  }

  Widget _buildMarketDemandInsightCard() {
    final criticalSorted = _items.where((e) => e.isCriticalGap).toList()
      ..sort((a, b) => b.gapPercent.compareTo(a.gapPercent));
    final topCritical = criticalSorted
        .take(3)
        .map(
          (item) => MarketDemandItem(
            name: item.name,
            isTechnical: item.isTechnical,
            demandPercent: _marketDemandForSkill(item.name, item.isTechnical),
          ),
        )
        .toList();

    return AnalysisMarketDemandCard(topCriticalItems: topCritical);
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
              Text(
                'Analyzing your skills...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
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
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700]),
                ),
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

    final signedInUser = FirebaseAuth.instance.currentUser;
    if (!_loading && signedInUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          title: const Text('Skills gap analysis'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'Sign in to compare your profile with this job.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_loading && _items.isEmpty) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          title: const Text('Skills gap analysis'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.data_saver_off_rounded, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(
                  'No data available',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'There are no skill requirements to analyze for this role yet, or your profile has no skills to compare.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
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
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth > 0
                            ? constraints.maxWidth
                            : MediaQuery.sizeOf(context).width - 40;
                        return SizedBox(
                          width: maxWidth,
                          child: TabBar(
                            isScrollable: true,
                            labelColor: theme.colorScheme.primary,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            unselectedLabelColor: Colors.grey.shade600,
                            unselectedLabelStyle: const TextStyle(fontSize: 14),
                            indicatorColor: theme.colorScheme.primary,
                            indicatorWeight: 3,
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.only(
                              left: 0,
                              right: 16,
                            ),
                            tabs: const [
                              Tab(text: 'Overview'),
                              Tab(text: 'Skills Breakdown'),
                              Tab(text: 'Recommendations'),
                            ],
                          ),
                        );
                      },
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
    return AnalysisHeader(
      title: _currentJob.title,
      matchPercent: _displayMatchPercent,
      matchLabel: _displayLabel,
      strongCount: _displayStrongCount,
      developingCount: _displayDevelopingCount,
      criticalCount: _displayCriticalCount,
      onBackTap: () => Navigator.pop(context),
    );
  }

  /// Readiness level from match %: Beginner (<50), Needs Improvement (50-69), Almost Job Ready (70-89), Job Ready (90+).
  Widget _buildReadinessLevelCard() {
    return AnalysisReadinessCard(
      score: _displayMatchPercent,
      matchedSkillsCount: _displayStrongCount,
      totalSkillsCount: _items.length,
    );
  }

  Widget _buildTopPrioritySkillGapCard() {
    final critical = _items.where((e) => e.isCriticalGap).toList()
      ..sort((a, b) => b.gapPercent.compareTo(a.gapPercent));
    final top = critical.isNotEmpty ? critical.first : null;
    if (top == null) return const SizedBox.shrink();

    return AnalysisTopPriorityGapCard(
      skillName: top.name,
      requiredPercent: top.requiredPercent,
      currentPercent: top.currentPercent,
      gapPercent: top.gapPercent,
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
            _buildReadinessLevelCard(),
            const SizedBox(height: 24),
            if (_items.any((e) => e.isCriticalGap)) ...[
              _buildTopPrioritySkillGapCard(),
              const SizedBox(height: 24),
            ],
            _buildMarketDemandInsightCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AnalysisMatchScoreCard(
                    label: 'Technical',
                    percent: technicalMatch,
                    color: theme.colorScheme.secondary,
                    icon: Icons.bar_chart_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnalysisMatchScoreCard(
                    label: 'Soft Skills',
                    percent: softMatch,
                    color: theme.colorScheme.primary,
                    icon: Icons.bolt_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Matched skills & Missing skills (from Firestore gap result)
            if (_gapResult != null) ...[
              SkillsListSection(
                title: 'Matched skills',
                skills: _gapResult!.matchedSkills,
                icon: Icons.check_circle_rounded,
                color: AppTheme.success,
              ),
              const SizedBox(height: 16),
              SkillsListSection(
                title: 'Skills below requirement (by priority)',
                skills: _gapResult!.missingSkills,
                icon: Icons.warning_amber_rounded,
                color: AppTheme.warning,
                highPrioritySkills: _gapResult!.missingSkills
                    .where((s) => _gapResult!.isHighPriority(s))
                    .toSet(),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkillCategoryComparisonCard() {
    final technicalMatch = _categoryMatch(true);
    final softMatch = _categoryMatch(false);
    return AnalysisSkillCategoryComparisonCard(
      technicalMatch: technicalMatch,
      softMatch: softMatch,
    );
  }

  Widget _buildSkillsBreakdownTab() {
    final technicalItems = _items.where((e) => e.isTechnical).toList();
    final softItems = _items.where((e) => !e.isTechnical).toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSkillCategoryComparisonCard(),
            const SizedBox(height: 24),
            if (technicalItems.isNotEmpty) ...[
              const Text(
                'Technical Skills',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 12),
              ...technicalItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BreakdownSkillTile(
                    name: item.name,
                    currentPercent: item.currentPercent,
                    requiredPercent: item.requiredPercent,
                    gapPercent: item.gapPercent,
                    isCriticalGap: item.isCriticalGap,
                    isStrong: item.isStrong,
                    isDeveloping: item.isDeveloping,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (softItems.isNotEmpty) ...[
              const Text(
                'Soft Skills',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 12),
              ...softItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BreakdownSkillTile(
                    name: item.name,
                    currentPercent: item.currentPercent,
                    requiredPercent: item.requiredPercent,
                    gapPercent: item.gapPercent,
                    isCriticalGap: item.isCriticalGap,
                    isStrong: item.isStrong,
                    isDeveloping: item.isDeveloping,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            const AnalysisStatusGuideCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    final top3 = _gapResult?.missingSkillsByPriority.take(3).toList() ??
        _gapResult?.missingSkills.take(3).toList() ??
        [];
    final criticalSet = _currentJob.gapCriticalSkillNames
        .map((s) => normalizeSkillName(s))
        .where((s) => s.isNotEmpty)
        .toSet();

    return RecommendationsTab(
      skillNames: top3,
      criticalGapNames: criticalSet,
    );
  }

  /// Improvement per skill if completed: 100 / totalSkills. Expected score = current + sum(improvements).
  int _expectedScoreIfSkillCompleted(int currentScore, SkillGapItem item) {
    final total = _items.length;
    if (total == 0) return currentScore;
    final per = 100.0 / total;
    final currentContribution = item.requiredPercent > 0
        ? (item.currentPercent / item.requiredPercent) * per
        : 0.0;
    final fullContribution = per;
    final add = fullContribution - currentContribution;
    return (currentScore + add).round().clamp(0, 100);
  }

  /// Same source of truth: GapAnalysisService (weighted %, missing skills by priority, skill→courses).
  Widget _buildGapSummaryCard() {
    final r = _gapResult!;
    final total = r.matchedSkills.length + r.missingSkills.length;
    final matchedFrac = total > 0 ? r.matchedSkills.length / total : 0.0;
    final flexMatched = total > 0
        ? (matchedFrac * 100).round().clamp(0, 100)
        : 50;
    final flexMissing = 100 - flexMatched;
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
          AnalysisGapSummaryHeader(
            matchPercentage: r.matchPercentage,
            matchedSkillsCount: r.matchedSkills.length,
            missingSkillsCount: r.missingSkills.length,
            flexMatched: flexMatched,
            flexMissing: flexMissing,
          ),
          AnalysisMissingSkillsSection(
            missingSkills: r.missingSkills,
            highPrioritySkills: r.missingSkills
                .where((s) => r.isHighPriority(s))
                .toSet(),
            skillRecommendations: r.skillRecommendations,
            skillCourseResources: r.skillCourseResources,
            skillGapSeverity: r.skillGapSeverity,
            onOpenCourseUrl: _openCourseUrl,
          ),
          AnalysisLearningPathSection(
            steps: r.learningPath,
            onOpenCourseUrl: _openCourseUrl,
          ),
        ],
      ),
    );
  }

  Widget _buildHighPrioritySkillsSection(List<SkillGapItem> criticalSkills) {
    final currentScore = _displayMatchPercent;
    final skills = criticalSkills.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final item = entry.value;
      final expected = _expectedScoreIfSkillCompleted(currentScore, item);
      final improvement = expected - currentScore;
      return HighPrioritySkillViewData(
        index: i,
        name: item.name,
        isTechnical: item.isTechnical,
        gapPercent: item.gapPercent,
        currentPercent: item.currentPercent,
        requiredPercent: item.requiredPercent,
        currentScore: currentScore,
        expectedScore: expected,
        improvement: improvement,
      );
    }).toList();
    return AnalysisHighPrioritySkillsSection(
      skills: skills,
    );
  }

  Widget _buildMediumPrioritySkillsSection(
    List<SkillGapItem> developingSkills,
  ) {
    final currentScore = _displayMatchPercent;
    final skills = developingSkills.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final item = entry.value;
      final expected = _expectedScoreIfSkillCompleted(currentScore, item);
      return MediumPrioritySkillViewData(
        index: i,
        name: item.name,
        gapPercent: item.gapPercent,
        expectedScore: expected,
      );
    }).toList();
    return AnalysisMediumPrioritySkillsSection(skills: skills);
  }

}

