import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/skill_document.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

/// Add or Edit Skill screen. viewOnly = true for View Details from Library.
class AdminSkillEditScreen extends StatefulWidget {
  final SkillDocument? skill;
  final bool viewOnly;

  const AdminSkillEditScreen({super.key, this.skill, this.viewOnly = false});

  @override
  State<AdminSkillEditScreen> createState() => _AdminSkillEditScreenState();
}

const _skillTypeOptions = ['Technical', 'Soft', 'Tool'];
const _skillCategoryOptions = [
  'Programming',
  'Framework',
  'Database',
  'Interpersonal',
  'Cognitive',
  'Design',
  'Tool',
  'Soft',
];

String _coerceSkillType(String? raw) {
  final t = (raw ?? '').trim();
  if (t == 'Tools') return 'Tool';
  if (_skillTypeOptions.contains(t)) return t;
  return 'Technical';
}

String _coerceSkillCategory(String? raw) {
  final t = (raw ?? '').trim();
  if (t == 'Tools') return 'Tool';
  if (_skillCategoryOptions.contains(t)) return t;
  return 'Programming';
}

Future<void> _openExternalUrl(BuildContext context, String rawUrl) async {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https'))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid link.')),
    );
    return;
  }
  final canOpen = await canLaunchUrl(uri);
  if (!canOpen) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link.')),
    );
    return;
  }
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open this link.')),
    );
  }
}

class _AdminSkillEditScreenState extends State<AdminSkillEditScreen> {
  final _firestore = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late String _type;
  late String _category;
  late String _demandLevel;
  late bool _trending;
  late String _growthRate;
  late String _salaryImpact;
  bool _saving = false;

  List<SkillCourse> _courses = [];
  List<SkillCertification> _certifications = [];
  List<SkillLearningResource> _learningResources = [];
  List<SkillPracticeProject> _practiceProjects = [];

  @override
  void initState() {
    super.initState();
    final s = widget.skill;
    _nameController = TextEditingController(text: s?.skillName ?? '');
    _descController = TextEditingController(text: s?.description ?? '');
    _type = _coerceSkillType(s?.type);
    _category = _coerceSkillCategory(s?.category);
    _demandLevel = s?.demandLevel ?? 'High';
    _trending = s?.trending ?? false;
    _growthRate = s?.growthRate ?? '';
    _salaryImpact = s?.averageSalaryImpact ?? '';
    _courses = List.from(s?.courses ?? []);
    _certifications = List.from(s?.certifications ?? []);
    _learningResources = List.from(s?.learningResources ?? []);
    _practiceProjects = List.from(s?.practiceProjects ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.viewOnly || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.skill?.skillId ?? FirestoreService.skillNameToSkillId(_nameController.text.trim());
      final updated = SkillDocument(
        skillId: id,
        skillName: _nameController.text.trim(),
        description: _descController.text.trim(),
        type: _type,
        category: _category,
        subCategory: widget.skill?.subCategory ?? '',
        aliases: widget.skill?.aliases ?? [],
        difficultyLevel: widget.skill?.difficultyLevel,
        learningCurve: widget.skill?.learningCurve,
        averageTimeToLearn: widget.skill?.averageTimeToLearn,
        prerequisites: widget.skill?.prerequisites ?? [],
        relatedSkills: widget.skill?.relatedSkills ?? [],
        advancedSkills: widget.skill?.advancedSkills ?? [],
        demandLevel: _demandLevel,
        trending: _trending,
        growthRate: _growthRate.isEmpty ? null : _growthRate,
        averageSalaryImpact: _salaryImpact.isEmpty ? null : _salaryImpact,
        usedInJobs: widget.skill?.usedInJobs ?? [],
        courses: _courses,
        certifications: _certifications,
        learningResources: _learningResources,
        practiceProjects: _practiceProjects,
        totalJobsUsingSkill: widget.skill?.totalJobsUsingSkill ?? 0,
        averageRequiredLevel: widget.skill?.averageRequiredLevel ?? 0,
        mostCommonPriority: widget.skill?.mostCommonPriority,
        icon: widget.skill?.icon,
        color: widget.skill?.color,
        isActive: widget.skill?.isActive ?? true,
        replacedBy: widget.skill?.replacedBy,
        createdAt: widget.skill?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _firestore.addOrUpdateSkillDocument(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skill saved.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDestructiveAction() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(AppConstants.dialogConfirmTitle),
        content: const Text(AppConstants.dialogConfirmDestructiveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(AppConstants.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(AppConstants.actionDelete),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skill = widget.skill;
    final isNew = skill == null;
    final viewOnly = widget.viewOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text(viewOnly ? 'View: ${skill?.skillName ?? ""}' : (isNew ? 'Add Skill' : 'Edit: ${skill.skillName}')),
        actions: viewOnly
            ? []
            : [
                if (!isNew)
                  IconButton(
                    color: Colors.red,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      final confirm = await _confirmDestructiveAction();
                      if (confirm == true && mounted) {
                        await _firestore.deleteSkillDocument(skill.skillId);
                        Navigator.pop(context);
                      }
                    },
                  ),
                TextButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic info
              _sectionTitle(theme, 'Basic Information'),
              TextFormField(
                controller: _nameController,
                readOnly: viewOnly,
                decoration: const InputDecoration(labelText: 'Skill Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: _skillTypeOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: viewOnly ? null : (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _skillCategoryOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: viewOnly ? null : (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 20),
              _sectionTitle(theme, 'Description'),
              TextFormField(
                controller: _descController,
                readOnly: viewOnly,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              _sectionTitle(theme, 'Market Data'),
              DropdownButtonFormField<String>(
                value: _demandLevel,
                decoration: const InputDecoration(labelText: 'Demand Level', border: OutlineInputBorder()),
                items: const ['Very High', 'High', 'Medium', 'Low'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: viewOnly ? null : (v) => setState(() => _demandLevel = v ?? _demandLevel),
              ),
              const SizedBox(height: 12),
              SwitchListTile(title: const Text('Trending'), value: _trending, onChanged: viewOnly ? null : (v) => setState(() => _trending = v)),
              if (!viewOnly) ...[
                TextFormField(initialValue: _growthRate, decoration: const InputDecoration(labelText: 'Growth rate (e.g. 18%)', border: OutlineInputBorder()), onChanged: (v) => _growthRate = v),
                const SizedBox(height: 8),
                TextFormField(initialValue: _salaryImpact, decoration: const InputDecoration(labelText: 'Salary impact (e.g. +15%)', border: OutlineInputBorder()), onChanged: (v) => _salaryImpact = v),
              ],
              const SizedBox(height: 24),
              _sectionTitle(theme, 'Courses (${_courses.length})'),
              ..._courses.map((c) => _CourseTile(course: c, viewOnly: viewOnly, onRemove: () async {
                if (await _confirmDestructiveAction()) {
                  setState(() => _courses.remove(c));
                }
              })),
              if (_courses.isEmpty) Text('No courses yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              if (!viewOnly) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(icon: const Icon(Icons.add_rounded, size: 20), label: const Text('Add Course'), onPressed: _addCourse)),
              const SizedBox(height: 16),
              _sectionTitle(theme, 'Certifications (${_certifications.length})'),
              ..._certifications.map((c) => _CertTile(cert: c, viewOnly: viewOnly, onRemove: () async {
                if (await _confirmDestructiveAction()) {
                  setState(() => _certifications.remove(c));
                }
              })),
              if (_certifications.isEmpty) Text('No certifications.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              if (!viewOnly) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(icon: const Icon(Icons.add_rounded, size: 20), label: const Text('Add Certification'), onPressed: _addCertification)),
              const SizedBox(height: 16),
              _sectionTitle(theme, 'Free Resources (${_learningResources.length})'),
              ..._learningResources.map((r) => _ResourceTile(resource: r, viewOnly: viewOnly, onRemove: () async {
                if (await _confirmDestructiveAction()) {
                  setState(() => _learningResources.remove(r));
                }
              })),
              if (_learningResources.isEmpty) Text('No resources.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              if (!viewOnly) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(icon: const Icon(Icons.add_rounded, size: 20), label: const Text('Add Resource'), onPressed: _addResource)),
              const SizedBox(height: 16),
              _sectionTitle(theme, 'Practice Projects (${_practiceProjects.length})'),
              ..._practiceProjects.map((p) => _ProjectTile(project: p, viewOnly: viewOnly, onRemove: () async {
                if (await _confirmDestructiveAction()) {
                  setState(() => _practiceProjects.remove(p));
                }
              })),
              if (_practiceProjects.isEmpty) Text('No projects.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              if (!viewOnly) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton.icon(icon: const Icon(Icons.add_rounded, size: 20), label: const Text('Add Project'), onPressed: _addProject)),
              const SizedBox(height: 16),
              _sectionTitle(theme, 'Statistics'),
              Text('Used in ${widget.skill?.totalJobsUsingSkill ?? 0} jobs · Avg level ${(widget.skill?.averageRequiredLevel ?? 0).toStringAsFixed(0)}%', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              if (!viewOnly) FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(height: 24, child: Center(child: CircularProgressIndicator())) : const Text('Save Skill')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
    );
  }

  Future<void> _addCourse() async {
    final titleC = TextEditingController();
    final platformC = TextEditingController();
    final urlC = TextEditingController();
    final ratingC = TextEditingController(text: '4.5');
    var level = 'Beginner';
    var isPrimary = false;
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Course'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: platformC, decoration: const InputDecoration(labelText: 'Platform (e.g. Coursera)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: urlC, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: ratingC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rating (0-5)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: level, decoration: const InputDecoration(labelText: 'Level', border: OutlineInputBorder()), items: const ['Beginner', 'Intermediate', 'Advanced'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setDialogState(() => level = v ?? level)),
                const SizedBox(height: 8),
                CheckboxListTile(title: const Text('Primary recommendation'), value: isPrimary, onChanged: (v) => setDialogState(() => isPrimary = v ?? false), controlAffinity: ListTileControlAffinity.leading),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (added == true && mounted) {
      final id = 'course_${DateTime.now().millisecondsSinceEpoch}';
      setState(() => _courses.add(SkillCourse(courseId: id, title: titleC.text.trim(), platform: platformC.text.trim(), url: urlC.text.trim(), rating: double.tryParse(ratingC.text) ?? 4.5, level: level, isPrimary: isPrimary)));
    }
  }

  Future<void> _addCertification() async {
    final nameC = TextEditingController();
    final providerC = TextEditingController();
    final urlC = TextEditingController();
    final costC = TextEditingController(text: 'Free');
    var difficulty = 'Intermediate';
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Certification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: providerC, decoration: const InputDecoration(labelText: 'Provider', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: urlC, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: costC, decoration: const InputDecoration(labelText: 'Cost', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: difficulty, decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()), items: const ['Beginner', 'Intermediate', 'Advanced'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setDialogState(() => difficulty = v ?? difficulty)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (added == true && mounted) {
      final id = 'cert_${DateTime.now().millisecondsSinceEpoch}';
      setState(() => _certifications.add(SkillCertification(certId: id, name: nameC.text.trim(), provider: providerC.text.trim(), url: urlC.text.trim(), cost: costC.text.trim(), validityYears: 3, difficulty: difficulty)));
    }
  }

  Future<void> _addResource() async {
    final titleC = TextEditingController();
    final urlC = TextEditingController();
    final sourceC = TextEditingController();
    var type = 'Article';
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Resource'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: urlC, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: sourceC, decoration: const InputDecoration(labelText: 'Source', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()), items: const ['Article', 'Video', 'Book', 'Documentation'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setDialogState(() => type = v ?? type)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (added == true && mounted) {
      setState(() => _learningResources.add(SkillLearningResource(type: type, title: titleC.text.trim(), url: urlC.text.trim(), source: sourceC.text.trim(), isFree: true)));
    }
  }

  Future<void> _addProject() async {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final hoursC = TextEditingController(text: '10');
    final tutorialC = TextEditingController();
    final githubC = TextEditingController();
    var difficulty = 'Beginner';
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Practice Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descC, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: hoursC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated hours', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: difficulty, decoration: const InputDecoration(labelText: 'Difficulty', border: OutlineInputBorder()), items: const ['Beginner', 'Intermediate', 'Advanced'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setDialogState(() => difficulty = v ?? difficulty)),
                const SizedBox(height: 12),
                TextField(controller: tutorialC, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Tutorial URL (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: githubC, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'GitHub URL (optional)', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (added == true && mounted) {
      setState(() => _practiceProjects.add(SkillPracticeProject(title: titleC.text.trim(), description: descC.text.trim(), difficulty: difficulty, estimatedHours: int.tryParse(hoursC.text) ?? 10, githubUrl: githubC.text.trim().isEmpty ? null : githubC.text.trim(), tutorialUrl: tutorialC.text.trim().isEmpty ? null : tutorialC.text.trim())));
    }
  }
}

class _CourseTile extends StatelessWidget {
  final SkillCourse course;
  final bool viewOnly;
  final Future<void> Function()? onRemove;

  const _CourseTile({required this.course, this.viewOnly = false, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(children: [
          if (course.isPrimary) Padding(padding: const EdgeInsets.only(right: 6), child: Text('⭐', style: theme.textTheme.titleMedium)),
          Expanded(child: Text(course.title, style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
        subtitle: Text('${course.platform} · ${course.rating}/5 · ${course.level}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.open_in_new_rounded), onPressed: () => _openExternalUrl(context, course.url), tooltip: 'Open link'),
            if (!viewOnly && onRemove != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                onPressed: () => onRemove?.call(),
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}

class _CertTile extends StatelessWidget {
  final SkillCertification cert;
  final bool viewOnly;
  final Future<void> Function()? onRemove;

  const _CertTile({required this.cert, this.viewOnly = false, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(cert.name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${cert.provider} · ${cert.cost}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.open_in_new_rounded), onPressed: () => _openExternalUrl(context, cert.url), tooltip: 'Open link'),
            if (!viewOnly && onRemove != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                onPressed: () => onRemove?.call(),
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final SkillLearningResource resource;
  final bool viewOnly;
  final Future<void> Function()? onRemove;

  const _ResourceTile({required this.resource, this.viewOnly = false, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_iconForType(resource.type), size: 20),
        title: Text(resource.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${resource.type} · ${resource.source}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.open_in_new_rounded), onPressed: () => _openExternalUrl(context, resource.url), tooltip: 'Open link'),
            if (!viewOnly && onRemove != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                onPressed: () => onRemove?.call(),
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'video': return Icons.video_library_rounded;
      case 'book': return Icons.menu_book_rounded;
      case 'documentation': return Icons.description_rounded;
      default: return Icons.article_rounded;
    }
  }
}

class _ProjectTile extends StatelessWidget {
  final SkillPracticeProject project;
  final bool viewOnly;
  final Future<void> Function()? onRemove;

  const _ProjectTile({required this.project, this.viewOnly = false, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('${project.difficulty} · ${project.estimatedHours}h'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (project.tutorialUrl != null) IconButton(icon: const Icon(Icons.open_in_new_rounded), onPressed: () => _openExternalUrl(context, project.tutorialUrl!), tooltip: 'Tutorial'),
            if (!viewOnly && onRemove != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                onPressed: () => onRemove?.call(),
                tooltip: 'Remove',
              ),
          ],
        ),
      ),
    );
  }
}
