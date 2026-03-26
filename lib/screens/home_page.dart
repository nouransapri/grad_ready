import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/insight_model.dart';
import '../models/market_insights.dart';
import '../services/firestore_service.dart';
import '../services/market_insights_service.dart';
import 'my_profile_screen.dart';
import 'select_job_role_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestore = FirestoreService();
  late Future<MarketInsights> _marketInsightsFuture;

  @override
  void initState() {
    super.initState();
    _marketInsightsFuture = MarketInsightsService.getRealInsights();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _marketInsightsFuture =
          MarketInsightsService.getRealInsights(forceRefresh: true);
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      // User doc stream: when skills are updated via addSkill/updateSkill (FirestoreService),
      // this snapshot updates immediately so profile completion %, skills count, and stats
      // reflect the new data without a manual refresh.
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                _buildHeader(null),
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
                _buildHeader(null),
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
          final userName = data?['full_name']?.toString().trim();

          return Column(
            children: [
              _buildHeader(userName),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 25),
                        const Row(
                        children: [
                          Icon(
                            Icons.bar_chart_rounded,
                            color: Color(0xFF1A1C1E),
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Dashboard Overview',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1C1E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildStatGrid(stats),
                      const SizedBox(height: 25),
                      _buildMarketInsightsCard(),
                      const SizedBox(height: 25),
                      const Row(
                        children: [
                          Icon(
                            Icons.trending_up_rounded,
                            color: Color(0xFF1A1C1E),
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Latest Insights',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1C1E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildInsightsSection(),
                      const SizedBox(height: 25),
                      _buildQuickTipsCard(),
                        const SizedBox(height: 120),
                      ],
                    ),
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
    final university =
        (data['university'] as String?)?.trim().isNotEmpty ?? false;
    final major = (data['major'] as String?)?.trim().isNotEmpty ?? false;
    final year = data['academic_year'] as String?;
    final academicOk =
        name &&
        university &&
        major &&
        year != null &&
        year.isNotEmpty &&
        year != 'Select year';
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
  Widget _buildHeader(String? userName) {
    return Container(
      padding: EdgeInsets.only(
        top: 60,
        left: 20,
        right: 20,
        bottom: userName != null && userName.isNotEmpty ? 20 : 30,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A6CFF), Color(0xFF9226FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SvgPicture.asset(
                  'assets/logo.svg',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  placeholderBuilder: (context) =>
                      const Icon(Icons.auto_graph, color: Colors.white),
                ),
              ),
              const SizedBox(width: 15),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GradReady',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Turning Gaps into Growth',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
          if (userName != null && userName.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildWelcomeBackBox(userName),
          ],
        ],
      ),
    );
  }

  /// Welcome box: light purple surface, dark text — compact padding.
  Widget _buildWelcomeBackBox(String name) {
    const darkText = Color(0xFF1A1C1E);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF3E5F5),
              Color(0xFFE1BEE7),
              Color(0xFFD1C4E9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFCE93D8).withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Welcome back,',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: darkText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDisplayName(name),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: darkText,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDisplayName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return fullName;
    if (parts.length == 1) return fullName;
    return parts.map((e) => e.isEmpty ? '' : '${e[0].toUpperCase()}${e.substring(1).toLowerCase()}').join(' ');
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
        _buildStatCard(
          '${stats.skillsCount}',
          'Skills',
          Icons.workspace_premium,
          const Color(0xFFF3E5F5),
          const Color(0xFF9C27B0),
        ),
        _buildStatCard(
          '${stats.coursesCount}',
          'Courses',
          Icons.menu_book,
          const Color(0xFFE3F2FD),
          const Color(0xFF2196F3),
        ),
        _buildStatCard(
          '${stats.profileCompletionPercent}%',
          'Profile Complete',
          Icons.check_circle,
          const Color(0xFFE8F5E9),
          const Color(0xFF4CAF50),
        ),
        _buildStatCard(
          stats.lastAnalysis,
          'Last Analysis',
          Icons.bolt,
          const Color(0xFFFFF3E0),
          const Color(0xFFFF9800),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
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
              Text(
                'Quick Tips',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _tipRow('Keep your profile updated with new skills '),
          _tipRow(
            'Analyze multiple job roles to explore different career paths',
          ),
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
          const Text(
            '• ',
            style: TextStyle(
              color: Color(0xFF2A6CFF),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF5A6B8D), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Live feeds via [MarketInsightsService].
  Widget _buildMarketInsightsCard() {
    return FutureBuilder<MarketInsights>(
      future: _marketInsightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildMarketInsightsLoading();
        }
        final insights = snapshot.data ?? MarketInsights.fallback();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF9800),
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Market Insights',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1C1E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (insights.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    insights.errorMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.grey[800],
                    ),
                  ),
                )
              else ...[
                _buildMarketInsightSummaryBlock(insights),
                ..._marketInsightJobRows(insights),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Summary: big count + full wrapped description + stat chips (no single-line ellipsis).
  Widget _buildMarketInsightSummaryBlock(MarketInsights insights) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _trendBgColors[0],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${insights.jobCount}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'live listings',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            insights.jobListKind,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _marketInsightStatChip(
                Icons.payments_outlined,
                'Avg salary',
                insights.avgSalary,
              ),
              _marketInsightStatChip(
                Icons.show_chart_rounded,
                'Trend',
                insights.growthRate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _marketInsightStatChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: const BoxConstraints(minWidth: 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _trendIconColors[0]),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Up to three job rows with multi-line titles (full job text).
  List<Widget> _marketInsightJobRows(MarketInsights insights) {
    final jobs = insights.topJobs.take(3).toList();
    if (jobs.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      for (var i = 0; i < jobs.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        _marketInsightJobRow(
          jobs[i],
          i < insights.topCompanies.length
              ? insights.topCompanies[i]
              : 'Remote listing',
          _trendBgColors[(i + 1) % _trendBgColors.length],
          _trendIconColors[(i + 1) % _trendIconColors.length],
        ),
      ],
    ];
  }

  Widget _marketInsightJobRow(
    String title,
    String company,
    Color bgColor,
    Color iconColor,
  ) {
    final iconContainerColor =
        Color.lerp(bgColor, Colors.white, 0.6) ?? bgColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconContainerColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.work_outline_rounded, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.35,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  company,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketInsightsLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
        ),
      ),
    );
  }

  // --- 4. Latest Insights (dynamic from Firestore) ---
  static const List<Color> _skillBarColors = [
    Color(0xFF9226FF),
    Color(0xFF2A6CFF),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
  ];

  Widget _buildInsightsSection() {
    return StreamBuilder<List<InsightModel>>(
      stream: _firestore.streamInsights(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildDemandedSkillsCardLoading();
        }
        if (snapshot.hasError) {
          return _buildDemandedSkillsCardError(snapshot.error.toString());
        }
        final insights = snapshot.data ?? [];
        return _buildDemandedSkillsCard(insights);
      },
    );
  }

  Widget _buildDemandedSkillsCardLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
        ),
      ),
    );
  }

  Widget _buildDemandedSkillsCardError(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        'Error loading insights: $message',
        style: const TextStyle(color: Colors.red),
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
      ),
    );
  }

  Widget _buildDemandedSkillsCard(List<InsightModel> insights) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: insights.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No insights yet. Add data in Firestore or run uploadHomeMockData().',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < insights.length; i++) ...[
                  if (i > 0) const SizedBox(height: 15),
                  _AnimatedInsightBar(
                    key: ValueKey(insights[i].id),
                    skillName: insights[i].skillName,
                    targetProgress: insights[i].progress,
                    color: _skillBarColors[i % _skillBarColors.length],
                  ),
                ],
              ],
            ),
    );
  }

  // --- 5. Market Insights palette (backgrounds + accent) ---
  static const List<Color> _trendBgColors = [
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFF3E5F5),
  ];
  static const List<Color> _trendIconColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
  ];

  // --- 6. Bottom Navigation Bar (fixed colors) ---
  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(25, 0, 25, 30),
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
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

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
    required Color itemColor,
  }) {
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
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SelectJobRoleScreen(),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: itemColor, // color stays fixed per design
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated progress bar: pulse/shimmer on color, optional jitter on %, smooth transition when Firestore updates.
class _AnimatedInsightBar extends StatefulWidget {
  final String skillName;
  final double targetProgress;
  final Color color;

  const _AnimatedInsightBar({
    super.key,
    required this.skillName,
    required this.targetProgress,
    required this.color,
  });

  @override
  State<_AnimatedInsightBar> createState() => _AnimatedInsightBarState();
}

class _AnimatedInsightBarState extends State<_AnimatedInsightBar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _jitterController;
  late AnimationController _transitionController;
  double _displayedProgress = 0;
  double _transitionFrom = 0;
  double _transitionTo = 0;

  @override
  void initState() {
    super.initState();
    _displayedProgress = widget.targetProgress;
    _transitionTo = widget.targetProgress;

    // Pulse: smooth opacity shimmer on the bar (repeat reverse = battery-friendly).
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Jitter: slight % fluctuation for "live data" feel (repeat reverse).
    _jitterController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    // One-shot transition when Firestore value changes.
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..addListener(_onTransitionTick);
  }

  void _onTransitionTick() {
    if (!mounted) return;
    setState(() {
      _displayedProgress =
          _transitionFrom +
          (_transitionTo - _transitionFrom) *
              Curves.easeInOut.transform(_transitionController.value);
    });
  }

  @override
  void didUpdateWidget(_AnimatedInsightBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetProgress != widget.targetProgress) {
      _transitionFrom = _displayedProgress;
      _transitionTo = widget.targetProgress;
      _transitionController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _jitterController.dispose();
    _transitionController.removeListener(_onTransitionTick);
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pulse: bar color opacity 0.8 → 1.0 → 0.8
    final pulseOpacity = 0.8 + 0.2 * _pulseController.value;
    // Jitter: ±0.2% on displayed value
    final jitter = (_jitterController.value - 0.5) * 0.004;
    final currentProgress = (_displayedProgress + jitter).clamp(0.0, 1.0);
    final displayPercent = (currentProgress * 100).toStringAsFixed(1);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.skillName,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Text('$displayPercent%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: currentProgress,
          color: widget.color.withValues(alpha: pulseOpacity),
          backgroundColor: Colors.grey[200],
          minHeight: 8,
        ),
      ],
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
      profileCompletionPercent: _HomePageState._profileCompletionPercentage(
        data,
      ),
      lastAnalysis: lastAnalysisValue != null
          ? lastAnalysisValue.toString()
          : 'N/A',
    );
  }
}
