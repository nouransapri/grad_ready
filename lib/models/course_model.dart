/// Firestore catalog course + user transcript row for GPA / charts.
library course_model;

export 'course.dart' show Course;

/// One row in [users.added_courses] for weighted GPA: (grade × credits) / total credits.
class UserCourseEntry {
  final String name;
  /// Grade points on a 4.0 scale (or normalized — see [AnalysisService]).
  final double gradePoints;
  final double credits;

  const UserCourseEntry({
    required this.name,
    required this.gradePoints,
    required this.credits,
  });

  bool get isValid => name.trim().isNotEmpty && credits > 0 && gradePoints >= 0;
}
