import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'my_profile_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
                  ),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data?.data();
          final stats = _DashboardStats.fromUserData(data);

          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 25),
                      const Row(
                        children: [
                          Icon(Icons.bar_chart_rounded, color: Color(0xFF1A1C1E), size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Dashboard Overview',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildStatGrid(stats),
                      const SizedBox(height: 25),
                      _buildQuickTipsCard(),
                      const SizedBox(height: 25),
                      const Row(
                        children: [
                          Icon(Icons.trending_up_rounded, color: Color(0xFF1A1C1E), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Latest Insights',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildDemandedSkillsCard(),
                      const SizedBox(height: 25),
                      _buildJobMarketTrends(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// 6 sections: Academic Info, Courses, Skills, Internships, Clubs, Projects.
  static int _profileCompletionPercentage(Map<String, dynamic>? data) {
    if (data == null) return 0;
    int completed = 0;
    final name = (data['full_name'] as String?)?.trim().isNotEmpty ?? false;
    final university = (data['university'] as String?)?.trim().isNotEmpty ?? false;
    final major = (data['major'] as String?)?.trim().isNotEmpty ?? false;
    final year = data['academic_year'] as String?;
    final academicOk = name && university && major && year != null && year.isNotEmpty && year != 'Select year';
    if (academicOk) completed++;
    final courses = data['added_courses'] as List?;
    if (courses != null && courses.isNotEmpty) completed++;
    final skills = data['skills'] as List?;
    if (skills != null && skills.isNotEmpty) completed++;
    final internships = data['internships'] as List?;
    if (internships != null && internships.isNotEmpty) completed++;
    final clubs = data['clubs'] as List?;
    if (clubs != null && clubs.isNotEmpty) completed++;
    final projects = data['projects'] as List?;
    if (projects != null && projects.isNotEmpty) completed++;
    if (completed == 0) return 0;
    return ((completed / 6) * 100).round();
  }

  // --- 1. Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A6CFF), Color(0xFF9226FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: SvgPicture.asset(
              'assets/logo.svg',
              width: 32,
              height: 32,
              placeholderBuilder: (context) => const Icon(Icons.auto_graph, color: Colors.white),
            ),
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GradReady', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Turning Gaps into Growth', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // --- 2. Stats Grid ---
  Widget _buildStatGrid(_DashboardStats stats) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard('${stats.skillsCount}', 'Skills', Icons.workspace_premium, const Color(0xFFF3E5F5), const Color(0xFF9C27B0)),
        _buildStatCard('${stats.coursesCount}', 'Courses', Icons.menu_book, const Color(0xFFE3F2FD), const Color(0xFF2196F3)),
        _buildStatCard('${stats.profileCompletionPercent}%', 'Profile Complete', Icons.check_circle, const Color(0xFFE8F5E9), const Color(0xFF4CAF50)),
        _buildStatCard(stats.lastAnalysis, 'Last Analysis', Icons.bolt, const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Quick Tips ---
  Widget _buildQuickTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD0DBFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Text('Quick Tips', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 12),
          _tipRow('Keep your profile updated with new skills and courses'),
          _tipRow('Analyze multiple job roles to explore different career paths'),
          _tipRow('Focus on critical gaps to maximize your job readiness'),
        ],
      ),
    );
  }

  Widget _tipRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF2A6CFF), fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF5A6B8D), fontSize: 14))),
        ],
      ),
    );
  }

  // --- 4. Most Demanded Skills ---
  Widget _buildDemandedSkillsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildSkillProgress('Python', 0.95, const Color(0xFF9226FF)),
          const SizedBox(height: 15),
          _buildSkillProgress('Data Analysis', 0.88, const Color(0xFF2A6CFF)),
          const SizedBox(height: 15),
          _buildSkillProgress('Cloud Computing', 0.82, const Color(0xFF4CAF50)),
          const SizedBox(height: 15),
          _buildSkillProgress('Machine Learning', 0.78, const Color(0xFFFF9800)),
        ],
      ),
    );
  }

  Widget _buildSkillProgress(String name, double progress, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${(progress * 100).toInt()}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress, color: color, backgroundColor: Colors.grey[200], minHeight: 8),
      ],
    );
  }

  // --- 5. Job Market Trends ---
  Widget _buildJobMarketTrends() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up, color: Color(0xFF4CAF50), size: 26),
              SizedBox(width: 10),
              Text(
                'Job Market Trends',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _trendItem('AI/ML Jobs', '+45% growth in 2025', const Color(0xFFE8F5E9), const Color(0xFF4CAF50), Icons.trending_up),
          const SizedBox(height: 12),
          _trendItem('Cybersecurity', 'High demand, 350K+ openings', const Color(0xFFE3F2FD), const Color(0xFF2196F3), Icons.security),
          const SizedBox(height: 12),
          _trendItem('Remote Work', '65% of tech jobs now remote-friendly', const Color(0xFFF3E5F5), const Color(0xFF9C27B0), Icons.home_work),
        ],
      ),
    );
  }

  Widget _trendItem(String title, String subtitle, Color bgColor, Color iconColor, IconData icon) {
    final iconContainerColor = Color.lerp(bgColor, Colors.white, 0.6) ?? bgColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconContainerColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Bottom Navigation Bar (ألوان ثابتة تماماً) ---
  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(25, 0, 25, 30),
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(
            icon: Icons.person_rounded, 
            label: 'My Profile', 
            index: 0, 
            itemColor: const Color(0xFF2A6CFF),
          ),
          _navItem(
            icon: Icons.track_changes_rounded, 
            label: 'Job Analysis', 
            index: 1, 
            itemColor: const Color(0xFF9226FF),
          ),
        ],
      ),
    );
  }

  Widget _navItem({required IconData icon, required String label, required int index, required Color itemColor}) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'My Profile'),
              builder: (context) => const MyProfileScreen(),
            ),
          );
        } else {
          setState(() => _selectedIndex = index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: itemColor, // اللون ثابت دائماً كما طلبتِ
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon, 
              color: Colors.white, 
              size: 28
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF1A1C1E) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStats {
  final int skillsCount;
  final int coursesCount;
  final int profileCompletionPercent;
  final String lastAnalysis;

  const _DashboardStats({
    required this.skillsCount,
    required this.coursesCount,
    required this.profileCompletionPercent,
    required this.lastAnalysis,
  });

  factory _DashboardStats.fromUserData(Map<String, dynamic>? data) {
    if (data == null) {
      return const _DashboardStats(
        skillsCount: 0,
        coursesCount: 0,
        profileCompletionPercent: 0,
        lastAnalysis: 'N/A',
      );
    }
    final skills = data['skills'] as List?;
    final courses = data['added_courses'] as List?;
    final lastAnalysisValue = data['last_analysis'];
    return _DashboardStats(
      skillsCount: skills?.length ?? 0,
      coursesCount: courses?.length ?? 0,
      profileCompletionPercent: _HomePageState._profileCompletionPercentage(data),
      lastAnalysis: lastAnalysisValue != null ? lastAnalysisValue.toString() : 'N/A',
    );
  }
}