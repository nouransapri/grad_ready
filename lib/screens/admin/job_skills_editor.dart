import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/job_document.dart';
import '../../models/skill_document.dart';
import '../../services/firestore_service.dart';

const Color _purple = Color(0xFF5B4B9E);
const Color _criticalColor = Color(0xFFB91C1C);
const Color _importantColor = Color(0xFFEA580C);
const Color _niceColor = Color(0xFF16A34A);

/// Required skills editor: 3 tabs (Technical / Soft / Tools), search from skills library, cards with level, priority, weight.
class JobSkillsEditor extends StatefulWidget {
  final List<JobSkillItem> technicalSkills;
  final List<JobSkillItem> softSkills;
  final List<JobSkillItem> tools;
  final ValueChanged<List<JobSkillItem>> onTechnicalChanged;
  final ValueChanged<List<JobSkillItem>> onSoftChanged;
  final ValueChanged<List<JobSkillItem>> onToolsChanged;

  const JobSkillsEditor({
    super.key,
    required this.technicalSkills,
    required this.softSkills,
    required this.tools,
    required this.onTechnicalChanged,
    required this.onSoftChanged,
    required this.onToolsChanged,
  });

  @override
  State<JobSkillsEditor> createState() => _JobSkillsEditorState();
}

class _JobSkillsEditorState extends State<JobSkillsEditor> {
  final FirestoreService _firestore = FirestoreService();
  int _skillTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  List<SkillDocument> _suggestions = [];
  bool _searching = false;
  String _lastQuery = '';
  bool _showSuggestions = false;
  static const Duration _searchDebounce = Duration(milliseconds: 450);
  Timer? _searchDebounceTimer;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _currentType {
    switch (_skillTabIndex) {
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
    switch (_skillTabIndex) {
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
    switch (_skillTabIndex) {
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
      if (mounted) setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
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

  void _updateItem(int index, JobSkillItem updated) {
    final list = List<JobSkillItem>.from(_currentList);
    if (index < 0 || index >= list.length) return;
    list[index] = updated;
    _onListChanged(list);
  }

  void _removeItem(int index) {
    final list = List<JobSkillItem>.from(_currentList);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    _onListChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Required Skills',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        Text(
          'Search the skills library and add skills. Set level, priority and weight per skill.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _tab('Technical', widget.technicalSkills.length, 0, Icons.code_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _tab('Soft', widget.softSkills.length, 1, Icons.people_rounded)),
            const SizedBox(width: 8),
            Expanded(child: _tab('Tools', widget.tools.length, 2, Icons.build_rounded)),
          ],
        ),
        const SizedBox(height: 14),
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
                hintText: 'Search $_currentType skills...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _colorFrom(s.color).withValues(alpha: 0.3),
                            child: Text(
                              (s.icon ?? s.skillName.substring(0, 1)).toUpperCase(),
                              style: TextStyle(color: _colorFrom(s.color), fontSize: 14),
                            ),
                          ),
                          title: Text(s.skillName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${s.category} · Used in ${s.totalJobsUsingSkill} jobs'),
                          onTap: () => _addSkill(s),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: true,
          itemCount: _currentList.length,
          onReorder: (oldIndex, newIndex) {
            if (newIndex > oldIndex) newIndex--;
            final list = List<JobSkillItem>.from(_currentList);
            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
            _onListChanged(list);
          },
          itemBuilder: (_, index) {
            final item = _currentList[index];
            return _SkillCard(
              key: ValueKey('${item.name}_$index'),
              index: index,
              item: item,
              onLevelChanged: (v) => _updateItem(
                index,
                JobSkillItem(
                  name: item.name,
                  requiredLevel: v.round(),
                  priority: item.priority,
                  weight: item.weight,
                  category: item.category,
                ),
              ),
              onPriorityChanged: (p) => _updateItem(
                index,
                JobSkillItem(
                  name: item.name,
                  requiredLevel: item.requiredLevel,
                  priority: p,
                  weight: item.weight,
                  category: item.category,
                ),
              ),
              onWeightChanged: (w) => _updateItem(
                index,
                JobSkillItem(
                  name: item.name,
                  requiredLevel: item.requiredLevel,
                  priority: item.priority,
                  weight: w,
                  category: item.category,
                ),
              ),
              onRemove: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Remove skill?'),
                    content: Text('Remove "${item.name}" from this job?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
                    ],
                  ),
                );
                if (confirm == true) _removeItem(index);
              },
            );
          },
        ),
        if (_currentList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 40, color: Colors.grey[600]),
                const SizedBox(height: 8),
                Text(
                  'No $_currentType skills added. Search above to add.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        _SummaryPanel(
          technical: widget.technicalSkills,
          soft: widget.softSkills,
          tools: widget.tools,
        ),
      ],
    );
  }

  Widget _tab(String label, int count, int index, IconData icon) {
    final selected = _skillTabIndex == index;
    return Material(
      color: selected ? _purple.withValues(alpha: 0.15) : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => setState(() {
          _skillTabIndex = index;
          _showSuggestions = false;
          _suggestions = [];
        }),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? _purple : Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                '$label ($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? _purple : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorFrom(String? hex) {
    if (hex == null || hex.isEmpty) return _purple;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final n = int.tryParse(hex, radix: 16);
    return n != null ? Color(n) : _purple;
  }
}

class _SkillCard extends StatelessWidget {
  final int index;
  final JobSkillItem item;
  final ValueChanged<double> onLevelChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<int> onWeightChanged;
  final VoidCallback onRemove;

  const _SkillCard({
    super.key,
    required this.index,
    required this.item,
    required this.onLevelChanged,
    required this.onPriorityChanged,
    required this.onWeightChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (item.category.isNotEmpty)
                        Text(
                          item.category,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onRemove,
                  color: Colors.red.shade400,
                  tooltip: 'Remove',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Required level: ${item.requiredLevel}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Slider(
              value: item.requiredLevel.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: onLevelChanged,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الأولوية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: item.priority,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem(value: 'Critical', child: Text('حرجة', style: TextStyle(color: _criticalColor, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'Important', child: Text('مهمة', style: TextStyle(color: _importantColor, fontWeight: FontWeight.w600))),
                          DropdownMenuItem(value: 'Nice-to-Have', child: Text('مفضلة', style: TextStyle(color: _niceColor, fontWeight: FontWeight.w600))),
                        ],
                        onChanged: (v) => onPriorityChanged(v ?? 'Important'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weight (1-10)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: item.weight.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null) onWeightChanged(n.clamp(1, 10));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final List<JobSkillItem> technical;
  final List<JobSkillItem> soft;
  final List<JobSkillItem> tools;

  const _SummaryPanel({
    required this.technical,
    required this.soft,
    required this.tools,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...technical, ...soft, ...tools];
    final total = all.length;
    final avg = total == 0 ? 0.0 : all.fold<int>(0, (a, s) => a + s.requiredLevel) / total;
    final critical = all.where((s) => s.priority == 'Critical').length;
    final important = all.where((s) => s.priority == 'Important').length;
    final nice = all.where((s) => s.priority == 'Nice-to-Have').length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Skills summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryChip(Icons.assessment_rounded, 'Total', '$total'),
              const SizedBox(width: 12),
              _summaryChip(Icons.code_rounded, 'Technical', '${technical.length}'),
              const SizedBox(width: 12),
              _summaryChip(Icons.people_rounded, 'Soft', '${soft.length}'),
              const SizedBox(width: 12),
              _summaryChip(Icons.build_rounded, 'Tools', '${tools.length}'),
            ],
          ),
          const SizedBox(height: 10),
          Text('Average required level: ${avg.toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('Critical: $critical', style: const TextStyle(fontSize: 12, color: _criticalColor, fontWeight: FontWeight.w600)),
              Text('Important: $important', style: const TextStyle(fontSize: 12, color: _importantColor, fontWeight: FontWeight.w600)),
              Text('Nice-to-Have: $nice', style: const TextStyle(fontSize: 12, color: _niceColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: _purple),
        const SizedBox(width: 4),
        Text('$label: $value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
