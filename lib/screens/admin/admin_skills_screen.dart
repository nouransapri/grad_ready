import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/skill_model.dart';
import '../../services/firestore_service.dart';

class AdminSkillsContent extends StatefulWidget {
  const AdminSkillsContent({super.key});

  @override
  State<AdminSkillsContent> createState() => _AdminSkillsContentState();
}

class _AdminSkillsContentState extends State<AdminSkillsContent> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<SkillModel> _skills = [];
  List<SkillModel> _filtered = [];
  bool _loading = true;
  bool _isGrid = true;

  String _categoryFilter = 'All';
  String _demandFilter = 'All';
  String _orderBy = 'jobCount';
  bool _orderDesc = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _firestore.getSkillModelsOnce();
      if (mounted) {
        setState(() {
          _skills = list;
          _applySearch();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _skills = [];
          _filtered = [];
          _loading = false;
        });
      }
    }
  }

  void _applySearch() {
    final q = _searchController.text.trim().toLowerCase();
    
    var temp = _skills.where((s) {
      if (_categoryFilter != 'All' && s.category != _categoryFilter) return false;
      if (_demandFilter != 'All' && s.demandLevel != _demandFilter) return false;
      return true;
    }).toList();

    if (q.isNotEmpty) {
      temp = temp.where((s) => s.skillName.toLowerCase().contains(q)).toList();
    }

    temp.sort((a, b) {
      if (_orderBy == 'skillName') {
        return _orderDesc ? b.skillName.compareTo(a.skillName) : a.skillName.compareTo(b.skillName);
      } else if (_orderBy == 'jobCount') {
        final jA = a.jobCount ?? 0;
        final jB = b.jobCount ?? 0;
        return _orderDesc ? jB.compareTo(jA) : jA.compareTo(jB);
      }
      return 0;
    });

    _filtered = temp;
  }

  Future<void> _handleBulkUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    
    final file = File(result.files.single.path!);
    final jsonStr = await file.readAsString();
    
    List<Map<String, dynamic>> parsedList = [];
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        for (var item in decoded) {
          if (item is Map<String, dynamic>) {
            parsedList.add(item);
          } else if (item is Map) {
            parsedList.add(Map<String, dynamic>.from(item));
          }
        }
      } else {
        throw FormatException("Expected a JSON array of skills.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid JSON file: $e')),
        );
      }
      return;
    }
    
    bool clearExisting = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Upload'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You are about to upload ${parsedList.length} skills.'),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Clear existing skills before uploading?'),
                    value: clearExisting,
                    onChanged: (val) {
                      setDialogState(() {
                        clearExisting = val ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Upload'),
                ),
              ],
            );
          }
        );
      }
    );
    
    if (confirmed != true) return;
    if (!mounted) return;
    
    setState(() => _loading = true);
    try {
      final skillModelsToUpload = parsedList.map((m) => SkillModel.fromFirestore('', m)).toList();
      await _firestore.uploadSkillsBatch(skillModelsToUpload, clearExisting: clearExisting);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk upload complete.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) _load();
    }
  }

  void _openSkillDialog([SkillModel? skill]) {
    final isEditing = skill != null;
    final nameCtrl = TextEditingController(text: skill?.skillName);
    final urlCtrl = TextEditingController(text: skill?.courseUrl);
    final platformCtrl = TextEditingController(text: skill?.platform);
    
    String cat = skill?.category ?? 'Programming';
    String dem = skill?.demandLevel ?? 'Medium';
    double count = (skill?.jobCount ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16, right: 16, top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isEditing ? 'Edit Skill' : 'Add Skill',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Skill Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: cat,
                      items: ['Programming', 'Framework', 'Interpersonal', 'Cognitive', 'Design', 'Other', 'Technical', 'Soft Skill']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setModalState(() => cat = v!),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: dem,
                      items: ['Very High', 'High', 'Medium', 'Low']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setModalState(() => dem = v!),
                      decoration: const InputDecoration(labelText: 'Demand Level'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlCtrl,
                      decoration: const InputDecoration(labelText: 'Course URL'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: platformCtrl,
                      decoration: const InputDecoration(labelText: 'Platform'),
                    ),
                    const SizedBox(height: 12),
                    Text('Job Count: ${count.toInt()}'),
                    Slider(
                      value: count,
                      min: 0,
                      max: 500,
                      divisions: 100,
                      label: count.toInt().toString(),
                      onChanged: (v) => setModalState(() => count = v),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final n = nameCtrl.text.trim();
                        if (n.isEmpty) return;
                        final newSkill = SkillModel(
                          id: skill?.id ?? '',
                          skillName: n,
                          category: cat,
                          courseUrl: urlCtrl.text.trim().isNotEmpty ? urlCtrl.text.trim() : null,
                          platform: platformCtrl.text.trim().isNotEmpty ? platformCtrl.text.trim() : null,
                          jobCount: count.toInt(),
                          demandLevel: dem,
                        );
                        
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() => _loading = true);
                        if (isEditing) {
                          await _firestore.updateSkillModel(newSkill);
                        } else {
                          await _firestore.uploadSkillsBatch([newSkill]);
                        }
                        if (!mounted) return;
                        _load();
                      },
                      child: const Text('Save'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _deleteSkill(SkillModel skill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Skill'),
        content: Text('Are you sure you want to delete ${skill.skillName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      )
    );
    if (confirm == true) {
      if (!mounted) return;
      setState(() => _loading = true);
      await _firestore.deleteSkill(skill.id);
      if (!mounted) return;
      _load();
    }
  }

  void _deleteAllSkills() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warning: Delete All Skills'),
        content: const Text('Are you absolutely sure? This will permanently delete all skills from the database. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      )
    );
    if (confirm == true) {
      if (!mounted) return;
      setState(() => _loading = true);
      await _firestore.clearAllSkills();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All skills cleared successfully.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(_applySearch),
            decoration: InputDecoration(
              hintText: 'Search skills by name...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip('Category', _categoryFilter, ['All', 'Programming', 'Framework', 'Interpersonal', 'Cognitive', 'Design', 'Other', 'Technical', 'Soft Skill'], (v) {
                setState(() {
                  _categoryFilter = v;
                  _applySearch();
                });
              }),
              const SizedBox(width: 8),
              _filterChip('Demand', _demandFilter, ['All', 'Very High', 'High', 'Medium', 'Low'], (v) {
                setState(() {
                  _demandFilter = v;
                  _applySearch();
                });
              }),
              const SizedBox(width: 8),
              _orderChip(theme),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_isGrid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                onPressed: () => setState(() => _isGrid = !_isGrid),
                tooltip: _isGrid ? 'List view' : 'Grid view',
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add Skill'),
                onPressed: () => _openSkillDialog(),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file, size: 20),
                label: const Text('Bulk Upload'),
                onPressed: _handleBulkUpload,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 20),
                label: const Text('Delete All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: _deleteAllSkills,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school_outlined, size: 64, color: theme.colorScheme.outline),
                          const SizedBox(height: 16),
                          Text('No skills match your filters', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _isGrid ? _buildGrid(theme, bottomPadding) : _buildList(theme, bottomPadding),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: label,
      child: Chip(
        avatar: Icon(Icons.tune_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
        label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),
      itemBuilder: (_) => options.map((o) => PopupMenuItem(value: o, child: Text(o))).toList(),
    );
  }

  Widget _orderChip(ThemeData theme) {
    final options = ['Most Used', 'Name'];
    final keys = ['jobCount', 'skillName'];
    var idx = keys.indexOf(_orderBy);
    if (idx < 0) idx = 0;
    return PopupMenuButton<int>(
      initialValue: idx,
      onSelected: (i) {
        setState(() {
          _orderBy = keys[i];
          _orderDesc = i != 1;
          _applySearch();
        });
      },
      tooltip: 'Sort by',
      child: Chip(
        avatar: Icon(Icons.sort_rounded, size: 18, color: theme.colorScheme.primary),
        label: Text('Sort: ${options[idx]}', style: const TextStyle(fontSize: 12)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),
      itemBuilder: (_) => List.generate(options.length, (i) => PopupMenuItem(value: i, child: Text(options[i]))),
    );
  }

  Widget _buildGrid(ThemeData theme, double bottomPadding) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _SkillCard(
        skill: _filtered[i],
        onEdit: () => _openSkillDialog(_filtered[i]),
        onDelete: () => _deleteSkill(_filtered[i]),
      ),
    );
  }

  Widget _buildList(ThemeData theme, double bottomPadding) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomPadding),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _SkillCard(
          skill: _filtered[i],
          onEdit: () => _openSkillDialog(_filtered[i]),
          onDelete: () => _deleteSkill(_filtered[i]),
          compact: true,
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  final SkillModel skill;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool compact;

  const _SkillCard({required this.skill, required this.onEdit, required this.onDelete, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = skill.skillName;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    if (compact) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(initial, style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${skill.category ?? 'Uncategorized'} · ${skill.jobCount ?? 0} jobs'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (skill.courseUrl != null && skill.courseUrl!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.link),
                  onPressed: () async {
                    final uri = Uri.tryParse(skill.courseUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  tooltip: 'Course Link',
                ),
              IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
              IconButton(onPressed: onDelete, icon: const Icon(Icons.delete, color: Colors.red)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        skill.category ?? 'Uncategorized',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (skill.courseUrl != null && skill.courseUrl!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    onPressed: () async {
                      final uri = Uri.tryParse(skill.courseUrl!);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    tooltip: 'Open Course',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(Icons.work_outline_rounded, '${skill.jobCount ?? 0} jobs', theme),
                if (skill.demandLevel != null) _badge(Icons.trending_up_rounded, skill.demandLevel!, theme),
                if (skill.platform != null && skill.platform!.isNotEmpty) _badge(Icons.school_rounded, skill.platform!, theme),
              ],
            ),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, ThemeData theme) {
    return Chip(
      avatar: Icon(icon, size: 14, color: theme.colorScheme.primary),
      label: Text(text, style: const TextStyle(fontSize: 11)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
