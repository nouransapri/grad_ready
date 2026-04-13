import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_user_summary.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

const Color _usersCardBg = Colors.white;
const Color _usersChipBg = Color(0xFFE8E4F5);
const Color _usersChipText = Color(0xFF5B4B9E);
const Color _usersSuspendedBg = Color(0xFFFFEBEE);
const Color _usersSuspendedText = Color(0xFFC62828);

class AdminUsersContent extends StatefulWidget {
  const AdminUsersContent({super.key});

  @override
  State<AdminUsersContent> createState() => _AdminUsersContentState();
}

class _AdminUsersContentState extends State<AdminUsersContent> {
  static const int _pageStep = 20;
  static const String _searchHint = 'Search users by name...';
  static const String _labelNoUsers = 'No users found.';
  static const String _labelLoadMore = 'Load more';

  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<AdminUserSummary> _users = <AdminUserSummary>[];
  bool _loading = true;
  bool _updating = false;
  int _currentLimit = _pageStep;
  String _searchQuery = '';
  bool _showOnlySuspended = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await _firestore.searchUsersOnce(
        query: _searchQuery,
        limit: _currentLimit,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _users = <AdminUserSummary>[];
        _loading = false;
      });
    }
  }

  List<AdminUserSummary> get _filtered {
    if (!_showOnlySuspended) return _users;
    return _users.where((u) => u.isSuspended).toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
        _currentLimit = _pageStep;
      });
      _loadUsers();
    });
  }

  Future<void> _toggleSuspended(AdminUserSummary user) async {
    setState(() => _updating = true);
    try {
      await _firestore.setUserSuspended(
        uid: user.uid,
        suspended: !user.isSuspended,
      );
      if (!mounted) return;
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.isSuspended ? 'User unsuspended.' : 'User suspended.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final users = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: _searchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: PopupMenuButton<bool>(
                tooltip: 'Filter',
                initialValue: _showOnlySuspended,
                onSelected: (value) => setState(() => _showOnlySuspended = value),
                itemBuilder: (_) => const [
                  PopupMenuItem<bool>(
                    value: false,
                    child: Text('All users'),
                  ),
                  PopupMenuItem<bool>(
                    value: true,
                    child: Text('Suspended only'),
                  ),
                ],
                icon: const Icon(Icons.filter_alt_outlined),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
                  ? Center(
                      child: Text(
                        _labelNoUsers,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        itemCount: users.length + 1,
                        itemBuilder: (context, index) {
                          if (index == users.length) {
                            final canLoadMore = _users.length >= _currentLimit;
                            if (!canLoadMore) return const SizedBox(height: 12);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: OutlinedButton(
                                onPressed: _updating
                                    ? null
                                    : () {
                                        setState(() => _currentLimit += _pageStep);
                                        _loadUsers();
                                      },
                                child: const Text(_labelLoadMore),
                              ),
                            );
                          }
                          final user = users[index];
                          return Card(
                            color: _usersCardBg,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              title: Text(
                                user.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _chip(
                                      label: user.gpa == null
                                          ? 'GPA: —'
                                          : 'GPA: ${user.gpa!.toStringAsFixed(2)}',
                                      bg: _usersChipBg,
                                      fg: _usersChipText,
                                    ),
                                    _chip(
                                      label: user.academicYear.isEmpty
                                          ? 'Year: —'
                                          : 'Year: ${user.academicYear}',
                                      bg: _usersChipBg,
                                      fg: _usersChipText,
                                    ),
                                    if (user.isSuspended)
                                      _chip(
                                        label: 'Suspended',
                                        bg: _usersSuspendedBg,
                                        fg: _usersSuspendedText,
                                      ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (_) => _toggleSuspended(user),
                                itemBuilder: (_) => [
                                  PopupMenuItem<String>(
                                    value: user.uid,
                                    child: Text(
                                      user.isSuspended
                                          ? AppConstants.actionUnsuspend
                                          : AppConstants.actionSuspend,
                                    ),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert_rounded),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
