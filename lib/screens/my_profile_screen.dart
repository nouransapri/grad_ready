import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_profile.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  static const _gradientStart = Color(0xFF2A6CFF);
  static const _gradientEnd = Color(0xFF9226FF);
  static const _purple = Color(0xFF9226FF);

  Future<DocumentSnapshot> _getProfileFuture() {
    final user = FirebaseAuth.instance.currentUser!;
    return FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FutureBuilder<DocumentSnapshot>(
        future: _getProfileFuture(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _gradientStart));
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildBody(context, null);
          }
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          return _buildBody(context, data);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? data) {
    final name = data?['full_name'] as String? ?? '—';
    final university = data?['university'] as String? ?? '';
    final major = data?['major'] as String? ?? '';
    final academicYear = data?['academic_year'] as String? ?? '';
    final gpa = data?['gpa'] as String? ?? '';
    final courses = List<String>.from(data?['added_courses'] ?? []);
    final skills = List<Map<String, dynamic>>.from(
      (data?['skills'] as List?)?.map((e) => e as Map<String, dynamic>) ?? [],
    );
    final internships = List<Map<String, dynamic>>.from(
      (data?['internships'] as List?)?.map((e) => e as Map<String, dynamic>) ?? [],
    );
    final clubs = List<Map<String, dynamic>>.from(
      (data?['clubs'] as List?)?.map((e) => e as Map<String, dynamic>) ?? [],
    );
    final projects = List<Map<String, dynamic>>.from(
      (data?['projects'] as List?)?.map((e) => e as Map<String, dynamic>) ?? [],
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildProfileCard(context, name, university),
              const SizedBox(height: 20),
              _buildSection(
                context,
                title: 'Academic Information',
                icon: Icons.school_rounded,
                iconColor: const Color(0xFF2A6CFF),
                onEdit: () => _openEditProfile(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoRow('Full Name', name),
                    _buildInfoRow('University', university),
                    _buildInfoRow('Major', major),
                    _buildInfoRow('Academic Year', academicYear.isEmpty || academicYear == 'Select year' ? '—' : academicYear),
                    _buildInfoRow('GPA', gpa.isEmpty ? '—' : gpa),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                title: 'Completed Courses',
                icon: Icons.menu_book_rounded,
                iconColor: Colors.blue,
                onEdit: () => _openEditProfile(context),
                child: courses.isEmpty
                    ? _emptyHint('No courses added')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: courses.map((c) => _courseRow(c)).toList(),
                      ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                title: 'Skills',
                icon: Icons.star_rounded,
                iconColor: _purple,
                onEdit: () => _openEditProfile(context),
                child: skills.isEmpty
                    ? _emptyHint('No skills added')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: skills
                            .map((s) => _skillRow(
                                  name: s['name']?.toString() ?? '',
                                  type: s['type']?.toString() ?? 'Technical',
                                  level: s['level']?.toString() ?? '',
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                title: 'Internships',
                icon: Icons.work_outline,
                iconColor: const Color(0xFF2A6CFF),
                onEdit: () => _openEditProfile(context),
                child: internships.isEmpty
                    ? _emptyHint('No internships added')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: internships
                            .map((i) => _internshipRow(
                                  title: i['title']?.toString() ?? '',
                                  company: i['company']?.toString() ?? '',
                                  duration: i['duration']?.toString() ?? '',
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                title: 'Student Clubs',
                icon: Icons.groups_rounded,
                iconColor: _purple,
                onEdit: () => _openEditProfile(context),
                child: clubs.isEmpty
                    ? _emptyHint('No clubs added')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: clubs
                            .map((c) => _clubRow(
                                  name: c['name']?.toString() ?? '',
                                  role: c['role']?.toString() ?? '',
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                title: 'Academic Projects',
                icon: Icons.lightbulb_outline_rounded,
                iconColor: Colors.green,
                onEdit: () => _openEditProfile(context),
                child: projects.isEmpty
                    ? _emptyHint('No projects added')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: projects
                            .map((p) => _projectRow(
                                  name: p['name']?.toString() ?? '',
                                  description: p['description']?.toString() ?? '',
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_gradientStart, _gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
          ),
          const Expanded(
            child: Text(
              'My Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, String name, String university) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _purple.withOpacity(0.15),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                ),
                child: Icon(Icons.person_rounded, size: 48, color: _purple),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: IconButton(
                  onPressed: () => _openEditProfile(context),
                  icon: const Icon(Icons.edit_rounded, color: _purple, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Student at ',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Icon(Icons.school_rounded, size: 18, color: Colors.grey[600]),
              if (university.isNotEmpty)
                Flexible(
                  child: Text(
                    ' $university',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, color: _purple, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _courseRow(String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.menu_book_rounded, size: 22, color: Colors.blue[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clubRow({required String name, required String role}) {
    final subtitle = role.isNotEmpty ? ' — $role' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.groups_rounded, size: 22, color: _purple.withOpacity(0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name + subtitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectRow({required String name, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 22, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillRow({required String name, required String type, required String level}) {
    final levelColor = level == 'Basic'
        ? Colors.orange
        : level == 'Intermediate'
            ? Colors.blue
            : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 22, color: _purple.withOpacity(0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                _chip(type, _purple.withOpacity(0.2)),
                if (level.isNotEmpty) _chip(level, levelColor.withOpacity(0.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
    );
  }

  Widget _internshipRow({
    required String title,
    required String company,
    required String duration,
  }) {
    final subtitle = [company, duration].where((s) => s.isNotEmpty).join(' • ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.work_outline, size: 22, color: Colors.blue[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateProfileScreen(isEditMode: true),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}
