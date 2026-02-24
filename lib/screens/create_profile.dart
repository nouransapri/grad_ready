import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart'; 

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- القوائم الأساسية ---
  List<String> addedCourses = [];
  List<Map<String, String>> addedSkillsList = [];
  List<Map<String, String>> addedInternships = [];
  List<Map<String, String>> addedClubs = [];
  List<Map<String, String>> addedProjects = [];

  // --- الكنترولرز ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController universityController = TextEditingController();
  final TextEditingController majorController = TextEditingController();
  final TextEditingController gpaController = TextEditingController();
  final TextEditingController customCourseController = TextEditingController();
  final TextEditingController customSkillController = TextEditingController();
  final TextEditingController internTitleController = TextEditingController();
  final TextEditingController internCompanyController = TextEditingController();
  final TextEditingController internDurationController = TextEditingController();
  final TextEditingController clubNameController = TextEditingController();
  final TextEditingController clubRoleController = TextEditingController();
  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController projectDescController = TextEditingController();

  // --- المتغيرات المختارة ---
  final List<String> academicYears = [
    "Select year", "Freshman (Year 1)", "Sophomore (Year 2)", "Junior (Year 3)",
    "Senior (Year 4)", "Year 5", "Year 6", "Year 7", "Internship Year",
    "Master's Student", "PhD Student", "Graduate Student", "Recent Graduate"
  ];
  String selectedYear = "Select year";
  String selectedCourse = "Select a course";
  String selectedSkillType = "Technical";
  String selectedSkillName = "Select a skill";
  String selectedProficiency = "Basic";
  bool showCustomCourseField = false;
  bool showCustomSkillField = false;

  final List<String> technicalSkills = ["Select a skill", "Flutter", "Python", "Java", "SQL", "Dart", "C++", "HTML/CSS", "Other (Custom)"];
  final List<String> softSkills = ["Select a skill", "Communication", "Leadership", "Teamwork", "Problem Solving", "Time Management", "Other (Custom)"];

  // --- التحقق من صحة النموذج ---
  bool get isFormValid {
    return nameController.text.trim().isNotEmpty &&
           universityController.text.trim().isNotEmpty &&
           majorController.text.trim().isNotEmpty &&
           addedCourses.isNotEmpty &&
           addedSkillsList.isNotEmpty;
  }

  // --- دالة الحفظ في Firebase ---
  Future<void> saveUserProfile() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF2A6CFF))),
      );

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.pop(context);
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        "uid": user.uid,
        "email": user.email,
        "full_name": nameController.text.trim(),
        "university": universityController.text.trim(),
        "major": majorController.text.trim(),
        "academic_year": selectedYear,
        "gpa": gpaController.text.trim(),
        "added_courses": addedCourses,
        "skills": addedSkillsList,
        "internships": addedInternships,
        "clubs": addedClubs,
        "projects": addedProjects,
        "profile_completed": true,
        "created_at": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); 

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCourseInputActive = (selectedCourse != "Select a course" && !showCustomCourseField) || 
                               (showCustomCourseField && customCourseController.text.isNotEmpty);
    
    bool isSkillInputActive = (selectedSkillName != "Select a skill" && !showCustomSkillField) || 
                              (showCustomSkillField && customSkillController.text.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: Column(
                  children: [
                    // 1. Academic Information
                    _buildSectionCard(
                      title: "Academic Information *",
                      children: [
                        _buildLabel("Full Name *"),
                        _buildInputField("Enter your full name", controller: nameController, isRequired: true),
                        _buildLabel("University *"),
                        _buildInputField("Enter your university name", controller: universityController, isRequired: true),
                        _buildLabel("Major *"),
                        _buildInputField("e.g., Computer Science", controller: majorController, isRequired: true),
                        _buildLabel("Academic Year"),
                        _buildDropdownField(academicYears, value: selectedYear, onChanged: (v) => setState(() => selectedYear = v!)),
                        _buildLabel("GPA (Optional)"),
                        _buildInputField("e.g., 3.5", controller: gpaController),
                      ],
                    ),

                    // 2. Courses
                    _buildSectionCard(
                      title: "Courses * (${addedCourses.length})",
                      icon: Icons.menu_book_rounded, iconColor: Colors.blue,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                ["Select a course", "Data Structures", "Algorithms", "Database Systems", "Web Development", "Mobile Development", "Other (Custom)"],
                                value: selectedCourse,
                                onChanged: (val) => setState(() {
                                  selectedCourse = val!;
                                  showCustomCourseField = (val == "Other (Custom)");
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildAddIconButton(isCourseInputActive, () {
                              setState(() {
                                addedCourses.add(showCustomCourseField ? customCourseController.text : selectedCourse);
                                selectedCourse = "Select a course";
                                customCourseController.clear();
                                showCustomCourseField = false;
                              });
                            }),
                          ],
                        ),
                        if (showCustomCourseField)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextFormField(controller: customCourseController, decoration: _inputDecoration("Enter course name")),
                          ),
                        ...addedCourses.map((c) => _buildAddedTile(c, Icons.book, Colors.blue, () => setState(() => addedCourses.remove(c)))),
                      ],
                    ),

                    // 3. Skills
                    _buildSectionCard(
                      title: "Skills * (${addedSkillsList.length})",
                      icon: Icons.star, iconColor: Colors.purple,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDropdownField(["Technical", "Soft Skill"], value: selectedSkillType, onChanged: (v) => setState(() {
                                  selectedSkillType = v!;
                                  selectedSkillName = "Select a skill";
                                  showCustomSkillField = false;
                            }))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDropdownField(["Basic", "Intermediate", "Expert"], value: selectedProficiency, onChanged: (v) => setState(() => selectedProficiency = v!))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                selectedSkillType == "Technical" ? technicalSkills : softSkills,
                                value: selectedSkillName,
                                onChanged: (val) => setState(() {
                                  selectedSkillName = val!;
                                  showCustomSkillField = (val == "Other (Custom)");
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildAddIconButton(isSkillInputActive, () {
                              setState(() {
                                addedSkillsList.add({"name": showCustomSkillField ? customSkillController.text : selectedSkillName, "level": selectedProficiency});
                                selectedSkillName = "Select a skill";
                                customSkillController.clear();
                                showCustomSkillField = false;
                              });
                            }),
                          ],
                        ),
                        if (showCustomSkillField)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextFormField(controller: customSkillController, decoration: _inputDecoration("Enter skill name")),
                          ),
                        ...addedSkillsList.map((s) => _buildAddedTile("${s['name']} (${s['level']})", Icons.bolt, Colors.purple, () => setState(() => addedSkillsList.remove(s)))),
                      ],
                    ),

                    // 4. Internships (Optional)
                    _buildSectionCard(
                      title: "Internships (${addedInternships.length})",
                      icon: Icons.work, iconColor: Colors.orange,
                      children: [
                        _buildInputField("Title", controller: internTitleController),
                        _buildInputField("Company", controller: internCompanyController),
                        _buildAddIconButton(true, () {
                          if (internTitleController.text.isNotEmpty) {
                            setState(() {
                              addedInternships.add({"title": internTitleController.text, "company": internCompanyController.text});
                              internTitleController.clear(); internCompanyController.clear();
                            });
                          }
                        }, label: "Add Internship"),
                        ...addedInternships.map((i) => _buildAddedTile("${i['title']} @ ${i['company']}", Icons.business, Colors.orange, () => setState(() => addedInternships.remove(i)))),
                      ],
                    ),

                    const SizedBox(height: 30),
                    _buildFinalSubmitButton(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildHeader() => Container(
    width: double.infinity, padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2A6CFF), Color(0xFF9226FF)])),
    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.person_add_alt_1, color: Colors.white, size: 40),
      SizedBox(height: 10),
      Text('Create Profile', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildSectionCard({required String title, IconData? icon, Color? iconColor, required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [if (icon != null) Icon(icon, color: iconColor, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
      const Divider(height: 20), ...children,
    ]),
  );

  Widget _buildInputField(String hint, {bool isRequired = false, TextEditingController? controller}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(controller: controller, validator: (v) => isRequired && (v == null || v.isEmpty) ? "Required" : null, decoration: _inputDecoration(hint)),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFFF9FAFB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12));

  Widget _buildDropdownField(List<String> items, {String? value, ValueChanged<String?>? onChanged}) => DropdownButtonFormField<String>(isExpanded: true, value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(), onChanged: onChanged, decoration: _inputDecoration(""));

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 5, top: 5), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)));

  Widget _buildAddIconButton(bool active, VoidCallback onTap, {String? label}) => label == null 
    ? IconButton(onPressed: active ? onTap : null, icon: Icon(Icons.add_circle, color: active ? Colors.blue : Colors.grey, size: 30))
    : ElevatedButton.icon(onPressed: active ? onTap : null, icon: const Icon(Icons.add), label: Text(label), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white));

  Widget _buildAddedTile(String text, IconData icon, Color color, VoidCallback onRemove) => Container(
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
    child: ListTile(dense: true, leading: Icon(icon, color: color, size: 20), title: Text(text, style: const TextStyle(fontSize: 13)), trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onRemove)),
  );

  Widget _buildFinalSubmitButton() => ElevatedButton(
    onPressed: isFormValid ? saveUserProfile : null,
    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: const Color(0xFF2A6CFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    child: const Text("Complete Profile", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
  );
}