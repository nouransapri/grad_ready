import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';

class CreateProfileScreen extends StatefulWidget {
  final bool isEditMode;

  const CreateProfileScreen({super.key, this.isEditMode = false});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  List<String> addedCourses = [];
  List<Map<String, String>> addedSkillsList = [];
  List<Map<String, String>> addedInternships = [];
  List<Map<String, String>> addedClubs = [];
  List<Map<String, String>> addedProjects = [];

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

  final List<String> academicYears = [
    "Select year",
    "Freshman (Year 1)",
    "Sophomore (Year 2)",
    "Junior (Year 3)",
    "Senior (Year 4)",
    "Year 5",
    "Year 6",
    "Year 7",
    "Internship Year",
    "Master's Student",
    "PhD Student",
    "Graduate Student",
    "Recent Graduate"
  ];

  String selectedYear = "Select year";
  String selectedCourse = "Select a course";
  String selectedSkillType = "Technical";
  String selectedSkillName = "Select a skill";
  String selectedProficiency = "Basic";
  bool showCustomCourseField = false;
  bool showCustomSkillField = false;
  bool internshipsExpanded = true;

  final List<String> technicalSkills = [
    "Select a skill",
    "Flutter",
    "Python",
    "Java",
    "SQL",
    "Dart",
    "C++",
    "HTML/CSS",
    "Other (Custom)"
  ];

  final List<String> softSkills = [
    "Select a skill",
    "Communication",
    "Leadership",
    "Teamwork",
    "Problem Solving",
    "Time Management",
    "Other (Custom)"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists || !mounted) return;
    final d = doc.data()!;
    nameController.text = d['full_name']?.toString() ?? '';
    universityController.text = d['university']?.toString() ?? '';
    majorController.text = d['major']?.toString() ?? '';
    gpaController.text = d['gpa']?.toString() ?? '';
    final year = d['academic_year']?.toString();
    if (year != null && year.isNotEmpty) selectedYear = year;
    addedCourses = List<String>.from(d['added_courses'] ?? []);
    final skillsList = d['skills'] as List?;
    addedSkillsList = skillsList?.map((e) {
      final m = e as Map<dynamic, dynamic>;
      return Map<String, String>.from(m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
    }).toList() ?? [];
    final internshipsList = d['internships'] as List?;
    addedInternships = internshipsList?.map((e) {
      final m = e as Map<dynamic, dynamic>;
      return Map<String, String>.from(m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
    }).toList() ?? [];
    final clubsList = d['clubs'] as List?;
    addedClubs = clubsList?.map((e) {
      final m = e as Map<dynamic, dynamic>;
      return Map<String, String>.from(m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
    }).toList() ?? [];
    final projectsList = d['projects'] as List?;
    addedProjects = projectsList?.map((e) {
      final m = e as Map<dynamic, dynamic>;
      return Map<String, String>.from(m.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
    }).toList() ?? [];
    if (mounted) setState(() {});
  }

  bool get isFormValid {
    return nameController.text.trim().isNotEmpty &&
        universityController.text.trim().isNotEmpty &&
        majorController.text.trim().isNotEmpty &&
        addedCourses.isNotEmpty &&
        addedSkillsList.isNotEmpty;
  }

  Future<void> saveUserProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    if (selectedYear == "Select year") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select your academic year")),
      );
      return;
    }

    if (addedCourses.isEmpty || addedSkillsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please add at least one course and one skill")),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2A6CFF)),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
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
        "internships": addedInternships
            .map((i) => {
                  "title": i["title"],
                  "company": i["company"],
                  "duration": i["duration"] ?? "",
                })
            .toList(),
        "clubs": addedClubs,
        "projects": addedProjects,
        "profile_completed": true,
        "created_at": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully 🎉")),
      );

      if (widget.isEditMode) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCourseInputActive =
        (selectedCourse != "Select a course" && !showCustomCourseField) ||
            (showCustomCourseField && customCourseController.text.isNotEmpty);

    bool isSkillInputActive =
        (selectedSkillName != "Select a skill" && !showCustomSkillField) ||
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
                    _buildSectionCard(
                      title: "Academic Information *",
                      children: [
                        _buildLabel("Full Name *"),
                        _buildInputField(
                          "Enter your full name",
                          controller: nameController,
                          isRequired: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        _buildLabel("University *"),
                        _buildInputField(
                          "Enter your university name",
                          controller: universityController,
                          isRequired: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        _buildLabel("Major *"),
                        _buildInputField(
                          "e.g., Computer Science",
                          controller: majorController,
                          isRequired: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        _buildLabel("Academic Year"),
                        _buildDropdownField(
                          academicYears,
                          value: selectedYear,
                          onChanged: (v) => setState(() => selectedYear = v!),
                        ),
                        _buildLabel("GPA (Optional)"),
                        _buildInputField("e.g., 3.5", controller: gpaController),
                      ],
                    ),

                    _buildSectionCard(
                      title: "Courses * (${addedCourses.length})",
                      icon: Icons.menu_book_rounded,
                      iconColor: Colors.blue,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                [
                                  "Select a course",
                                  "Data Structures",
                                  "Algorithms",
                                  "Database Systems",
                                  "Web Development",
                                  "Mobile Development",
                                  "Other (Custom)"
                                ],
                                value: selectedCourse,
                                onChanged: (val) => setState(() {
                                  selectedCourse = val!;
                                  showCustomCourseField =
                                      (val == "Other (Custom)");
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildAddIconButton(isCourseInputActive, () {
                              setState(() {
                                addedCourses.add(showCustomCourseField
                                    ? customCourseController.text
                                    : selectedCourse);
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
                            child: TextFormField(
                              controller: customCourseController,
                              decoration: _inputDecoration("Enter course name"),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ...addedCourses.map((c) => _buildSkillCourseChip(
                            name: c,
                            typeTag: 'Course',
                            levelTag: null,
                            onRemove: () => setState(() => addedCourses.remove(c)))),
                      ],
                    ),

                    _buildSectionCard(
                      title: "Skills * (${addedSkillsList.length})",
                      icon: Icons.star,
                      iconColor: Colors.purple,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                ["Technical", "Soft Skill"],
                                value: selectedSkillType,
                                onChanged: (v) => setState(() {
                                  selectedSkillType = v!;
                                  selectedSkillName = "Select a skill";
                                  showCustomSkillField = false;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildDropdownField(
                                ["Basic", "Intermediate", "Advanced"],
                                value: selectedProficiency,
                                onChanged: (v) =>
                                    setState(() => selectedProficiency = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                selectedSkillType == "Technical"
                                    ? technicalSkills
                                    : softSkills,
                                value: selectedSkillName,
                                onChanged: (val) => setState(() {
                                  selectedSkillName = val!;
                                  showCustomSkillField =
                                      (val == "Other (Custom)");
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildAddIconButton(isSkillInputActive, () {
                              setState(() {
                                addedSkillsList.add({
                                  "name": showCustomSkillField
                                      ? customSkillController.text
                                      : selectedSkillName,
                                  "type": selectedSkillType,
                                  "level": selectedProficiency
                                });
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
                            child: TextFormField(
                              controller: customSkillController,
                              decoration: _inputDecoration("Enter skill name"),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ...addedSkillsList.map((s) => _buildSkillCourseChip(
                            name: s['name'] ?? '',
                            typeTag: s['type'] ?? 'Technical',
                            levelTag: s['level'],
                            onRemove: () => setState(() => addedSkillsList.remove(s)))),
                      ],
                    ),

                    _buildInternshipsSection(),

                    _buildSectionCard(
                      title: "Student Clubs (${addedClubs.length})",
                      icon: Icons.groups,
                      iconColor: Colors.purple,
                      children: [
                        _buildInputField("Club/Organization Name",
                            controller: clubNameController),
                        _buildInputField("Your Role",
                            controller: clubRoleController),
                        _buildAddIconButton(clubNameController.text.isNotEmpty,
                            () {
                          setState(() {
                            addedClubs.add({
                              "name": clubNameController.text,
                              "role": clubRoleController.text
                            });
                            clubNameController.clear();
                            clubRoleController.clear();
                          });
                        }, label: "Add Club"),
                        ...addedClubs.map((c) => _buildAddedTile(
                            "${c['name']} - ${c['role']}",
                            Icons.groups,
                            Colors.purple,
                            () => setState(() => addedClubs.remove(c)))),
                      ],
                    ),

                    _buildSectionCard(
                      title: "Academic Projects (${addedProjects.length})",
                      icon: Icons.work,
                      iconColor: Colors.green,
                      children: [
                        _buildInputField("Project Name",
                            controller: projectNameController),
                        _buildInputField("Brief Description",
                            controller: projectDescController),
                        _buildAddIconButton(projectNameController.text.isNotEmpty,
                            () {
                          setState(() {
                            addedProjects.add({
                              "name": projectNameController.text,
                              "description": projectDescController.text
                            });
                            projectNameController.clear();
                            projectDescController.clear();
                          });
                        }, label: "Add Project"),
                        ...addedProjects.map((p) => _buildAddedTile(
                            "${p['name']} - ${p['description']}",
                            Icons.work,
                            Colors.green,
                            () => setState(() => addedProjects.remove(p)))),
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

  Widget _buildHeader() => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A6CFF), Color(0xFF9226FF)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isEditMode)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
            const Icon(Icons.person_add_alt_1, color: Colors.white, size: 40),
            const SizedBox(height: 10),
            Text(
              widget.isEditMode ? 'Edit Profile' : 'Create Profile',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );

  Widget _buildSectionCard(
          {required String title,
          IconData? icon,
          Color? iconColor,
          required List<Widget> children}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      );

  static const _internshipsBlue = Color(0xFF2A6CFF);

  Widget _buildInternshipsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => internshipsExpanded = !internshipsExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.work_outline, color: _internshipsBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "Internships (${addedInternships.length})",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    internshipsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 28,
                    color: Colors.black54,
                  ),
                ],
              ),
            ),
          ),
          if (internshipsExpanded) ...[
            const Divider(height: 24),
            _buildInputField(
              "Internship/Training Title",
              controller: internTitleController,
              onChanged: (_) => setState(() {}),
            ),
            _buildInputField(
              "Company/Organization",
              controller: internCompanyController,
              onChanged: (_) => setState(() {}),
            ),
            _buildInputField(
              "Duration (e.g., 3 months, Summer 2024)",
              controller: internDurationController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final canAdd = internTitleController.text.trim().isNotEmpty &&
                    internCompanyController.text.trim().isNotEmpty &&
                    internDurationController.text.trim().isNotEmpty;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canAdd
                        ? () {
                            setState(() {
                              addedInternships.add({
                                "title": internTitleController.text.trim(),
                                "company": internCompanyController.text.trim(),
                                "duration": internDurationController.text.trim(),
                              });
                              internTitleController.clear();
                              internCompanyController.clear();
                              internDurationController.clear();
                            });
                          }
                        : null,
                    icon: Icon(
                      Icons.add,
                      color: canAdd ? Colors.white : Colors.grey,
                      size: 20,
                    ),
                    label: Text(
                      "Add Internship",
                      style: TextStyle(
                        color: canAdd ? Colors.white : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canAdd ? _internshipsBlue : Colors.grey[400],
                      disabledBackgroundColor: Colors.grey[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                );
              },
            ),
            if (addedInternships.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...addedInternships.map((i) => _buildInternshipTile(
                    title: i['title'] ?? '',
                    company: i['company'] ?? '',
                    duration: i['duration'] ?? '',
                    onRemove: () => setState(() => addedInternships.remove(i)),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInternshipTile({
    required String title,
    required String company,
    required String duration,
    required VoidCallback onRemove,
  }) {
    final subtitle = [company, duration].where((s) => s.isNotEmpty).join(' • ');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String hint,
          {bool isRequired = false,
          TextEditingController? controller,
          ValueChanged<String>? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          onChanged: onChanged,
          validator: (v) =>
              isRequired && (v == null || v.isEmpty) ? "Required" : null,
          decoration: _inputDecoration(hint),
        ),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      );

  Widget _buildDropdownField(List<String> items,
          {String? value, ValueChanged<String?>? onChanged}) =>
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        items: items
            .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: onChanged,
        decoration: _inputDecoration(""),
      );

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5, top: 5),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _buildAddIconButton(bool active, VoidCallback onTap,
          {String? label}) =>
      label == null
          ? IconButton(
              onPressed: active ? onTap : null,
              icon: Icon(Icons.add_circle,
                  color: active ? Colors.blue : Colors.grey, size: 30),
            )
          : ElevatedButton.icon(
              onPressed: active ? onTap : null,
              icon: const Icon(Icons.add),
              label: Text(label),
            );

  Widget _buildAddedTile(
          String text, IconData icon, Color color, VoidCallback onRemove) =>
      Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: color, size: 20),
          title: Text(text, style: const TextStyle(fontSize: 13)),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ),
      );

  /// Card style for Skills & Courses: icon, name, type tag, level tag, remove.
  Widget _buildSkillCourseChip({
    required String name,
    required String typeTag,
    String? levelTag,
    required VoidCallback onRemove,
  }) {
    const purple = Color(0xFF9226FF);
    final typeBg = purple.withOpacity(0.2);
    final levelBg = levelTag == null
        ? null
        : levelTag == 'Basic'
            ? const Color(0xFFFFF3E0) // light orange/amber
            : levelTag == 'Intermediate'
                ? const Color(0xFFE3F2FD) // light blue
                : const Color(0xFFE8F5E9); // light green (Advanced)
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.school_rounded, color: purple, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                _buildChip(typeTag, typeBg),
                if (levelTag != null) _buildChip(levelTag, levelBg!),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 20, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      );

  Widget _buildFinalSubmitButton() => ElevatedButton(
        onPressed: isFormValid ? saveUserProfile : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
          backgroundColor: const Color(0xFF2A6CFF),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: const Text(
          "Complete Profile",
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
}