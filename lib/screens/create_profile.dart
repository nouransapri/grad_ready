import 'package:flutter/material.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- القوائم الأساسية لتخزين البيانات ---
  List<String> addedCourses = [];
  List<Map<String, String>> addedSkillsList = [];
  List<Map<String, String>> addedInternships = [];
  List<Map<String, String>> addedClubs = [];
  List<Map<String, String>> addedProjects = [];

  // --- الكنترولرز للأقسام الإجبارية ---
  final TextEditingController nameController = TextEditingController();
  final TextEditingController universityController = TextEditingController();
  final TextEditingController majorController = TextEditingController();

  // --- متغيرات الأقسام ---
  final List<String> academicYears = [
    "Select year", "Freshman (Year 1)", "Sophomore (Year 2)", "Junior (Year 3)",
    "Senior (Year 4)", "Year 5", "Year 6", "Year 7", "Internship Year (امتياز)",
    "Master's Student (ماجستير)", "PhD Student (دكتوراه)", "Graduate Student", "Recent Graduate"
  ];
  String selectedYear = "Select year";

  String selectedCourse = "Select a course";
  bool showCustomCourseField = false;
  final TextEditingController customCourseController = TextEditingController();

  String selectedSkillType = "Technical";
  String selectedSkillName = "Select a skill";
  String selectedProficiency = "Basic";
  bool showCustomSkillField = false;
  final TextEditingController customSkillController = TextEditingController();

  final List<String> technicalSkills = ["Select a skill", "Flutter", "Python", "Java", "SQL", "Dart", "C++", "HTML/CSS", "Other (Custom)"];
  final List<String> softSkills = ["Select a skill", "Communication", "Leadership", "Teamwork", "Problem Solving", "Time Management", "Other (Custom)"];

  // --- الكنترولرز للأقسام الأخرى ---
  final TextEditingController internTitleController = TextEditingController();
  final TextEditingController internCompanyController = TextEditingController();
  final TextEditingController internDurationController = TextEditingController();
  final TextEditingController clubNameController = TextEditingController();
  final TextEditingController clubRoleController = TextEditingController();
  final TextEditingController projectNameController = TextEditingController();
  final TextEditingController projectDescController = TextEditingController();

  // --- منطق تفعيل الزرار النهائي (الإجباري فقط) ---
  bool get isFormValid {
    bool hasAcademicInfo = nameController.text.trim().isNotEmpty && 
                          universityController.text.trim().isNotEmpty &&
                          majorController.text.trim().isNotEmpty;
    bool hasCourses = addedCourses.isNotEmpty;
    bool hasSkills = addedSkillsList.isNotEmpty;
    return hasAcademicInfo && hasCourses && hasSkills;
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
                    // 1. Academic Information (REQUIRED)
                    _buildSectionCard(
                      title: "Academic Information *",
                      children: [
                        _buildLabel("Full Name *"),
                        _buildInputField("Enter your full name", controller: nameController, isRequired: true),
                        _buildLabel("University *"),
                        _buildInputField("Enter your university name", controller: universityController, isRequired: true),
                        _buildLabel("Major / Department *"),
                        _buildInputField("e.g., Computer Science", controller: majorController, isRequired: true),
                        _buildLabel("Academic Year"),
                        _buildDropdownField(academicYears, value: selectedYear, onChanged: (v) => setState(() => selectedYear = v!)),
                        _buildLabel("GPA (Optional)"),
                        _buildInputField("e.g., 3.5", isRequired: false),
                      ],
                    ),

                    // 2. Completed Courses (REQUIRED)
                    _buildSectionCard(
                      title: "Completed Courses * (${addedCourses.length})",
                      icon: Icons.menu_book_rounded, iconColor: Colors.blue,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildDropdownField(
                                    ["Select a course", "Data Structures", "Algorithms", "Database Systems", "Web Development", "Mobile Development", "Operating Systems", "Other (Custom)"],
                                    value: selectedCourse,
                                    onChanged: (val) => setState(() {
                                      selectedCourse = val!;
                                      showCustomCourseField = (val == "Other (Custom)");
                                    }),
                                  ),
                                  if (showCustomCourseField)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: TextFormField(
                                        controller: customCourseController,
                                        onChanged: (v) => setState(() {}),
                                        decoration: _inputDecoration("Enter custom course name..."),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildAddIconButton(isCourseInputActive, () {
                              setState(() {
                                String toAdd = showCustomCourseField ? customCourseController.text : selectedCourse;
                                addedCourses.add(toAdd);
                                selectedCourse = "Select a course";
                                customCourseController.clear();
                                showCustomCourseField = false;
                              });
                            }),
                          ],
                        ),
                        ...addedCourses.map((c) => _buildAddedTile(c, Icons.menu_book_rounded, Colors.blue, () => setState(() => addedCourses.remove(c)))),
                      ],
                    ),

                    // 3. Skills (REQUIRED)
                    _buildSectionCard(
                      title: "Skills * (${addedSkillsList.length})",
                      icon: Icons.auto_awesome_outlined, iconColor: Colors.purple,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildDropdownField(["Technical", "Soft Skill"], value: selectedSkillType, onChanged: (val) => setState(() {
                                  selectedSkillType = val!;
                                  selectedSkillName = "Select a skill";
                                  showCustomSkillField = false;
                                }))),
                            const SizedBox(width: 8),
                            Expanded(child: _buildDropdownField(["Basic", "Intermediate", "Expert"], value: selectedProficiency, onChanged: (val) => setState(() => selectedProficiency = val!))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildDropdownField(
                                    selectedSkillType == "Technical" ? technicalSkills : softSkills,
                                    value: selectedSkillName,
                                    onChanged: (val) => setState(() {
                                      selectedSkillName = val!;
                                      showCustomSkillField = (val == "Other (Custom)");
                                    }),
                                  ),
                                  if (showCustomSkillField)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: TextFormField(
                                        controller: customSkillController,
                                        onChanged: (v) => setState(() {}),
                                        decoration: _inputDecoration("Enter custom skill..."),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildAddIconButton(isSkillInputActive, () {
                              setState(() {
                                String finalName = showCustomSkillField ? customSkillController.text : selectedSkillName;
                                if (finalName != "Select a skill" && finalName.isNotEmpty) {
                                  addedSkillsList.add({"name": finalName, "level": selectedProficiency});
                                  selectedSkillName = "Select a skill";
                                  customSkillController.clear();
                                  showCustomSkillField = false;
                                }
                              });
                            }),
                          ],
                        ),
                        ...addedSkillsList.map((skill) => _buildAddedTile("${skill['name']} (${skill['level']})", Icons.star_border, Colors.purple, () => setState(() => addedSkillsList.remove(skill)))),
                      ],
                    ),

                    // 4. Internships (OPTIONAL)
                    _buildSectionCard(
                      title: "Internships (${addedInternships.length})",
                      icon: Icons.work_outline, iconColor: Colors.blueAccent,
                      children: [
                        _buildInputField("Internship Title", controller: internTitleController),
                        _buildInputField("Company", controller: internCompanyController),
                        _buildInputField("Duration", controller: internDurationController),
                        _buildActionButton("Add Internship", Colors.blueAccent, Icons.add, () {
                          if (internTitleController.text.isNotEmpty) {
                            setState(() {
                              addedInternships.add({"title": internTitleController.text, "company": internCompanyController.text, "duration": internDurationController.text});
                              internTitleController.clear(); internCompanyController.clear(); internDurationController.clear();
                            });
                          }
                        }),
                        ...addedInternships.map((i) => _buildAddedTile("${i['title']} @ ${i['company']}", Icons.work, Colors.blueAccent, () => setState(() => addedInternships.remove(i)))),
                      ],
                    ),

                    // 5. Student Clubs (OPTIONAL)
                    _buildSectionCard(
                      title: "Student Clubs (${addedClubs.length})",
                      icon: Icons.groups_3_outlined, iconColor: Colors.purple,
                      children: [
                        _buildInputField("Club Name", controller: clubNameController),
                        _buildInputField("Your Role", controller: clubRoleController),
                        _buildActionButton("Add Club", const Color(0xFF9226FF), Icons.add, () {
                          if (clubNameController.text.isNotEmpty) {
                            setState(() {
                              addedClubs.add({"name": clubNameController.text, "role": clubRoleController.text});
                              clubNameController.clear(); clubRoleController.clear();
                            });
                          }
                        }),
                        ...addedClubs.map((c) => _buildAddedTile("${c['name']} - ${c['role']}", Icons.groups, Colors.purple, () => setState(() => addedClubs.remove(c)))),
                      ],
                    ),

                    // 6. Academic Projects (OPTIONAL)
                    _buildSectionCard(
                      title: "Academic Projects (${addedProjects.length})",
                      icon: Icons.folder_open_rounded, iconColor: Colors.green,
                      children: [
                        _buildInputField("Project Name", controller: projectNameController),
                        _buildInputField("Description", controller: projectDescController, maxLines: 2),
                        _buildActionButton("Add Project", Colors.green, Icons.add, () {
                          if (projectNameController.text.isNotEmpty) {
                            setState(() {
                              addedProjects.add({"name": projectNameController.text});
                              projectNameController.clear(); projectDescController.clear();
                            });
                          }
                        }),
                        ...addedProjects.map((p) => _buildAddedTile(p['name']!, Icons.folder, Colors.green, () => setState(() => addedProjects.remove(p)))),
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
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2A6CFF), Color(0xFF9226FF)])),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.person_outline, color: Colors.white, size: 40),
          SizedBox(height: 8),
          Text('Create Profile', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text('Complete Information', style: TextStyle(color: Colors.white70, fontSize: 14)),
      ]),
    );
  }

  Widget _buildSectionCard({required String title, IconData? icon, Color? iconColor, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) Icon(icon, color: iconColor, size: 22),
          if (icon != null) const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        ]),
        const Divider(height: 25, thickness: 1),
        ...children,
      ]),
    );
  }

  Widget _buildAddedTile(String text, IconData icon, Color color, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 18, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildAddIconButton(bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: isActive ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isActive ? const Color(0xFF2A6CFF) : const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInputField(String hint, {bool isRequired = false, int maxLines = 1, TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (v) => isRequired && (v == null || v.isEmpty) ? "Required" : null,
        decoration: _inputDecoration(hint),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    );
  }

  Widget _buildDropdownField(List<String> items, {String? value, ValueChanged<String?>? onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      decoration: _inputDecoration(""),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(padding: const EdgeInsets.only(bottom: 6, top: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)));
  }

  Widget _buildActionButton(String text, Color color, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildFinalSubmitButton() {
    bool active = isFormValid;
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: active ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10)] : []),
      child: ElevatedButton(
        onPressed: active ? () { if (_formKey.currentState!.validate()) { print("Success!"); } } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? const Color(0xFF2A6CFF) : const Color(0xFFD1D5DB), 
          minimumSize: const Size(double.infinity, 55), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Create Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}