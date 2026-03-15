import 'package:flutter/material.dart';
import '../../models/job_document.dart';
import '../../services/firestore_service.dart';
import '../login_screen.dart';
import 'job_skills_editor.dart';

// ألوان مطابقة للتصميم
const Color _headerPurpleStart = Color(0xFF5B4B9E);
const Color _headerPurpleEnd = Color(0xFF7B6BBE);
const Color _tabSelectedBg = Color(0xFFE8E4F5);
const Color _saveButtonGrey = Color(0xFFE0E0E0);
const Color _saveButtonText = Color(0xFF757575);

/// شاشة إنشاء أو تعديل دور وظيفي (تفتح من Add New Job Role أو Edit على بطاقة الوظيفة).
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
  bool _saving = false;
  JobDocument? get _editingJob => widget.job;

  @override
  void initState() {
    super.initState();
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
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(topPadding),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + bottomPadding),
              child: _buildFormCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double topPadding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_headerPurpleStart, _headerPurpleEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
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
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _tabChip('Overview', Icons.dashboard_rounded, false),
              const SizedBox(width: 6),
              _tabChip('Jobs', Icons.work_outline_rounded, true),
              const SizedBox(width: 6),
              _tabChip('Analytics', Icons.analytics_outlined, false),
              const SizedBox(width: 6),
              _tabChip('Market', Icons.storage_rounded, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, IconData icon, bool selected) {
    return Expanded(
      child: Material(
        color: selected ? _tabSelectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? _headerPurpleStart : Colors.white,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? _headerPurpleStart : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _editingJob != null ? 'Edit Job' : 'Create New Job Role',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    size: 24,
                    color: Colors.black54,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _field(
              'Job Title *',
              _titleController,
              hint: 'e.g., Senior Data Analyst',
            ),
            const SizedBox(height: 14),
            _field(
              'Description *',
              _descriptionController,
              hint: 'Brief description of the role...',
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'Category *',
                    _categoryController,
                    hint: 'e.g., Data & A',
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
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
                            onChanged: (v) =>
                                setState(() => _demand = v ?? 'Medium'),
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
              hint: 'e.g., \$70K - \$110K',
            ),
            const SizedBox(height: 20),
            JobSkillsEditor(
              technicalSkills: _technicalSkills,
              softSkills: _softSkills,
              tools: _tools,
              onTechnicalChanged: (v) => setState(() => _technicalSkills = v),
              onSoftChanged: (v) => setState(() => _softSkills = v),
              onToolsChanged: (v) => setState(() => _tools = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: _saveButtonGrey,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _saving ? null : _saveJobRole,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.save_outlined,
                          size: 20,
                          color: _saveButtonText,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _saving ? 'Saving...' : 'Save Job Role',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _saveButtonText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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
            borderRadius: BorderRadius.circular(10),
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
        final jobId = '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch % 100000}';
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
        SnackBar(content: Text(doc != null ? 'تم تحديث الوظيفة' : 'تم حفظ الوظيفة')),
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
