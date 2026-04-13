import 'dart:async';
import 'dart:developer' as developer;

/// Coalesces rapid skill updates into a single [refresh] call per [uid].
class AnalysisRefreshScheduler {
  AnalysisRefreshScheduler._();

  static final Map<String, Timer> _timers = {};
  static const Duration debounce = Duration(milliseconds: 650);

  /// Schedules [refresh]. Cancels any pending refresh for the same [uid].
  static void schedule(String uid, Future<void> Function() refresh) {
    if (uid.isEmpty) return;
    _timers[uid]?.cancel();
    _timers[uid] = Timer(debounce, () async {
      _timers.remove(uid);
      try {
        await refresh();
      } catch (e, st) {
        developer.log(
          'AnalysisRefreshScheduler: refresh failed: $e',
          name: 'AnalysisRefreshScheduler',
          error: e,
          stackTrace: st,
        );
      }
    });
  }

  /// For tests: cancel pending timer without running refresh.
  static void cancelForTest(String uid) {
    _timers[uid]?.cancel();
    _timers.remove(uid);
  }

  static bool hasPendingForTest(String uid) => _timers.containsKey(uid);
}
