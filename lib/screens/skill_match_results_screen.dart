import 'package:flutter/material.dart';

import '../models/skill_match_row.dart';
import '../services/skill_match_csv_service.dart';

/// Displays skill match results from assets/data/skill_match_results.csv.
/// Supports: filter by user_id, show only recommended (match >= 70%).
class SkillMatchResultsScreen extends StatefulWidget {
  const SkillMatchResultsScreen({super.key});

  @override
  State<SkillMatchResultsScreen> createState() =>
      _SkillMatchResultsScreenState();
}

class _SkillMatchResultsScreenState extends State<SkillMatchResultsScreen> {
  List<SkillMatchRow> _allRows = [];
  bool _loading = true;
  String? _error;
  String? _selectedUserId;
  bool _recommendedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadCsv();
  }

  Future<void> _loadCsv() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await SkillMatchCsvService.loadFromAssets();
      if (mounted) {
        final availableUserIds = _uniqueUserIds(rows);
        final selectedStillExists =
            _selectedUserId != null && availableUserIds.contains(_selectedUserId);
        setState(() {
          _allRows = rows;
          _loading = false;
          if (_selectedUserId == null && rows.isNotEmpty) {
            _selectedUserId = availableUserIds.first;
          } else if (!selectedStillExists) {
            _selectedUserId = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<String> _uniqueUserIds(List<SkillMatchRow> rows) {
    final ids = rows.map((r) => r.userId).toSet().toList()..sort();
    return ids;
  }

  List<SkillMatchRow> get _filteredRows {
    var list = _allRows;
    if (_selectedUserId != null && _selectedUserId!.isNotEmpty) {
      list = list.where((r) => r.userId == _selectedUserId).toList();
    }
    if (_recommendedOnly) {
      list = list.where((r) => r.recommend).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Skill Match Report'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _loadCsv,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilters(theme),
                  const SizedBox(height: 20),
                  Text(
                    'Results (${_filteredRows.length} rows)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTable(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    final userIds = ['All users', ..._uniqueUserIds(_allRows)];
    final selectedValue =
        (_selectedUserId == null || _selectedUserId!.isEmpty || !userIds.contains(_selectedUserId))
        ? 'All users'
        : _selectedUserId;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter by user', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedValue,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: userIds
                  .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedUserId = (v == null || v == 'All users') ? null : v;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _recommendedOnly,
                  onChanged: (v) =>
                      setState(() => _recommendedOnly = v ?? false),
                  activeColor: const Color(0xFF2A6CFF),
                ),
                const Expanded(
                  child: Text('Recommended only (match ≥ 70%)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(ThemeData theme) {
    final rows = _filteredRows;
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No rows match the filters.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4FF)),
          columns: const [
            DataColumn(
              label: Text(
                'User ID',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Job ID',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Match %',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Recommend',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: rows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r.userId)),
                DataCell(Text(r.jobId)),
                DataCell(Text('${r.matchPercentage.toStringAsFixed(1)}%')),
                DataCell(
                  r.recommend
                      ? const Icon(
                          Icons.check_circle,
                          color: Color(0xFF4CAF50),
                          size: 22,
                        )
                      : const Icon(Icons.cancel, color: Colors.grey, size: 22),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
