import 'package:flutter/material.dart';
import '../models/job_document.dart';
import '../services/firestore_service.dart';
import 'skills_gap_analysis_screen.dart';

/// Loads the latest job document from Firestore so admin edits sync while viewing.
class JobRequirementsScreen extends StatelessWidget {
  final JobDocument job;

  const JobRequirementsScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firestore = FirestoreService();
    return StreamBuilder<JobDocument?>(
      stream: firestore.getJobStream(job.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFFF0F0F0),
            body: Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF0F0F0),
            appBar: AppBar(
              title: const Text('Job requirements'),
              backgroundColor: const Color(0xFF2A6CFF),
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load job details. Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
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
        final live = snapshot.data;
        if (live == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF0F0F0),
            appBar: AppBar(
              title: const Text('Job requirements'),
              backgroundColor: const Color(0xFF2A6CFF),
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.work_off_outlined,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No data available for this job.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
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
        return _JobRequirementsContent(job: live);
      },
    );
  }
}

class _JobRequirementsContent extends StatelessWidget {
  final JobDocument job;

  const _JobRequirementsContent({required this.job});

  static const _gradientStart = Color(0xFF2A6CFF);
  static const _gradientEnd = Color(0xFF9226FF);
  static const _purple = Color(0xFF9226FF);
  static const _blue = Color(0xFF2A6CFF);

  List<JobSkillItem> get _technicalSkills => job.technicalSkills;

  List<JobSkillItem> get _softSkills => job.softSkills;

  List<String> get _criticalSkills {
    final all = [...job.technicalSkills, ...job.softSkills, ...job.tools];
    final critical = all
        .where((s) => s.priority.toLowerCase() == 'critical')
        .map((s) => s.name.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (critical.isNotEmpty) return critical;
    return all
        .map((s) => s.name.trim())
        .where((s) => s.isNotEmpty)
        .take(4)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeaderBox(context)),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildJobRequirementsSection(context),
                          if (_technicalSkills.isEmpty &&
                              _softSkills.isEmpty &&
                              job.tools.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: Material(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No skill requirements are listed for this role yet.',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          _buildTechnicalSkills(),
                          _buildSoftSkills(),
                          _buildCriticalSkillsSection(),
                          _buildReadyForAnalysis(context),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SkillsGapAnalysisScreen(job: job),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Start Skills Gap Analysis',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A6CFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBox(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 32,
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
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.gps_fixed, color: Colors.white, size: 20),
              SizedBox(width: 6),
              Text(
                'Target Job Role',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            job.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          Text(
            job.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 15,
              height: 1.3,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _headerTag(job.category, const Color(0xFFB0BEC5)),
              if (job.isActive)
                _headerTag(
                  'High Demand',
                  const Color(0xFFE8F5E9),
                  isGreen: true,
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected Salary Range',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _salaryRangeShort(job),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.white38),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Required Skills',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_requiredSkillsCount(job)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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

  Widget _headerTag(String label, Color bg, {bool isGreen = false}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isGreen ? const Color(0xFFC8E6C9) : bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGreen) ...[
              Icon(Icons.trending_up, size: 16, color: Colors.green[700]),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isGreen ? Colors.green[800] : Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobRequirementsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: _blue, size: 24),
              SizedBox(width: 8),
              Text(
                'Job Requirements',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These are the skills and proficiency levels required for this position. Your profile will be compared against these requirements.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(String name, int percent, Color barColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1C1E),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: Colors.grey[300],
            color: barColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 6),
          Text(
            'Required proficiency level',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalSkills() {
    final list = _technicalSkills;
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: _purple),
              const SizedBox(width: 8),
              Text(
                'Technical Skills (${list.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...list.map(
            (s) => _buildSkillCard(s.name, s.requiredLevel.clamp(0, 100), _purple),
          ),
        ],
      ),
    );
  }

  Widget _buildSoftSkills() {
    final list = _softSkills;
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: _blue),
              const SizedBox(width: 8),
              Text(
                'Soft Skills (${list.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...list.map(
            (s) => _buildSkillCard(s.name, s.requiredLevel.clamp(0, 100), _blue),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalSkillsSection() {
    final list = _criticalSkills;
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.whatshot, color: Colors.orange[700], size: 22),
              const SizedBox(width: 8),
              const Text(
                'Critical Skills',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'These high-priority skills are essential for success in this role:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: list
                .map(
                  (name) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyForAnalysis(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_gradientStart, _gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready for Analysis?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We\'ll compare your skills and courses with these job requirements to calculate your readiness score and identify skill gaps.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _checkItem('Detailed gap analysis'),
          _checkItem('Personalized recommendations'),
          _checkItem('Skills breakdown & insights'),
        ],
      ),
    );
  }

  Widget _checkItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  static String _salaryRangeShort(JobDocument job) {
    final min = job.salary.minimum;
    final max = job.salary.maximum;
    if (min <= 0 && max <= 0) return 'Not specified';
    return '\$${(min / 1000).round()}K - \$${(max / 1000).round()}K';
  }

  static int _requiredSkillsCount(JobDocument job) {
    if (job.totalSkillsCount > 0) return job.totalSkillsCount;
    return job.technicalSkills.length + job.softSkills.length + job.tools.length;
  }
}
