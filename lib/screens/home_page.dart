import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/insight_model.dart';
import '../models/trend_model.dart';
import '../services/firestore_service.dart';
import 'my_profile_screen.dart';
import 'select_job_role_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final FirestoreService _firestore = FirestoreService();

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
                      _buildInsightsSection(),
                      const SizedBox(height: 25),
                      _buildMarketTrendsSection(),
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
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Text('Error loading insights: $message', style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildDemandedSkillsCard(List<InsightModel> insights) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: insights.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No insights yet. Add data in Firestore or run uploadHomeMockData().'),
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

  // --- 5. Job Market Trends (dynamic from Firestore) ---
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

  Widget _buildMarketTrendsSection() {
    return StreamBuilder<List<TrendModel>>(
      stream: _firestore.streamMarketTrends(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildJobMarketTrendsLoading();
        }
        if (snapshot.hasError) {
          return _buildJobMarketTrendsError(snapshot.error.toString());
        }
        final trends = snapshot.data ?? [];
        return _buildJobMarketTrends(trends);
      },
    );
  }

  Widget _buildJobMarketTrendsLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
        ),
      ),
    );
  }

  Widget _buildJobMarketTrendsError(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Text('Error loading trends: $message', style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildJobMarketTrends(List<TrendModel> trends) {
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
          if (trends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No trends yet. Add data in Firestore or run uploadHomeMockData().'),
            )
          else
            ...trends.asMap().entries.map((e) {
              final i = e.key;
              final t = e.value;
              return Padding(
                padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
                child: _trendItem(
                  t.title,
                  t.displaySubtitle,
                  _trendBgColors[i % _trendBgColors.length],
                  _trendIconColors[i % _trendIconColors.length],
                  trendIconFromName(t.iconName),
                ),
              );
            }),
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
        } else if (index == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SelectJobRoleScreen(),
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
      _displayedProgress = _transitionFrom +
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
            Text(widget.skillName, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('$displayPercent%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: currentProgress,
          color: widget.color.withOpacity(pulseOpacity),
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
      profileCompletionPercent: _HomePageState._profileCompletionPercentage(data),
      lastAnalysis: lastAnalysisValue != null ? lastAnalysisValue.toString() : 'N/A',
    );
  }
}