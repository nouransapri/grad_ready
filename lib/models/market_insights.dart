class MarketInsights {
  final int jobCount;
  final String avgSalary;
  final String growthRate;
  final List<String> topJobs;
  final List<String> topCompanies;

  /// Shown after the count, e.g. "Flutter / Dart-related jobs" vs broader sample.
  final String jobListKind;

  /// When set, the feed failed; show this instead of pretending numbers are real.
  final String? errorMessage;

  const MarketInsights({
    required this.jobCount,
    required this.avgSalary,
    required this.growthRate,
    required this.topJobs,
    required this.topCompanies,
    this.jobListKind = 'new Flutter jobs',
    this.errorMessage,
  });

  bool get hasLiveData => errorMessage == null;

  factory MarketInsights.fallback() => const MarketInsights(
        jobCount: 0,
        avgSalary: '—',
        growthRate: '—',
        topJobs: [],
        topCompanies: [],
        jobListKind: 'new Flutter jobs',
        errorMessage:
            'Could not load live listings. Pull down to retry, or check your connection.',
      );
}
