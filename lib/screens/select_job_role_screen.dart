import 'package:flutter/material.dart';
import '../models/job_role.dart';
import '../models/skill.dart';
import '../services/firestore_service.dart';
import '../utils/skill_utils.dart';
import 'job_requirements_screen.dart';

class SelectJobRoleScreen extends StatefulWidget {
  const SelectJobRoleScreen({super.key});

  @override
  State<SelectJobRoleScreen> createState() => _SelectJobRoleScreenState();
}

class _SelectJobRoleScreenState extends State<SelectJobRoleScreen> {
  final TextEditingController _searchController = TextEditingController();
  JobRole? _selectedJob;

  static const _gradientStart = Color(0xFF2A6CFF);
  static const _gradientEnd = Color(0xFF9226FF);

  final _firestoreService = FirestoreService();
  late Stream<List<JobRole>> _jobsStream;
  Map<String, Skill> _skillsCatalog = const {};
  bool _refreshing = false;

  List<JobRole> _filterJobs(List<JobRole> jobs, String query) {
    final q = query.trim();
    final dedupedJobs = _dedupeJobs(jobs);
    if (q.isEmpty) return dedupedJobs;
    final qNorm = normalizeSkillName(q);
    final qAlias = normalizeSkillAliasKey(q);
    return dedupedJobs.where((j) {
      final terms = _jobSearchTerms(j);
      return terms.any((t) {
        final n = normalizeSkillName(t);
        final a = normalizeSkillAliasKey(t);
        return n.contains(qNorm) || a.contains(qAlias);
      });
    }).toList();
  }

  List<JobRole> _dedupeJobs(List<JobRole> jobs) {
    final out = <JobRole>[];
    final seen = <String>{};
    for (final j in jobs) {
      final key = canonicalJobId(j.title, j.category);
      if (seen.add(key)) {
        out.add(j);
      }
    }
    return out;
  }

  void _onSearchChanged() => setState(() {});

  List<String> _jobSearchTerms(JobRole j) {
    final terms = <String>[
      j.title,
      j.description,
      j.category,
      ...j.requiredSkills,
      ...j.criticalSkills,
    ];

    for (final req in j.requiredSkillsWithLevel) {
      final sid = canonicalSkillId(req.skillId);
      if (sid.isEmpty) continue;
      terms.add(sid);
      final skill = _skillsCatalog[sid];
      if (skill != null) {
        terms.add(skill.name);
        terms.addAll(skill.aliases);
      } else {
        terms.add(req.skillId);
      }
    }

    // Keep only non-empty unique values to reduce repeated checks.
    final seen = <String>{};
    final out = <String>[];
    for (final t in terms) {
      final s = t.trim();
      if (s.isEmpty) continue;
      final key = normalizeSkillName(s);
      if (seen.add(key)) out.add(s);
    }
    return out;
  }

  Future<void> _loadSkillsCatalog() async {
    try {
      final catalog = await _firestoreService.getSkills();
      if (!mounted) return;
      setState(() => _skillsCatalog = catalog);
    } catch (_) {
      // Keep search functional even if skills catalog fails.
    }
  }

  @override
  void initState() {
    super.initState();
    _jobsStream = _firestoreService.getJobs();
    _searchController.addListener(_onSearchChanged);
    _loadSkillsCatalog();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JobRole>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Center(
              child: CircularProgressIndicator(color: _gradientStart),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        final allJobs = snapshot.data ?? [];
        final filteredJobs = _filterJobs(allJobs, _searchController.text);

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _buildHeader(),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchCard(),
                              const SizedBox(height: 24),
                              const Text(
                                'Popular Job Roles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1C1E),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final job = filteredJobs[index];
                            final isSelected = _selectedJob?.id == job.id;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _JobCard(
                                job: job,
                                isSelected: isSelected,
                                onSelect: () =>
                                    setState(() => _selectedJob = job),
                              ),
                            );
                          }, childCount: filteredJobs.length),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: _selectedJob == null
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey[400]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'View Job Requirements',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            if (_selectedJob != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JobRequirementsScreen(job: _selectedJob!),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2A6CFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'View Job Requirements',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshData() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) {
      setState(() {
        // Recreate stream to force a fresh subscription.
        _jobsStream = _firestoreService.getJobs();
      });
    }
    await _loadSkillsCatalog();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _refreshing = false;
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          bottom: 24,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'Back',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Target Job Role',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose the position you\'re aiming for.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search for Any Job Role',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g., Data Scientist',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => setState(() {}),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Text(
                      'Select',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobRole job;
  final bool isSelected;
  final VoidCallback onSelect;

  const _JobCard({
    required this.job,
    required this.isSelected,
    required this.onSelect,
  });

  static const _blue = Color(0xFF2A6CFF);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _blue : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: _blue, size: 22),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.35,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _tag(job.category, Colors.grey[200]!, Colors.grey[800]!),
                const SizedBox(width: 8),
                if (job.isHighDemand)
                  _tag(
                    'High Demand',
                    const Color(0xFFE8F5E9),
                    const Color(0xFF2E7D32),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    job.salaryRange,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Text(
                  '${job.requiredSkillsCount} required skills',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label == 'High Demand') ...[
            Icon(Icons.trending_up, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
