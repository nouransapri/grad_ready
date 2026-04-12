import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../models/job_role.dart';
import '../models/skill.dart';
import '../services/firestore_service.dart';
import '../services/gap_analysis_service.dart';
import '../utils/skill_utils.dart';
import 'recommendations_tab.dart';

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

class SkillsGapAnalysisScreen extends StatefulWidget {
  final JobRole job;

  const SkillsGapAnalysisScreen({super.key, required this.job});

  @override
  State<SkillsGapAnalysisScreen> createState() =>
      _SkillsGapAnalysisScreenState();
}

class _SkillsGapAnalysisScreenState extends State<SkillsGapAnalysisScreen>
    with SingleTickerProviderStateMixin {
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
  final Set<String> _lastAnalysisSavedJobIds = {};
  Map<String, Skill>? _skillsCatalog;
  int _updateAnalysisVersion = 0;

  List<SkillProficiency> get _technicalSkills {
    if (_currentJob.technicalSkillsWithLevel.isNotEmpty) {
      return _currentJob.technicalSkillsWithLevel;
    }
    final n = (_currentJob.requiredSkills.length / 2).ceil();
    return _currentJob.requiredSkills
        .take(n)
        .map((s) => SkillProficiency(name: s, percent: 70))
        .toList();
  }

  List<SkillProficiency> get _softSkills {
    if (_currentJob.softSkillsWithLevel.isNotEmpty) {
      return _currentJob.softSkillsWithLevel;
    }
    final n = (_currentJob.requiredSkills.length / 2).ceil();
    return _currentJob.requiredSkills
        .skip(n)
        .map((s) => SkillProficiency(name: s, percent: 70))
        .toList();
  }

  /// Maps profile level (Basic/Intermediate/Advanced) to a 0–100 percent (same as create_profile).
  static int _levelToPercent(dynamic level) {
    if (level == null) return 0;
    if (level is int) return level.clamp(0, 100);
    if (level is double) return level.round().clamp(0, 100);
    final s = level.toString().trim();
    if (s.isEmpty) return 0;
    final normalized = s.toLowerCase();
    switch (normalized) {
      case 'advanced':
      case 'expert':
        return 95;
      case 'intermediate':
      case 'intermidiate':
      case 'mid':
        return 65;
      case 'basic':
      case 'beginner':
        return 35;
      default:
        final num = int.tryParse(s);
        return num != null ? num.clamp(0, 100) : 35;
    }
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

  static int _userLevelFallbackByName(Map<String, dynamic> userData, String skillName) {
    final skills = userData['skills'] as List?;
    if (skills == null) return 0;
    final target = normalizeSkillName(skillName);
    int best = 0;
    for (final s in skills) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(
        s.map((k, v) => MapEntry(k.toString(), v)),
      );
      final name = (m['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final n = normalizeSkillName(name);
      if (!(n == target || n.contains(target) || target.contains(n))) continue;
      final percent = _levelToPercent(m['level'] ?? m['points']);
      if (percent > best) best = percent;
    }
    return best;
  }

  Future<void> _updateAnalysis() async {
    if (_userSnap == null) return;
    final version = ++_updateAnalysisVersion;
    final userData = _userSnap!.data();
    final mergedCatalog = GapAnalysisService.mergeJobRequiredSkillsCatalog(
      _currentJob,
      _skillsCatalog,
    );
    final useLevelBased =
        _currentJob.requiredSkillsWithLevel.isNotEmpty && userData != null;

    List<SkillGapItem> items = [];
    GapAnalysisResult? gapResult;

    if (useLevelBased) {
      final userLevels = GapAnalysisService.collectUserLevelsBySkillId(
        userData,
        mergedCatalog,
      );
      final requiredSorted = List<JobRequiredSkill>.from(
        _currentJob.requiredSkillsWithLevel,
      )..sort((a, b) => b.importance.compareTo(a.importance));
      for (final req in requiredSorted) {
        final skill = _catalogSkillById(mergedCatalog, req.skillId);
        final name = skill?.name ?? req.skillId;
        final requiredPercent = req.requiredLevel.clamp(0, 100);
        int currentPercent = _userLevelForSkillId(req.skillId, userLevels);
        if (currentPercent == 0) {
          currentPercent = _userLevelFallbackByName(userData, name);
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
      final criticalNames = _currentJob.criticalSkills
          .map((e) => normalizeSkillName(e))
          .toSet();
      Map<String, int> userSkillPercent = {};
      final skills = userData?['skills'] as List?;
      if (skills != null) {
        for (final s in skills) {
          final m = s is Map
              ? Map<String, dynamic>.from(s)
              : <String, dynamic>{};
          final name = (m['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          final percent = _levelToPercent(m['level']);
          final key = normalizeSkillName(name);
          if (percent > (userSkillPercent[key] ?? 0)) {
            userSkillPercent[key] = percent;
          }
        }
      }
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

  /// Updates user profile `last_analysis` once per job role per session.
  void _saveLastAnalysisIfNeeded() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _currentJob.id.isEmpty) return;
    if (_lastAnalysisSavedJobIds.contains(_currentJob.id)) return;
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
    _lastAnalysisSavedJobIds.add(_currentJob.id);
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
          'last_analysis': analysisDetails,
          'last_analysis_title': _currentJob.title,
          'last_analysis_at': FieldValue.serverTimestamp(),
        })
        .catchError((e, st) {
          debugPrint('_saveLastAnalysisIfNeeded failed: $e');
          if (kDebugMode) debugPrintStack(stackTrace: st);
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
          debugPrint('getSkills failed: $e');
          if (kDebugMode) debugPrintStack(stackTrace: st);
        });
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
    final topCritical = criticalSorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Market Demand Insight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'How often these skills appear in job postings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (topCritical.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Text(
                "Great! You don't have any critical skill gaps.",
                style: TextStyle(fontSize: 14, color: Color(0xFF166534)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ...topCritical.asMap().entries.map((entry) {
              final item = entry.value;
              final demand = _marketDemandForSkill(item.name, item.isTechnical);
              final level = demand >= 75
                  ? 'High Demand'
                  : demand >= 60
                  ? 'Moderate Demand'
                  : 'Low Demand';
              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < topCritical.length - 1 ? 12 : 0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                    ),
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
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1C1E),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          Text(
                            '$demand%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            item.isTechnical ? '💻 Technical' : '🤝 Soft Skill',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '• $level',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: demand >= 75
                                  ? const Color(0xFF15803D)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: demand / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
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
                  Text(
                    'Back to Requirements',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Target Role',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _currentJob.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Gap summary card (inside gradient card)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Animated circular progress 0% → calculated %
                  TweenAnimationBuilder<double>(
                    key: ValueKey(_displayMatchPercent),
                    tween: Tween(begin: 0, end: _displayMatchPercent / 100),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: value.clamp(0.0, 1.0),
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(value * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _displayLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_displayMatchPercent),
                      tween: Tween(begin: 0, end: _displayMatchPercent / 100),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _headerStatCard(
                          '$_displayStrongCount',
                          'Strong',
                          Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _headerStatCard(
                          '$_displayDevelopingCount',
                          'Developing',
                          Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _headerStatCard(
                          '$_displayCriticalCount',
                          'Critical Gaps',
                          Colors.white.withValues(alpha: 0.25),
                        ),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Readiness level from match %: Beginner (<50), Needs Improvement (50-69), Almost Job Ready (70-89), Job Ready (90+).
  Widget _buildReadinessLevelCard() {
    final score = _displayMatchPercent;
    final matched = _displayStrongCount;
    final total = _items.length;
    String label;
    String emoji;
    List<Color> gradientColors;
    String message;
    if (score >= 90) {
      label = 'Job Ready';
      emoji = '🎯';
      gradientColors = [const Color(0xFF10B981), const Color(0xFF059669)];
      message =
          'You have strong alignment with this role. Focus on polishing your interview skills and portfolio.';
    } else if (score >= 70) {
      label = 'Beginner';
      emoji = '🚀';
      gradientColors = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      message = 'Start with the priority skills to build a strong foundation.';
    } else if (score >= 50) {
      label = 'Needs Improvement';
      emoji = '📚';
      gradientColors = [const Color(0xFFF59E0B), const Color(0xFFD97706)];
      message =
          'Build foundational skills in the critical gap areas to improve your match.';
    } else {
      label = 'Beginner';
      emoji = '🚀';
      gradientColors = [const Color(0xFFEF4444), const Color(0xFFDC2626)];
      message = 'Start with the priority skills to build a strong foundation.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Your Current Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'You match ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    children: [
                      TextSpan(
                        text: '$matched',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' out of ',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      TextSpan(
                        text: '$total',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' required skills',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPrioritySkillGapCard() {
    final critical = _items.where((e) => e.isCriticalGap).toList()
      ..sort((a, b) => b.gapPercent.compareTo(a.gapPercent));
    final top = critical.isNotEmpty ? critical.first : null;
    if (top == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDBA74), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFFEA580C),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Top Priority Skill Gap',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEA580C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            top.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'High Priority',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'This skill is required at ',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    children: [
                      TextSpan(
                        text: '${top.requiredPercent}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      TextSpan(
                        text: ' but you currently have ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      TextSpan(
                        text: '${top.currentPercent}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: 'Gap: ',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                    children: [
                      TextSpan(
                        text: '${top.gapPercent}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      const TextSpan(text: ' improvement needed'),
                    ],
                  ),
                ),
              ],
            ),
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
                  child: _matchScoreCard(
                    'Technical',
                    technicalMatch,
                    theme.colorScheme.secondary,
                    Icons.bar_chart_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _matchScoreCard(
                    'Soft Skills',
                    softMatch,
                    theme.colorScheme.primary,
                    Icons.bolt_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Matched skills & Missing skills (from Firestore gap result)
            if (_gapResult != null) ...[
              _SkillsListSection(
                title: 'Matched skills',
                skills: _gapResult!.matchedSkills,
                icon: Icons.check_circle_rounded,
                color: AppTheme.success,
              ),
              const SizedBox(height: 16),
              _SkillsListSection(
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
            const Text(
              'All Skills Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1C1E),
              ),
            ),
            const SizedBox(height: 14),
            ..._items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SkillAnalysisCard(item: item),
              ),
            ),
            const SizedBox(height: 24),
            _buildStatusGuide(),
          ],
        ),
      ),
    );
  }

  Widget _matchScoreCard(
    String label,
    int percent,
    Color color,
    IconData icon,
  ) {
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$percent%',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Match Score',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCoverageSummaryCard() {
    final total = _items.length;
    final matched = _items.where((e) => e.isStrong).length;
    final missing = _items.where((e) => e.isCriticalGap).length;
    final coveragePct = total > 0 ? (matched / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gps_fixed,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill Coverage Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _coverageStatTile('$total', 'Total Required'),
              _coverageStatTile('$matched', 'Matched'),
              _coverageStatTile('$missing', 'Missing'),
              _coverageStatTile('$coveragePct%', 'Coverage'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _legendItem(const Color(0xFF4ADE80), 'Matched'),
              _legendItem(const Color(0xFF60A5FA), 'Developing'),
              _legendItem(const Color(0xFFFB923C), 'Critical'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _coverageStatTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _buildSkillCategoryComparisonCard() {
    final technicalMatch = _categoryMatch(true);
    final softMatch = _categoryMatch(false);
    final diff = (technicalMatch - softMatch).abs();
    final isBalanced = diff <= 15;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart,
                  color: Color(0xFF7C3AED),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill Category Comparison',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Coverage breakdown by skill type',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _categoryComparisonRow(
            icon: '💻',
            label: 'Technical Skills',
            percent: technicalMatch,
            barColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFDBEAFE),
          ),
          const SizedBox(height: 20),
          _categoryComparisonRow(
            icon: '🤝',
            label: 'Soft Skills',
            percent: softMatch,
            barColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFEDE9FE),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isBalanced
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBalanced
                    ? const Color(0xFFBBF7D0)
                    : const Color(0xFFFED7AA),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.info_outline,
                  color: isBalanced
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFEA580C),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBalanced ? 'Balanced Skill Profile' : 'Skill balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isBalanced
                              ? const Color(0xFF166534)
                              : const Color(0xFF9A3412),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBalanced
                            ? 'Great balance! Both technical and soft skills are well-developed.'
                            : (technicalMatch >= softMatch + 15)
                            ? 'Your technical skills ($technicalMatch%) are stronger than soft skills ($softMatch%). Consider developing soft skills for better job readiness.'
                            : 'Your soft skills ($softMatch%) are stronger than technical skills ($technicalMatch%). Consider strengthening technical skills for this role.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isBalanced
                              ? const Color(0xFF166534)
                              : const Color(0xFF9A3412),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryComparisonRow({
    required String icon,
    required String label,
    required int percent,
    required Color barColor,
    required Color bgColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1C1E),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: barColor,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Current Coverage',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${100 - percent}% gap remaining',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
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
            _buildSkillCoverageSummaryCard(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _breakdownSummaryCard(
                    'Technical Skills',
                    technicalMatch,
                    const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _breakdownSummaryCard(
                    'Soft Skills',
                    softMatch,
                    const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                  child: _BreakdownSkillTile(item: item),
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
                  child: _BreakdownSkillTile(item: item),
                ),
              ),
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
    final top3 = _gapResult?.missingSkillsByPriority.take(3).toList() ??
        _gapResult?.missingSkills.take(3).toList() ??
        [];
    final criticalSet = _currentJob.criticalSkills.map((s) => s.trim()).toSet();

    return RecommendationsTab(
      skillNames: top3,
      criticalGapNames: criticalSet,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your Personalized Learning Path',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          Text(
            'Based on your current skills and target role, here\'s a strategic plan to help you bridge the gap and achieve your career goals.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.5,
            ),
            overflow: TextOverflow.fade,
            maxLines: 4,
          ),
        ],
      ),
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

  int get _potentialScoreTop3Critical {
    final total = _items.length;
    if (total == 0) return _displayMatchPercent;
    final current = _displayMatchPercent.toDouble();
    final per = 100.0 / total;
    final critical = _items.where((e) => e.isCriticalGap).toList();
    critical.sort((a, b) => b.gapPercent.compareTo(a.gapPercent));
    var add = 0.0;
    for (final item in critical.take(3)) {
      final currentContribution = item.requiredPercent > 0
          ? (item.currentPercent / item.requiredPercent) * per
          : 0.0;
      add += per - currentContribution;
    }
    return (current + add).round().clamp(0, 100);
  }

  Widget _buildPotentialScoreCard() {
    final current = _displayMatchPercent;
    final potential = _potentialScoreTop3Critical;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 2),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Potential Score Improvement',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Complete these skills to boost your readiness',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Current Score',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$current%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF16A34A),
                  size: 32,
                ),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Potential Score',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$potential%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Focus on top 3 priority skills to see significant improvement',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          Text(
            'Profile vs Job Match: ${r.matchPercentage.toStringAsFixed(0)}% (${r.matchedSkills.length}/${r.matchedSkills.length + r.missingSkills.length} skills)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 18,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Matched ${r.matchedSkills.length} · Below requirement ${r.missingSkills.length}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  flex: flexMatched > 0 ? flexMatched : 1,
                  child: Container(height: 10, color: AppTheme.success),
                ),
                Expanded(
                  flex: flexMissing > 0 ? flexMissing : 1,
                  child: Container(height: 10, color: AppTheme.warning),
                ),
              ],
            ),
          ),
          if (r.missingSkills.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Skills below job requirement — suggested courses',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            ...r.missingSkills.map((s) {
              final isHigh = r.isHighPriority(s);
              final courses = r.skillRecommendations[s] ?? [];
              final courseLinks = r.skillCourseResources[s] ?? [];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isHigh)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'High priority',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.warning,
                              ),
                            ),
                          ),
                        if (r.skillGapSeverity[s] != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r.skillGapSeverity[s]!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (courseLinks.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Suggested courses (tap to open)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: courseLinks
                            .take(3)
                            .map(
                              (c) => InkWell(
                                onTap: c.url.trim().isEmpty
                                    ? null
                                    : () => _openCourseUrl(c.url),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                    horizontal: 2,
                                  ),
                                  child: Text(
                                    c.title.isNotEmpty ? c.title : c.platform,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ] else if (courses.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: Text(
                          'Suggested courses: ${courses.take(3).join(', ')}${courses.length > 3 ? '...' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          if (r.learningPath.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Learning path (by priority)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            ...r.learningPath
                .map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step ${step.stepNumber}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                step.skillName,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (step.suggestedCourseLinks.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: step.suggestedCourseLinks
                                      .take(3)
                                      .map(
                                        (c) => InkWell(
                                          onTap: c.url.trim().isEmpty
                                              ? null
                                              : () => _openCourseUrl(c.url),
                                          child: Text(
                                            c.title.isNotEmpty
                                                ? c.title
                                                : c.platform,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ] else if (step.suggestedCourses.isNotEmpty)
                                Text(
                                  'Resources: ${step.suggestedCourses.take(2).join(', ')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildHighPrioritySkillsSection(List<SkillGapItem> criticalSkills) {
    final currentScore = _displayMatchPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('🔥', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'High Priority Skills',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Focus on these skills first to make the biggest impact on your readiness.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        ...criticalSkills.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final item = entry.value;
          final expected = _expectedScoreIfSkillCompleted(currentScore, item);
          final improvement = expected - currentScore;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _highPrioritySkillCard(
              index: i,
              item: item,
              currentScore: currentScore,
              expectedScore: expected,
              improvement: improvement,
            ),
          );
        }),
      ],
    );
  }

  Widget _highPrioritySkillCard({
    required int index,
    required SkillGapItem item,
    required int currentScore,
    required int expectedScore,
    required int improvement,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7ED), Color(0xFFFEE2E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1C1E),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'High Priority',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      item.isTechnical ? '💻 Technical' : '🤝 Soft Skill',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'Gap: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    children: [
                      TextSpan(
                        text: '${item.gapPercent}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                      TextSpan(
                        text: ' • Improve from ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextSpan(
                        text: '${item.currentPercent}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' to ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      TextSpan(
                        text: '${item.requiredPercent}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text:
                                'Expected Impact: Learning this skill will increase your match score from ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                            children: [
                              TextSpan(
                                text: '$currentScore%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              const TextSpan(text: ' to '),
                              TextSpan(
                                text: '$expectedScore%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              TextSpan(
                                text: ' (+$improvement%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediumPrioritySkillsSection(
    List<SkillGapItem> developingSkills,
  ) {
    final currentScore = _displayMatchPercent;

    if (developingSkills.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Medium Priority Skills',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...developingSkills.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final item = entry.value;
          final expected = _expectedScoreIfSkillCompleted(currentScore, item);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF93C5FD)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$i',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1C1E),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Medium Priority',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Gap: ${item.gapPercent}%',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Improving this skill will boost your score to $expected%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPriorityFocusAreas(List<SkillGapItem> prioritySkills) {
    final critical = _items.where((e) => e.isCriticalGap).toList()
      ..sort((a, b) => b.gapPercent.compareTo(a.gapPercent));
    final developing = _items.where((e) => e.isDeveloping).toList()
      ..sort((a, b) => b.gapPercent.compareTo(a.gapPercent));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHighPrioritySkillsSection(critical),
        const SizedBox(height: 24),
        _buildMediumPrioritySkillsSection(developing),
      ],
    );
  }

  Widget _buildLearningResources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Learning Resources',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1C1E),
          ),
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

  Widget _learningResourceCard(
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 16),
          _timelineRow(
            'Short Term (1-3 months)',
            short,
            Theme.of(context).colorScheme.primary,
            'Focus on developing skills that are close to target',
          ),
          const SizedBox(height: 12),
          _timelineRow(
            'Medium Term (3-6 months)',
            medium,
            Theme.of(context).colorScheme.secondary,
            'Address priority gaps with structured learning',
          ),
          const SizedBox(height: 12),
          _timelineRow(
            'Long Term (6-12 months)',
            long,
            AppTheme.warning,
            'Build expertise in advanced or specialized areas',
          ),
        ],
      ),
    );
  }

  /// Roadmap: critical first (by gap desc), then developing (by gap desc), top 6. Weeks: gap≥50→6, ≥30→4, else 2. Impact: critical&gap≥40→High, critical|gap≥25→Medium, else Low.
  Widget _buildSuggestedLearningRoadmap() {
    final critical = _items.where((e) => e.isCriticalGap).toList()
      ..sort((a, b) => b.gapPercent.compareTo(a.gapPercent));
    final developing = _items.where((e) => e.isDeveloping).toList()
      ..sort((a, b) => b.gapPercent.compareTo(a.gapPercent));
    final steps = <SkillGapItem>[...critical, ...developing].take(6).toList();
    if (steps.isEmpty) return const SizedBox.shrink();

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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggested Learning Roadmap',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Follow this path to close your skill gaps efficiently',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    _roadmapStepCard(
                      step: i + 1,
                      item: steps[i],
                      isCritical: steps[i].isCriticalGap,
                    ),
                    if (i < steps.length - 1)
                      Container(
                        margin: const EdgeInsets.only(left: 19),
                        width: 2,
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE9D5FF),
                              const Color(0xFFBFDBFE),
                              Colors.grey.shade300,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _roadmapStepCard({
    required int step,
    required SkillGapItem item,
    required bool isCritical,
  }) {
    final gap = item.gapPercent;
    final weeks = gap >= 50
        ? 6
        : gap >= 30
        ? 4
        : 2;
    final impact = isCritical && gap >= 40
        ? 'High'
        : (isCritical || gap >= 25)
        ? 'Medium'
        : 'Low';
    final impactColor = impact == 'High'
        ? const Color(0xFFB91C1C)
        : impact == 'Medium'
        ? const Color(0xFFC2410C)
        : const Color(0xFFA16207);
    final impactBg = impact == 'High'
        ? const Color(0xFFFEE2E2)
        : impact == 'Medium'
        ? const Color(0xFFFFEDD5)
        : const Color(0xFFFEF9C3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCritical
                  ? [const Color(0xFFEA580C), const Color(0xFFDC2626)]
                  : [const Color(0xFF2563EB), const Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:
                    (isCritical
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF2563EB))
                        .withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isCritical
                  ? const LinearGradient(
                      colors: [Color(0xFFFED7AA), Color(0xFFFECACA)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: isCritical ? null : const Color(0xFFEFF6FF),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                left: BorderSide(
                  color: isCritical
                      ? const Color(0xFFEA580C)
                      : const Color(0xFF2563EB),
                  width: 4,
                ),
              ),
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
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: impactBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$impact Impact',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: impactColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.isTechnical ? '💻' : '🤝'} ${item.isTechnical ? 'Technical' : 'Soft Skill'} · Gap $gap%',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Estimated learning time: $weeks weeks',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (isCritical) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Priority: Start with this skill',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoadmapTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEDE9FE), Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC4B5FD).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: Colors.amber.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 Roadmap Tip',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Follow the order shown above for maximum efficiency. High-impact skills will boost your job readiness score faster. You can adjust the pace based on your schedule, but try to maintain the priority order.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                    height: 1.5,
                  ),
                  overflow: TextOverflow.fade,
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineRow(
    String period,
    int count,
    Color color,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            '$count Skills',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                period,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1C1E),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
                overflow: TextOverflow.fade,
                maxLines: 2,
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
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 18),
          _statusRow(
            Icons.check_circle,
            AppTheme.success,
            'Strong',
            'You meet or exceed the requirement',
          ),
          const SizedBox(height: 14),
          _statusRow(
            Icons.trending_up_rounded,
            Theme.of(context).colorScheme.primary,
            'Developing',
            'Gap is ≤30% - you\'re close!',
          ),
          const SizedBox(height: 14),
          _statusRow(
            Icons.warning_amber_rounded,
            AppTheme.warning,
            'Critical',
            'Gap is >30% - priority for improvement',
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    IconData icon,
    Color color,
    String boldLabel,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
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

/// Single skill card in Skills Breakdown tab (Critical label + improvement text).
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
              const Icon(
                Icons.show_chart_rounded,
                color: AppTheme.warning,
                size: 20,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1C1E),
                ),
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
                item.isStrong
                    ? AppTheme.success
                    : item.isDeveloping
                    ? AppTheme.primary
                    : AppTheme.warning,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gap: ${item.gapPercent}% improvement needed',
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

/// Section showing a list of skill names (matched or missing).
/// [highPrioritySkills] optionally marks which skills to show with a "High priority" badge.
class _SkillsListSection extends StatelessWidget {
  final String title;
  final List<String> skills;
  final IconData icon;
  final Color color;
  final Set<String>? highPrioritySkills;

  const _SkillsListSection({
    required this.title,
    required this.skills,
    required this.icon,
    required this.color,
    this.highPrioritySkills,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uniqueSkills = <String>[];
    final seen = <String>{};
    for (final s in skills) {
      final key = normalizeSkillName(s);
      if (key.isEmpty || !seen.add(key)) continue;
      uniqueSkills.add(s);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '(${uniqueSkills.length})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          if (uniqueSkills.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'None',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: uniqueSkills.map((s) {
                final isHigh = highPrioritySkills?.contains(s) ?? false;
                final short = s.length > 22 ? '${s.substring(0, 22)}…' : s;
                return Chip(
                  label: Text(
                    short,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: isHigh
                      ? const Icon(
                          Icons.priority_high_rounded,
                          size: 14,
                          color: AppTheme.warning,
                        )
                      : null,
                  backgroundColor: color.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                );
              }).toList(),
            ),
          ],
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
    if (item.isStrong) {
      return const Icon(Icons.check_circle, color: AppTheme.success, size: 22);
    }
    if (item.isDeveloping) {
      return const Icon(
        Icons.trending_up_rounded,
        color: AppTheme.primary,
        size: 22,
      );
    }
    return const Icon(
      Icons.warning_amber_rounded,
      color: AppTheme.warning,
      size: 22,
    );
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
                item.isTechnical
                    ? Icons.bar_chart_rounded
                    : Icons.shield_rounded,
                size: 16,
                color: item.isTechnical
                    ? Theme.of(context).colorScheme.secondary
                    : AppTheme.warning,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1C1E),
                ),
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
