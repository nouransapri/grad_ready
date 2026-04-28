import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/profile_photo_service.dart';
import 'create_profile.dart';
import 'splash_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  static const _gradientStart = Color(0xFF2A6CFF);
  static const _gradientEnd = Color(0xFF9226FF);
  static const _purple = Color(0xFF9226FF);

  final FirestoreService _firestore = FirestoreService();
  bool _uploadingPhoto = false;

  /// True once the stream has delivered its first snapshot.
  /// Used to show the loading spinner only for the initial fetch.
  bool _hasReceivedFirstSnapshot = false;

  /// Real-time stream of the current user's Firestore document.
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    if (_userStream == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (FirebaseAuth.instance.currentUser == null) {
            return const SizedBox.shrink();
          }
          // Show loading spinner only on the very first fetch.
          if (!_hasReceivedFirstSnapshot &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _gradientStart),
            );
          }

          // Mark that we've received at least one snapshot.
          if (snapshot.hasData || snapshot.hasError) {
            _hasReceivedFirstSnapshot = true;
          }

          if (snapshot.hasError) {
            final errorStr = snapshot.error.toString().toLowerCase();
            if (errorStr.contains('permission-denied') || errorStr.contains('permission_denied')) {
              return const SizedBox.shrink();
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 42, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text('Could not load profile.'),
                  ],
                ),
              ),
            );
          }

          // Map the Firestore document snapshot to our UserModel.
          UserModel? userModel;
          final docSnap = snapshot.data;
          if (docSnap != null && docSnap.exists && docSnap.data() != null) {
            userModel = UserModel.fromFirestore(docSnap.id, docSnap.data()!);
          }

          return _buildBody(context, userModel);
        },
      ),
    );
  }

  String? _effectivePhotoUrl(UserModel? userModel) {
    final fromDoc = userModel?.photoUrl.trim();
    if (fromDoc != null && fromDoc.isNotEmpty) return fromDoc;
    return FirebaseAuth.instance.currentUser?.photoURL;
  }

  Future<void> _offerPhotoChange(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(ImageSource source) async {
    if (_uploadingPhoto) return;
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required')),
        );
        return;
      }
    }
    setState(() => _uploadingPhoto = true);
    try {
      final xfile = await ProfilePhotoService.pickImage(source: source);
      if (xfile == null) return;
      await ProfilePhotoService.uploadAndSaveProfilePhoto(File(xfile.path));
      // No manual refresh needed — the stream auto-updates.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _buildBody(BuildContext context, UserModel? userModel) {
    final name = userModel?.fullName.isNotEmpty == true ? userModel!.fullName : '—';
    final university = userModel?.university ?? '';
    final major = userModel?.major ?? '';
    final academicYear = userModel?.academicYear ?? '';
    final gpa = userModel?.gpa ?? '';
    final skills = userModel?.skills.map((s) => s.toMap()).toList() ?? const <Map<String, dynamic>>[];
    final internships = userModel?.internships.map((i) => i.toMap()).toList() ?? const <Map<String, dynamic>>[];
    final clubs = userModel?.clubs.map((c) => c.toMap()).toList() ?? const <Map<String, dynamic>>[];
    final projects = userModel?.projects.map((p) => p.toMap()).toList() ?? const <Map<String, dynamic>>[];
    final photoUrl = _effectivePhotoUrl(userModel);

    return RefreshIndicator(
      // The stream is already live, but pull-to-refresh still feels natural.
      // We just return a short Future so the indicator dismisses.
      onRefresh: () => Future<void>.delayed(const Duration(milliseconds: 300)),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileCard(context, name, university, photoUrl),
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
                      _buildInfoRow(
                        'Academic Year',
                        academicYear.isEmpty || academicYear == 'Select year'
                            ? '—'
                            : academicYear,
                      ),
                      _buildInfoRow('GPA', gpa.isEmpty ? '—' : gpa),
                    ],
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
                            .map(
                              (s) => _skillRow(
                                name: s['name']?.toString() ?? '',
                                type: s['type']?.toString() ?? 'Technical',
                                level: s['level']?.toString() ?? '',
                              ),
                            )
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
                            .map(
                              (i) => _internshipRow(
                                title: i['title']?.toString() ?? '',
                                company: i['company']?.toString() ?? '',
                                duration: i['duration']?.toString() ?? '',
                              ),
                            )
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
                            .map(
                              (c) => _clubRow(
                                name: c['name']?.toString() ?? '',
                                role: c['role']?.toString() ?? '',
                              ),
                            )
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
                            .map(
                              (p) => _projectRow(
                                name: p['name']?.toString() ?? '',
                                description: p['description']?.toString() ?? '',
                              ),
                            )
                            .toList(),
                      ),
              ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
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
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 22,
            ),
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
            onPressed: _shareProfile,
            icon: const Icon(Icons.share_rounded, color: Colors.white),
          ),
          IconButton(
            onPressed: () async {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (_) => false,
              );
              await Future.delayed(const Duration(milliseconds: 50));
              await AuthService.signOut();
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    String name,
    String university,
    String? photoUrl,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _uploadingPhoto
                      ? null
                      : () => _offerPhotoChange(context),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _purple.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _uploadingPhoto
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : photoUrl != null && photoUrl.isNotEmpty
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            width: 90,
                            height: 90,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: _purple,
                            ),
                          )
                        : const Icon(
                            Icons.person_rounded,
                            size: 48,
                            color: _purple,
                          ),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: IconButton(
                  onPressed: () => _openEditProfile(context),
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: _purple,
                    size: 22,
                  ),
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
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: TextAlign.center,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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

  Widget _clubRow({required String name, required String role}) {
    final subtitle = role.isNotEmpty ? ' — $role' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.groups_rounded,
            size: 22,
            color: _purple.withValues(alpha: 0.9),
          ),
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
          Icon(
            Icons.lightbulb_outline_rounded,
            size: 22,
            color: Colors.green[700],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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

  Widget _skillRow({
    required String name,
    required String type,
    required String level,
  }) {
    final levelColor = level == 'Basic'
        ? Colors.orange
        : level == 'Intermediate'
        ? Colors.blue
        : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: 22,
            color: _purple.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _chip(type, _purple.withValues(alpha: 0.2)),
                    if (level.isNotEmpty)
                      _chip(level, levelColor.withValues(alpha: 0.25)),
                  ],
                ),
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
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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

  void _openEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateProfileScreen(isEditMode: true),
      ),
    );
    // No manual refresh needed — the stream auto-updates when
    // the profile is saved in CreateProfileScreen.
  }

  Future<void> _shareProfile() async {
    final model = await _firestore.getCurrentUserModel();
    final name = model?.fullName.trim();
    final major = model?.major.trim();
    final uni = model?.university.trim();
    final text = [
      if (name != null && name.isNotEmpty) name,
      if (major != null && major.isNotEmpty) 'Major: $major',
      if (uni != null && uni.isNotEmpty) 'University: $uni',
      'Shared from GradReady',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile copied to clipboard')));
  }
}
