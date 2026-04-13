class AdminUserSummary {
  final String uid;
  final String name;
  final double? gpa;
  final String academicYear;
  final bool isSuspended;

  const AdminUserSummary({
    required this.uid,
    required this.name,
    required this.gpa,
    required this.academicYear,
    required this.isSuspended,
  });
}
