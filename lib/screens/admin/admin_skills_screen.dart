import 'package:flutter/material.dart';
import '../../models/skill_document.dart';
import '../../services/firestore_service.dart';
import 'admin_skill_edit_screen.dart';

/// Skills Library tab content: search, filters, sort, grid/list, skill cards.
class AdminSkillsContent extends StatefulWidget {
  const AdminSkillsContent({super.key});

  @override
  State<AdminSkillsContent> createState() => _AdminSkillsContentState();
}

class _AdminSkillsContentState extends State<AdminSkillsContent> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<SkillDocument> _skills = [];
  List<SkillDocument> _filtered = [];
  bool _loading = true;
  bool _isGrid = true;

  String _typeFilter = 'All';
  String _categoryFilter = 'All';
  String _demandFilter = 'All';
  String _trendingFilter = 'All';
  String _orderBy = 'totalJobsUsingSkill';
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
      final list = await _firestore.getSkillDocumentsOnce(
        type: _typeFilter == 'All' ? null : _typeFilter,
        category: _categoryFilter == 'All' ? null : _categoryFilter,
        demandLevel: _demandFilter == 'All' ? null : _demandFilter,
        trending: _trendingFilter == 'Yes' ? true : (_trendingFilter == 'No' ? false : null),
        orderBy: _orderBy,
        descending: _orderDesc,
      );
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
    if (q.isEmpty) {
      _filtered = List.from(_skills);
      return;
    }
    _filtered = _skills.where((s) {
      final name = s.skillName.toLowerCase();
      final aliases = s.aliases.map((e) => e.toLowerCase()).join(' ');
      return name.contains(q) || aliases.contains(q);
    }).toList();
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
              hintText: 'Search skills by name or alias…',
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
              _filterChip('Type', _typeFilter, ['All', 'Technical', 'Soft', 'Tool'], (v) {
                setState(() {
                  _typeFilter = v;
                  _load();
                });
              }),
              const SizedBox(width: 8),
              _filterChip('Category', _categoryFilter, ['All', 'Programming', 'Framework', 'Interpersonal', 'Cognitive', 'Design'], (v) {
                setState(() {
                  _categoryFilter = v;
                  _load();
                });
              }),
              const SizedBox(width: 8),
              _filterChip('Demand', _demandFilter, ['All', 'Very High', 'High', 'Medium', 'Low'], (v) {
                setState(() {
                  _demandFilter = v;
                  _load();
                });
              }),
              const SizedBox(width: 8),
              _filterChip('Trending', _trendingFilter, ['All', 'Yes', 'No'], (v) {
                setState(() {
                  _trendingFilter = v;
                  _load();
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
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSkillEditScreen())).then((_) => _load()),
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
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSkillEditScreen())).then((_) => _load()),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add first skill'),
                          ),
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
    final options = ['Most used', 'Name', 'Demand', 'Recent'];
    final keys = ['totalJobsUsingSkill', 'skillName', 'demandLevel', 'createdAt'];
    var idx = keys.indexOf(_orderBy);
    if (idx < 0) idx = 0;
    return PopupMenuButton<int>(
      initialValue: idx,
      onSelected: (i) {
        setState(() {
          _orderBy = keys[i];
          _orderDesc = i != 1;
          _load();
        });
      },
      tooltip: 'Sort by',
      child: Chip(
        avatar: Icon(Icons.sort_rounded, size: 18, color: theme.colorScheme.primary),
        label: Text('Sort: ${options[idx]}', style: const TextStyle(fontSize: 12)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),
      itemBuilder: (_) => List.generate(4, (i) => PopupMenuItem(value: i, child: Text(options[i]))),
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
        onView: () => _openSkill(_filtered[i], viewOnly: true),
        onEdit: () => _openSkill(_filtered[i], viewOnly: false),
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
          onView: () => _openSkill(_filtered[i], viewOnly: true),
          onEdit: () => _openSkill(_filtered[i], viewOnly: false),
          compact: true,
        ),
      ),
    );
  }

  void _openSkill(SkillDocument skill, {required bool viewOnly}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminSkillEditScreen(skill: skill, viewOnly: viewOnly),
      ),
    ).then((_) => _load());
  }
}

class _SkillCard extends StatelessWidget {
  final SkillDocument skill;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final bool compact;

  const _SkillCard({required this.skill, required this.onView, required this.onEdit, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFrom(skill.color);

    if (compact) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.3), child: Text((skill.icon ?? skill.skillName.substring(0, 1).toUpperCase()), style: TextStyle(color: color))),
          title: Text(skill.skillName, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${skill.type} · ${skill.category} · Used in ${skill.totalJobsUsingSkill} jobs'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: onView, child: const Text('View')),
              FilledButton(onPressed: onEdit, child: const Text('Edit')),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.25), child: Text(skill.icon ?? skill.skillName.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(skill.skillName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${skill.type} · ${skill.category}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _badge(Icons.work_outline_rounded, '${skill.totalJobsUsingSkill} jobs', theme),
                if (skill.demandLevel != null) _badge(Icons.trending_up_rounded, skill.demandLevel!, theme),
                if (skill.trending == true) _badge(Icons.local_fire_department_rounded, 'Trending', theme),
                if (skill.averageSalaryImpact != null) _badge(Icons.attach_money_rounded, skill.averageSalaryImpact!, theme),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: onView, child: const Text('View', style: TextStyle(fontSize: 12)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                const SizedBox(width: 6),
                Expanded(child: FilledButton(onPressed: onEdit, child: const Text('Edit', style: TextStyle(fontSize: 12)), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
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

  Color _colorFrom(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final n = int.tryParse(hex, radix: 16);
    return n != null ? Color(n) : Colors.blue;
  }
}
