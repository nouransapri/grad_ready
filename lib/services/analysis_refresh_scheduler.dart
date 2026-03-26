import 'dart:async';

import 'package:flutter/foundation.dart';

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
        debugPrint('AnalysisRefreshScheduler: refresh failed: $e');
        if (kDebugMode) debugPrintStack(stackTrace: st);
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
