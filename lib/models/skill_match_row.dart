/// One row from skill_match_results.csv: user-job match percentage and recommend flag.
class SkillMatchRow {
  final String userId;
  final String jobId;
  final double matchPercentage;
  final bool recommend;

  const SkillMatchRow({
    required this.userId,
    required this.jobId,
    required this.matchPercentage,
    required this.recommend,
  });
}
