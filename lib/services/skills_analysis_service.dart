/// Canonical weighted match % for skills gap: Σ(contribution × weight) / Σ(weight).
///
/// [perSkillContribution] is typically in **0–1** (e.g. min(userLevel/requiredLevel, 1)).
/// [weights] must be parallel and positive (e.g. job skill weight 1–10).
class SkillsAnalysisService {
  SkillsAnalysisService._();

  /// Returns a ratio in **[0, 1]**.
  ///
  /// Spec: `match += score * weight; totalWeight += weight; return totalWeight > 0 ? match/totalWeight : 0`
  static double weightedMatchRatio(
    List<double> perSkillContribution,
    List<int> weights,
  ) {
    if (perSkillContribution.isEmpty || weights.isEmpty) return 0;
    if (perSkillContribution.length != weights.length) {
      throw ArgumentError(
        'perSkillContribution (${perSkillContribution.length}) and weights (${weights.length}) must match',
      );
    }
    double match = 0;
    double totalWeight = 0;
    for (var i = 0; i < perSkillContribution.length; i++) {
      final w = weights[i];
      if (w <= 0) continue;
      final s = perSkillContribution[i].clamp(0.0, 1.0);
      match += s * w;
      totalWeight += w;
    }
    return totalWeight > 0 ? match / totalWeight : 0;
  }

  /// Same as [weightedMatchRatio] × 100 for UI labels.
  static double weightedMatchPercent(
    List<double> perSkillContribution,
    List<int> weights,
  ) =>
      weightedMatchRatio(perSkillContribution, weights) * 100;
}
