import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
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
                  _buildStatGrid(), 
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
      ),
      bottomNavigationBar: _buildBottomNav(), 
    );
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
  Widget _buildStatGrid() {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.6,
      children: [
        _buildStatCard('0', 'Skills', Icons.workspace_premium, const Color(0xFFF3E5F5), const Color(0xFF9C27B0)),
        _buildStatCard('0', 'Courses', Icons.menu_book, const Color(0xFFE3F2FD), const Color(0xFF2196F3)),
        _buildStatCard('0%', 'Profile Complete', Icons.check_circle, const Color(0xFFE8F5E9), const Color(0xFF4CAF50)),
        _buildStatCard('N/A', 'Last Analysis', Icons.bolt, const Color(0xFFFFF3E0), const Color(0xFFFF9800)),
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
    return Column(
      children: [
        _trendItem('AI/ML Jobs', '+45% growth in 2025', const Color(0xFFE8F5E9), const Color(0xFF4CAF50), Icons.auto_graph),
        _trendItem('Cybersecurity', '350K+ openings', const Color(0xFFE3F2FD), const Color(0xFF2196F3), Icons.security),
        _trendItem('Remote Work', '65% of tech jobs', const Color(0xFFF3E5F5), const Color(0xFF9C27B0), Icons.home_work),
      ],
    );
  }

  Widget _trendItem(String title, String subtitle, Color bgColor, Color iconColor, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 15),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
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
      onTap: () => setState(() => _selectedIndex = index),
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