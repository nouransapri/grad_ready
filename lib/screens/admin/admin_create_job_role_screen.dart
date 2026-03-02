import 'package:flutter/material.dart';
import '../../models/job_role.dart';
import '../../services/firestore_service.dart';
import '../login_screen.dart';

// ألوان مطابقة للتصميم
const Color _headerPurpleStart = Color(0xFF5B4B9E);
const Color _headerPurpleEnd = Color(0xFF7B6BBE);
const Color _tabSelectedBg = Color(0xFFE8E4F5);
const Color _purple = Color(0xFF5B4B9E);
const Color _saveButtonGrey = Color(0xFFE0E0E0);
const Color _saveButtonText = Color(0xFF757575);

/// شاشة إنشاء دور وظيفي جديد (تفتح عند الضغط على Add New Job Role).
class AdminCreateJobRoleScreen extends StatefulWidget {
  const AdminCreateJobRoleScreen({super.key});

  @override
  State<AdminCreateJobRoleScreen> createState() => _AdminCreateJobRoleScreenState();
}

class _AdminCreateJobRoleScreenState extends State<AdminCreateJobRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _salaryController = TextEditingController();
  final _skillNameController = TextEditingController();
  final _proficiencyController = TextEditingController(text: '70');

  String _demand = 'Medium'; // High, Medium, Low
  bool _isTechnicalSkill = true;
  final List<SkillProficiency> _technicalSkills = [];
  final List<SkillProficiency> _softSkills = [];
  final FirestoreService _firestore = FirestoreService();
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _salaryController.dispose();
    _skillNameController.dispose();
    _proficiencyController.dispose();
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
                  const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
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
                icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
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
                const Text(
                  'Create New Job Role',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 24, color: Colors.black54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _field('Job Title *', _titleController, hint: 'e.g., Senior Data Analyst'),
            const SizedBox(height: 14),
            _field('Description *', _descriptionController,
                hint: 'Brief description of the role...', maxLines: 4),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _field('Category *', _categoryController, hint: 'e.g., Data & A'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
            _field('Salary Range', _salaryController, hint: 'e.g., \$70K - \$110K'),
            const SizedBox(height: 20),
            const Text(
              'Required Skills',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add technical and soft skills with required proficiency levels (0-100%).',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Material(
                    color: _isTechnicalSkill ? _purple : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => setState(() => _isTechnicalSkill = true),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            'Technical',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isTechnicalSkill ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    color: !_isTechnicalSkill ? _purple : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => setState(() => _isTechnicalSkill = false),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Text(
                            'Soft Skills',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: !_isTechnicalSkill ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _skillNameController,
                      decoration: const InputDecoration(
                        hintText: 'Skill name...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _proficiencyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: _addSkill,
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.add, color: Colors.black87, size: 24),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Technical Skills: ${_technicalSkills.length}   Soft Skills: ${_softSkills.length}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _technicalSkills.isEmpty && _softSkills.isEmpty
                  ? Column(
                      children: [
                        const Text(
                          'No skills added yet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add skills using the form above',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._technicalSkills.asMap().entries.map((e) => _skillChip(
                            e.value.name, e.value.percent, true, e.key)),
                        ..._softSkills.asMap().entries.map((e) => _skillChip(
                            e.value.name, e.value.percent, false, e.key)),
                      ],
                    ),
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
                        Icon(Icons.save_outlined, size: 20, color: _saveButtonText),
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

  Widget _field(String label, TextEditingController controller,
      {String? hint, int maxLines = 1}) {
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _skillChip(String name, int percent, bool isTechnical, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$name ($percent%)', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isTechnical) {
                        _technicalSkills.removeAt(index);
                      } else {
                        _softSkills.removeAt(index);
                      }
                    });
                  },
                  child: const Icon(Icons.close, size: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addSkill() {
    final name = _skillNameController.text.trim();
    if (name.isEmpty) return;
    final percent = int.tryParse(_proficiencyController.text) ?? 70;
    final clamped = percent.clamp(0, 100);
    setState(() {
      if (_isTechnicalSkill) {
        _technicalSkills.add(SkillProficiency(name: name, percent: clamped));
      } else {
        _softSkills.add(SkillProficiency(name: name, percent: clamped));
      }
      _skillNameController.clear();
      _proficiencyController.text = '70';
    });
  }

  Future<void> _saveJobRole() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _categoryController.text.trim();
    if (title.isEmpty || description.isEmpty || category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Job Title, Description, and Category')),
      );
      return;
    }

    final salaryMatch = RegExp(r'\$?\s*(\d+)\s*[Kk]\s*[-–]\s*\$?\s*(\d+)\s*[Kk]')
        .firstMatch(_salaryController.text.trim());
    int salaryMinK = 50;
    int salaryMaxK = 100;
    if (salaryMatch != null) {
      salaryMinK = int.tryParse(salaryMatch.group(1) ?? '50') ?? 50;
      salaryMaxK = int.tryParse(salaryMatch.group(2) ?? '100') ?? 100;
    }

    final requiredSkills = [
      ..._technicalSkills.map((s) => s.name),
      ..._softSkills.map((s) => s.name),
    ];

    final job = JobRole(
      id: '',
      title: title,
      description: description,
      category: category,
      isHighDemand: _demand == 'High',
      salaryMinK: salaryMinK,
      salaryMaxK: salaryMaxK,
      requiredSkills: requiredSkills,
      requiredCourses: [],
      technicalSkillsWithLevel: _technicalSkills,
      softSkillsWithLevel: _softSkills,
      criticalSkills: [],
    );

    setState(() => _saving = true);
    try {
      await _firestore.addJob(job);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job role saved successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
