import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/job_document.dart';
import '../../models/job_role.dart';
import '../../services/firestore_service.dart';
import '../../utils/skill_utils.dart';
import 'job_skills_editor.dart';

const Color _pageBg = Color(0xFF0A0A0A);
const Color _createPageBg = Color(0xFFF0F2F5);
const Color _cardWhite = Colors.white;
const Color _statRed = Color(0xFFD32F2F);

/// Create or edit a job role (from Add New Job Role or Edit on a job card).
class AdminCreateJobRoleScreen extends StatefulWidget {
  final JobDocument? job;

  const AdminCreateJobRoleScreen({super.key, this.job});

  @override
  State<AdminCreateJobRoleScreen> createState() =>
      _AdminCreateJobRoleScreenState();
}

class _AdminCreateJobRoleScreenState extends State<AdminCreateJobRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _salaryController = TextEditingController();

  String _demand = 'Medium';
  List<JobSkillItem> _technicalSkills = [];
  List<JobSkillItem> _softSkills = [];
  List<JobSkillItem> _tools = [];
  final FirestoreService _firestore = FirestoreService();
  late final Stream<List<JobRole>> _jobsStream = _firestore.getJobs();
  bool _saving = false;
  JobDocument? get _editingJob => widget.job;
  bool get _isCreate => widget.job == null;

  void _onFormFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFormFieldChanged);
    _descriptionController.addListener(_onFormFieldChanged);
    _categoryController.addListener(_onFormFieldChanged);
    _salaryController.addListener(_onFormFieldChanged);
    final job = widget.job;
    if (job != null) {
      _titleController.text = job.title;
      _descriptionController.text = job.description;
      _categoryController.text = job.category;
      _salaryController.text = job.salary.maximum > 0
          ? '\$${(job.salary.minimum / 1000).round()}K - \$${(job.salary.maximum / 1000).round()}K'
          : '';
      _demand = job.isActive ? 'High' : 'Medium';
      _technicalSkills = List.from(job.technicalSkills);
      _softSkills = List.from(job.softSkills);
      _tools = List.from(job.tools);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormFieldChanged);
    _descriptionController.removeListener(_onFormFieldChanged);
    _categoryController.removeListener(_onFormFieldChanged);
    _salaryController.removeListener(_onFormFieldChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  bool get _canSave {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    final total = _technicalSkills.length + _softSkills.length + _tools.length;
    return title.isNotEmpty &&
        description.isNotEmpty &&
        category.isNotEmpty &&
        total >= 5;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreate) {
      return _buildCreateScaffold(context);
    }
    return _buildEditScaffold(context);
  }

  Widget _buildCreateScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _createPageBg,
      body: Column(
        children: [
          _createGradientHeader(context, topPadding, primary, secondary),
          Expanded(
            child: StreamBuilder<List<JobRole>>(
              stream: _jobsStream,
              builder: (context, snapshot) {
                final jobs = snapshot.data ?? [];
                final categories = jobs
                    .map((j) => j.category)
                    .where((c) => c.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final highDemandCount = jobs.where((j) => j.isHighDemand).length;

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _CreateStatCard(
                              value: '${jobs.length}',
                              label: 'Total Roles',
                              color: primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CreateStatCard(
                              value: '$highDemandCount',
                              label: 'High Demand',
                              color: _statRed,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CreateStatCard(
                              value: '${categories.isEmpty ? 0 : categories.length}',
                              label: 'Categories',
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Material(
                        color: _cardWhite,
                        elevation: 2,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Create New Job Role',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.maybePop(context),
                                      icon: const Icon(Icons.close_rounded, color: Colors.black54),
                                      tooltip: 'Close',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _jobFields(isCreate: true),
                                const SizedBox(height: 20),
                                const Divider(height: 1),
                                const SizedBox(height: 16),
                                JobSkillsEditor(
                                  technicalSkills: _technicalSkills,
                                  softSkills: _softSkills,
                                  tools: _tools,
                                  createMode: true,
                                  onTechnicalChanged: (v) => setState(() => _technicalSkills = v),
                                  onSoftChanged: (v) => setState(() => _softSkills = v),
                                  onToolsChanged: (v) => setState(() => _tools = v),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 88 + bottomInset),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            color: _createPageBg,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
            child: FilledButton(
              onPressed: (_canSave && !_saving) ? _saveJobRole : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFBDBDBD),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_saving)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.save_rounded, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    _saving ? 'Saving…' : 'Save Job Role',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _createGradientHeader(
    BuildContext context,
    double topPadding,
    Color primary,
    Color secondary,
  ) {
    const tabs = [
      (label: 'Overview', icon: Icons.dashboard_rounded),
      (label: 'Jobs', icon: Icons.work_outline_rounded),
      (label: 'Analytics', icon: Icons.analytics_outlined),
      (label: 'Skills', icon: Icons.school_rounded),
    ];
    const selectedTabIndex = 1;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(8, topPadding + 8, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primary, secondary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                tooltip: 'Back',
              ),
              const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
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
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                tooltip: 'Log out',
              ),
            ],
          ),
          const SizedBox(height: 14),
          IgnorePointer(
            child: Row(
              children: List.generate(tabs.length, (i) {
                final isSelected = i == selectedTabIndex;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
                    child: Material(
                      color: isSelected ? Theme.of(context).colorScheme.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tabs[i].icon,
                              size: 20,
                              color: isSelected ? primary : Colors.white,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tabs[i].label,
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
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditScaffold(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const title = 'Edit Job Role';

    return Scaffold(
      backgroundColor: _pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _jobInfoCard(title),
                    const SizedBox(height: 16),
                    _skillsCard(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.maybePop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white38,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _saveJobRole,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_saving)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(Icons.save_rounded, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _saving ? 'Saving…' : 'Save Changes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
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
    );
  }

  Widget _jobInfoCard(String title) {
    return Material(
      color: _cardWhite,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _jobFields(isCreate: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobFields({required bool isCreate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(
          'Job Title *',
          _titleController,
          hint: isCreate ? 'e.g., Senior Data Analyst' : 'e.g., Data Analyst',
        ),
        const SizedBox(height: 14),
        _field(
          'Description *',
          _descriptionController,
          hint: isCreate ? 'Brief description of the role...' : 'Brief description of the role…',
          maxLines: 4,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                'Category *',
                _categoryController,
                hint: isCreate ? 'e.g., Data & A' : 'e.g., Data & Analytics',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demand',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _demand,
                        isExpanded: true,
                        items: ['High', 'Medium', 'Low']
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _demand = v ?? 'Medium'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _field(
          'Salary Range',
          _salaryController,
          hint: isCreate ? r'e.g., $70K - $110K' : r'e.g., $65K - $95K',
        ),
      ],
    );
  }

  Widget _skillsCard() {
    return Material(
      color: _cardWhite,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: JobSkillsEditor(
          technicalSkills: _technicalSkills,
          softSkills: _softSkills,
          tools: _tools,
          createMode: false,
          onTechnicalChanged: (v) => setState(() => _technicalSkills = v),
          onSoftChanged: (v) => setState(() => _softSkills = v),
          onToolsChanged: (v) => setState(() => _tools = v),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveJobRole() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    if (title.isEmpty || description.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill Job Title, Description, and Category'),
        ),
      );
      return;
    }

    final totalSkills = _technicalSkills.length + _softSkills.length + _tools.length;
    if (totalSkills < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 5 skills (Technical, Soft, or Tools)'),
        ),
      );
      return;
    }

    final salaryMatch = RegExp(
      r'\$?\s*(\d+)\s*[Kk]\s*[-–]\s*\$?\s*(\d+)\s*[Kk]',
    ).firstMatch(_salaryController.text.trim());
    int salaryMinK = 50;
    int salaryMaxK = 100;
    if (salaryMatch != null) {
      salaryMinK = int.tryParse(salaryMatch.group(1) ?? '50') ?? 50;
      salaryMaxK = int.tryParse(salaryMatch.group(2) ?? '100') ?? 100;
    }

    final allSkills = [..._technicalSkills, ..._softSkills, ..._tools];
    final avgLevel = allSkills.fold<int>(0, (a, s) => a + s.requiredLevel) / allSkills.length;

    setState(() => _saving = true);
    try {
      final doc = _editingJob;
      if (doc != null) {
        final updated = JobDocument(
          id: doc.id,
          jobId: doc.jobId,
          title: title,
          category: category,
          industry: doc.industry,
          experienceLevel: doc.experienceLevel,
          description: description,
          technicalSkills: _technicalSkills,
          softSkills: _softSkills,
          tools: _tools,
          certifications: doc.certifications,
          education: doc.education,
          experience: doc.experience,
          salary: SalaryInfo(currency: 'USD', minimum: salaryMinK * 1000, maximum: salaryMaxK * 1000, period: 'Yearly'),
          createdAt: doc.createdAt,
          updatedAt: DateTime.now(),
          isActive: _demand == 'High',
          totalSkillsCount: totalSkills,
          averageRequiredLevel: avgLevel,
        );
        await _firestore.updateJobDocument(updated);
      } else {
        final jobId = canonicalJobId(title, category);
        final newDoc = JobDocument(
          id: '',
          jobId: jobId,
          title: title,
          category: category,
          industry: '',
          experienceLevel: 'Mid-Level',
          description: description,
          technicalSkills: _technicalSkills,
          softSkills: _softSkills,
          tools: _tools,
          certifications: const [],
          education: const EducationRequirement(),
          experience: const ExperienceRequirement(),
          salary: SalaryInfo(currency: 'USD', minimum: salaryMinK * 1000, maximum: salaryMaxK * 1000, period: 'Yearly'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: _demand == 'High',
          totalSkillsCount: totalSkills,
          averageRequiredLevel: avgLevel,
        );
        await _firestore.addJobDocument(newDoc);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(doc != null ? 'Job updated' : 'Job saved')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CreateStatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _CreateStatCard({
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
