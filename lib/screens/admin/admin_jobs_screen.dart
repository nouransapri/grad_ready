import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/job_document.dart';
import '../../services/firestore_service.dart';
import 'admin_create_job_role_screen.dart';

const Color _red = Color(0xFFD32F2F);
const Color _chipCategoryBg = Color(0xFFE8E4F5);
const Color _chipCategoryText = Color(0xFF5B4B9E);
const Color _chipHighDemandBg = Color(0xFFFBEBEB);
const Color _chipHighDemandText = Color(0xFFC62828);
const Color _chipGrowingBg = Color(0xFFE6F8ED);
const Color _chipGrowingText = Color(0xFF2E7D32);
const Color _chipSkillsBg = Color(0xFFE3F2FD);
const Color _chipSkillsText = Color(0xFF1976D2);
const Color _chipSalaryBg = Color(0xFFE8F5E9);
const Color _chipSalaryText = Color(0xFF1B5E20);
const Color _marketingPinkBg = Color(0xFFFCE4EC);

/// Admin Jobs tab: stat cards, add button, search, and role list.
class AdminJobsContent extends StatefulWidget {
  const AdminJobsContent({super.key});

  @override
  State<AdminJobsContent> createState() => _AdminJobsContentState();
}

class _AdminJobsContentState extends State<AdminJobsContent> {
  final FirestoreService _firestore = FirestoreService();
  /// Stable stream so [StreamBuilder] does not reset subscription every build.
  late final Stream<List<JobDocument>> _jobsStream = _firestore.getJobDocuments();
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All Categories';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleSearchRebuild() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const horizontalPadding = 16.0;

    return StreamBuilder<List<JobDocument>>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Could not load jobs.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        final theme = Theme.of(context);
        final jobs = snapshot.data ?? [];
        final categories =
            jobs
                .map((j) => j.category)
                .where((c) => c.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final highDemandCount = jobs.where((j) => j.isActive).length;
        final filtered = _filterJobs(jobs);
        const displayCount = 15;
        final listCount =
            filtered.length < displayCount ? filtered.length : displayCount;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                14,
                horizontalPadding,
                8,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Expanded(
                        child: _JobsStatCard(
                          value: '${jobs.length}',
                          label: 'Total Roles',
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _JobsStatCard(
                          value: '$highDemandCount',
                          label: 'High Demand',
                          color: _red,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _JobsStatCard(
                          value: '${categories.isEmpty ? 0 : categories.length}',
                          label: 'Categories',
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 0,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AdminCreateJobRoleScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Add New Job Role',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (kDebugMode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          if (!kDebugMode) return;
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text(
                                'Replace all jobs with 15 new roles?',
                              ),
                              content: const Text(
                                'This deletes every job in the database and replaces them with 15 new roles (technical, soft skills, and tools per role). This cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Yes, replace'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true || !context.mounted) return;
                          try {
                            await FirestoreService.clearAllJobsAndSeed();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Done: all jobs replaced with 15 new roles.',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Update failed. Sign in as admin and ensure the admin account has the custom claim (admin). Error: $e',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Replace all jobs with 15 new roles'),
                      ),
                    ),
                  if (!kDebugMode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Danger actions are disabled in production mode.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _scheduleSearchRebuild(),
                      decoration: InputDecoration(
                        hintText: 'Search job roles…',
                        hintStyle:
                            TextStyle(color: Colors.grey[500], fontSize: 14),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.grey[600],
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PopupMenuButton<String>(
                    onSelected: (v) => setState(() => _selectedCategory = v),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'All Categories',
                        child: Text('All Categories'),
                      ),
                      ...categories.map(
                        (c) => PopupMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _selectedCategory,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey[700],
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting &&
                jobs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  8,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final job = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _JobRoleCard(
                          job: job,
                          onEdit: () => _openEditJob(context, job),
                        ),
                      );
                    },
                    childCount: listCount,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  20 + bottomPadding,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      'Showing first $listCount of ${filtered.length} roles',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _openEditJob(BuildContext context, JobDocument job) async {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCreateJobRoleScreen(job: job),
      ),
    );
  }

  List<JobDocument> _filterJobs(List<JobDocument> jobs) {
    var list = jobs;
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((j) {
        return j.title.toLowerCase().contains(q) ||
            j.description.toLowerCase().contains(q) ||
            j.category.toLowerCase().contains(q);
      }).toList();
    }
    if (_selectedCategory != 'All Categories') {
      list = list.where((j) => j.category == _selectedCategory).toList();
    }
    return list;
  }
}

class _JobsStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _JobsStatCard({
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
        borderRadius: BorderRadius.circular(14),
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
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }
}

class _JobRoleCard extends StatelessWidget {
  final JobDocument job;
  final VoidCallback onEdit;

  const _JobRoleCard({required this.job, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final count = job.totalSkillsCount > 0
        ? job.totalSkillsCount
        : (job.technicalSkills.length + job.softSkills.length + job.tools.length);
    final salaryRange = job.salary.maximum > 0
        ? '\$${(job.salary.minimum / 1000).round()}K - \$${(job.salary.maximum / 1000).round()}K'
        : 'Not specified';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            job.description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                job.category,
                _categoryChipColor(job.category),
                _chipCategoryText,
              ),
              _chip(
                job.isActive ? 'High Demand' : 'Growing Demand',
                job.isActive ? _chipHighDemandBg : _chipGrowingBg,
                job.isActive ? _chipHighDemandText : _chipGrowingText,
              ),
              _chip('$count skills', _chipSkillsBg, _chipSkillsText),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _chipSalaryBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              salaryRange,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _chipSalaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryChipColor(String category) {
    if (category.toLowerCase().contains('marketing')) {
      return _marketingPinkBg;
    }
    return _chipCategoryBg;
  }

  Widget _chip(String label, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
