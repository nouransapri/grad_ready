import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/job_document.dart';
import '../../models/skill_document.dart';
import '../../services/firestore_service.dart';

const Color _purple = Color(0xFF5B4B9E);
const Color _softBlue = Color(0xFF2563EB);

/// Required skills: segmented add target, manual row (name + level), library search, grouped lists.
/// [createMode] matches the Add New Job Role mock: two segments (Technical / Soft), gray + button, no Tools section.
class JobSkillsEditor extends StatefulWidget {
  final List<JobSkillItem> technicalSkills;
  final List<JobSkillItem> softSkills;
  final List<JobSkillItem> tools;
  final ValueChanged<List<JobSkillItem>> onTechnicalChanged;
  final ValueChanged<List<JobSkillItem>> onSoftChanged;
  final ValueChanged<List<JobSkillItem>> onToolsChanged;
  final bool createMode;

  const JobSkillsEditor({
    super.key,
    required this.technicalSkills,
    required this.softSkills,
    required this.tools,
    required this.onTechnicalChanged,
    required this.onSoftChanged,
    required this.onToolsChanged,
    this.createMode = false,
  });

  @override
  State<JobSkillsEditor> createState() => _JobSkillsEditorState();
}

class _JobSkillsEditorState extends State<JobSkillsEditor> {
  final FirestoreService _firestore = FirestoreService();
  int _skillTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _manualLevelController = TextEditingController(text: '70');
  List<SkillDocument> _suggestions = [];
  bool _searching = false;
  String _lastQuery = '';
  bool _showSuggestions = false;
  static const Duration _searchDebounce = Duration(milliseconds: 450);
  Timer? _searchDebounceTimer;

  @override
  void didUpdateWidget(covariant JobSkillsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.createMode && _skillTabIndex > 1) {
      _skillTabIndex = 0;
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _manualNameController.dispose();
    _manualLevelController.dispose();
    super.dispose();
  }

  int get _effectiveTabIndex {
    if (widget.createMode && _skillTabIndex > 1) return 0;
    return _skillTabIndex;
  }

  String get _currentType {
    switch (_effectiveTabIndex) {
      case 0:
        return 'Technical';
      case 1:
        return 'Soft';
      case 2:
        return 'Tool';
      default:
        return 'Technical';
    }
  }

  List<JobSkillItem> get _currentList {
    switch (_effectiveTabIndex) {
      case 0:
        return widget.technicalSkills;
      case 1:
        return widget.softSkills;
      case 2:
        return widget.tools;
      default:
        return widget.technicalSkills;
    }
  }

  void _onListChanged(List<JobSkillItem> list) {
    switch (_effectiveTabIndex) {
      case 0:
        widget.onTechnicalChanged(list);
        break;
      case 1:
        widget.onSoftChanged(list);
        break;
      case 2:
        widget.onToolsChanged(list);
        break;
    }
  }

  Set<String> get _addedNames {
    final set = <String>{};
    for (final s in widget.technicalSkills) set.add(s.name.trim().toLowerCase());
    for (final s in widget.softSkills) set.add(s.name.trim().toLowerCase());
    for (final s in widget.tools) set.add(s.name.trim().toLowerCase());
    return set;
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _searching = true);
    try {
      final list = await _firestore.searchSkillDocuments(
        query: q.trim(),
        type: _currentType,
        limit: 12,
      );
      if (!mounted) return;
      final added = _addedNames;
      final filtered = list.where((s) => !added.contains(s.skillName.trim().toLowerCase())).toList();
      if (!mounted) return;
      setState(() {
        _suggestions = filtered;
        _showSuggestions = true;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addSkill(SkillDocument doc) {
    final item = JobSkillItem(
      name: doc.skillName,
      requiredLevel: 70,
      priority: 'Important',
      weight: 5,
      category: doc.category,
    );
    final list = List<JobSkillItem>.from(_currentList)..add(item);
    _onListChanged(list);
    _searchController.clear();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
  }

  void _addManual() {
    final name = _manualNameController.text.trim();
    if (name.isEmpty) return;
    final raw = _manualLevelController.text.trim();
    final n = int.tryParse(raw) ?? 70;
    final level = n.clamp(0, 100);
    if (raw.isNotEmpty && int.tryParse(raw) != null) {
      _manualLevelController.text = level.toString();
    }
    final lower = name.toLowerCase();
    if (_addedNames.contains(lower)) return;
    final item = JobSkillItem(
      name: name,
      requiredLevel: level,
      priority: 'Important',
      weight: 5,
      category: '',
    );
    final list = List<JobSkillItem>.from(_currentList)..add(item);
    _onListChanged(list);
    _manualNameController.clear();
    setState(() {});
  }

  void _updateInList(
    int tabIndex,
    int index,
    JobSkillItem updated,
  ) {
    switch (tabIndex) {
      case 0:
        final list = List<JobSkillItem>.from(widget.technicalSkills);
        if (index < 0 || index >= list.length) return;
        list[index] = updated;
        widget.onTechnicalChanged(list);
        break;
      case 1:
        final list = List<JobSkillItem>.from(widget.softSkills);
        if (index < 0 || index >= list.length) return;
        list[index] = updated;
        widget.onSoftChanged(list);
        break;
      case 2:
        final list = List<JobSkillItem>.from(widget.tools);
        if (index < 0 || index >= list.length) return;
        list[index] = updated;
        widget.onToolsChanged(list);
        break;
    }
  }

  void _removeFromList(int tabIndex, int index) {
    switch (tabIndex) {
      case 0:
        final list = List<JobSkillItem>.from(widget.technicalSkills);
        if (index < 0 || index >= list.length) return;
        list.removeAt(index);
        widget.onTechnicalChanged(list);
        break;
      case 1:
        final list = List<JobSkillItem>.from(widget.softSkills);
        if (index < 0 || index >= list.length) return;
        list.removeAt(index);
        widget.onSoftChanged(list);
        break;
      case 2:
        final list = List<JobSkillItem>.from(widget.tools);
        if (index < 0 || index >= list.length) return;
        list.removeAt(index);
        widget.onToolsChanged(list);
        break;
    }
    setState(() {});
  }

  Color _colorFrom(String? hex) {
    if (hex == null || hex.isEmpty) return _purple;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final n = int.tryParse(h, radix: 16);
    return n != null ? Color(n) : _purple;
  }

  @override
  Widget build(BuildContext context) {
    final create = widget.createMode;
    final showUnifiedEmpty =
        create && widget.technicalSkills.isEmpty && widget.softSkills.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Required Skills',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Text(
          create
              ? 'Add technical and soft skills with required proficiency levels (0–100%).'
              : 'Modify technical and soft skills with required proficiency levels (0–100%).',
          style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.35),
        ),
        const SizedBox(height: 14),
        _segmentedToggle(),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _manualNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Skill name...',
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onSubmitted: (_) => _addManual(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _manualLevelController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  suffixText: create ? null : '%',
                  suffixStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onSubmitted: (_) => _addManual(),
              ),
            ),
            const SizedBox(width: 4),
            create
                ? Material(
                    color: const Color(0xFFE8E8E8),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _addManual,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.add_rounded, color: Colors.grey.shade800, size: 22),
                      ),
                    ),
                  )
                : Material(
                    color: _purple,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _addManual,
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.add_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
          ],
        ),
        const SizedBox(height: 12),
        if (!create)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8),
              title: Text(
                'Search skills library',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800]),
              ),
              children: [
                Stack(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        _searchDebounceTimer?.cancel();
                        _lastQuery = v;
                        _searchDebounceTimer = Timer(_searchDebounce, () {
                          _searchDebounceTimer = null;
                          if (_lastQuery == _searchController.text && mounted) _search(v);
                        });
                      },
                      onTap: () => setState(() => _showSuggestions = _suggestions.isNotEmpty),
                      decoration: InputDecoration(
                        hintText: 'Search $_currentType skills…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 22),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    if (_showSuggestions && _suggestions.isNotEmpty)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 52,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _suggestions.length,
                              itemBuilder: (_, i) {
                                final s = _suggestions[i];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: _colorFrom(s.color).withValues(alpha: 0.25),
                                    child: Text(
                                      (s.icon ?? (s.skillName.isNotEmpty ? s.skillName.substring(0, 1) : '?')).toUpperCase(),
                                      style: TextStyle(color: _colorFrom(s.color), fontSize: 13),
                                    ),
                                  ),
                                  title: Text(s.skillName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${s.category} · ${s.totalJobsUsingSkill} jobs',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => _addSkill(s),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (!create) const SizedBox(height: 8),
        Text(
          create
              ? 'Technical Skills: ${widget.technicalSkills.length}    Soft Skills: ${widget.softSkills.length}'
              : 'Technical Skills: ${widget.technicalSkills.length}    Soft Skills: ${widget.softSkills.length}    Tools: ${widget.tools.length}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        if (showUnifiedEmpty) _buildUnifiedEmptyPlaceholder() else ...[
          _buildSection(
            label: 'Technical Skills',
            labelColor: _purple,
            rowBg: const Color(0xFFF3EEFF),
            accent: _purple,
            tabIndex: 0,
            items: widget.technicalSkills,
          ),
          const SizedBox(height: 16),
          _buildSection(
            label: 'Soft Skills',
            labelColor: _softBlue,
            rowBg: const Color(0xFFE8F4FC),
            accent: _softBlue,
            tabIndex: 1,
            items: widget.softSkills,
          ),
        ],
        if (!create) ...[
          const SizedBox(height: 16),
          _buildSection(
            label: 'Tools',
            labelColor: Colors.black87,
            rowBg: const Color(0xFFF3F4F6),
            accent: Colors.blueGrey.shade700,
            tabIndex: 2,
            items: widget.tools,
          ),
        ],
      ],
    );
  }

  Widget _buildUnifiedEmptyPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'No skills added yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
          ),
          const SizedBox(height: 6),
          Text(
            'Add skills using the form above',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _segmentedToggle() {
    Widget seg(String label, int index) {
      final selected = _effectiveTabIndex == index;
      return Expanded(
        child: Material(
          color: selected ? _purple : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => setState(() {
              _skillTabIndex = index;
              _showSuggestions = false;
              _suggestions = [];
            }),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.createMode) {
      return Row(
        children: [
          seg('Technical', 0),
          const SizedBox(width: 8),
          seg('Soft Skills', 1),
        ],
      );
    }

    return Row(
      children: [
        seg('Technical', 0),
        const SizedBox(width: 8),
        seg('Soft Skills', 1),
        const SizedBox(width: 8),
        seg('Tools', 2),
      ],
    );
  }

  Widget _buildSection({
    required String label,
    required Color labelColor,
    required Color rowBg,
    required Color accent,
    required int tabIndex,
    required List<JobSkillItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No ${label.toLowerCase()} added yet.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          )
        else
          ...List.generate(items.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CompactSkillRow(
                key: ValueKey('$tabIndex-${items[index].name}-$index'),
                item: items[index],
                rowBg: rowBg,
                accent: accent,
                onChanged: (updated) => _updateInList(
                  tabIndex,
                  index,
                  updated,
                ),
                onRemove: () => _removeFromList(tabIndex, index),
              ),
            );
          }),
      ],
    );
  }
}

class _CompactSkillRow extends StatefulWidget {
  final JobSkillItem item;
  final Color rowBg;
  final Color accent;
  final ValueChanged<JobSkillItem> onChanged;
  final VoidCallback onRemove;

  const _CompactSkillRow({
    super.key,
    required this.item,
    required this.rowBg,
    required this.accent,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_CompactSkillRow> createState() => _CompactSkillRowState();
}

class _CompactSkillRowState extends State<_CompactSkillRow> {
  late TextEditingController _levelController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController(
      text: widget.item.requiredLevel.clamp(0, 100).toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _CompactSkillRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.requiredLevel != widget.item.requiredLevel &&
        widget.item.requiredLevel.toString() != _levelController.text) {
      _levelController.text = widget.item.requiredLevel.clamp(0, 100).toString();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _levelController.dispose();
    super.dispose();
  }

  void _commit() {
    _debounce?.cancel();
    final raw = _levelController.text.trim();
    if (raw.isEmpty) return;
    final n = int.tryParse(raw);
    if (n == null) return;
    final c = n.clamp(0, 100);
    if (c != n) _levelController.text = c.toString();
    
    _triggerChange(level: c);
  }

  void _triggerChange({int? level, String? priority}) {
    widget.onChanged(
      JobSkillItem(
        skillId: widget.item.skillId,
        name: widget.item.name,
        requiredLevel: level ?? widget.item.requiredLevel,
        priority: priority ?? widget.item.priority,
        weight: widget.item.weight,
        category: widget.item.category,
      ),
    );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _commit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              widget.item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: ['Critical', 'Important', 'Nice-to-Have'].contains(widget.item.priority)
                  ? widget.item.priority
                  : 'Important',
              isDense: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600, size: 20),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.item.priority == 'Critical'
                    ? const Color(0xFFDC2626) // Red for mandatory
                    : Colors.grey.shade800,
              ),
              items: const [
                DropdownMenuItem(value: 'Critical', child: Text('Mandatory (Critical)')),
                DropdownMenuItem(value: 'Important', child: Text('Important')),
                DropdownMenuItem(value: 'Nice-to-Have', child: Text('Nice-to-Have')),
              ],
              onChanged: (val) {
                if (val != null) {
                  _triggerChange(priority: val);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: TextField(
              controller: _levelController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: widget.accent,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                suffixText: '%',
                suffixStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              onChanged: (_) => _schedule(),
              onEditingComplete: _commit,
              onSubmitted: (_) => _commit(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
            onPressed: widget.onRemove,
            tooltip: 'Remove',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
