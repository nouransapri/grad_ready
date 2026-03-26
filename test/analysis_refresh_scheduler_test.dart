import 'package:flutter_test/flutter_test.dart';
import 'package:grad_ready/services/analysis_refresh_scheduler.dart';

void main() {
  test('schedule coalesces multiple calls into one refresh', () async {
    var refreshCount = 0;
    AnalysisRefreshScheduler.schedule('user1', () async {
      refreshCount++;
    });
    AnalysisRefreshScheduler.schedule('user1', () async {
      refreshCount++;
    });
    AnalysisRefreshScheduler.schedule('user1', () async {
      refreshCount++;
    });

    expect(refreshCount, 0);
    await Future<void>.delayed(
      AnalysisRefreshScheduler.debounce + const Duration(milliseconds: 100),
    );
    expect(refreshCount, 1);

    AnalysisRefreshScheduler.cancelForTest('user1');
  });

  test('different uids get independent timers', () async {
    var a = 0;
    var b = 0;
    AnalysisRefreshScheduler.schedule('a', () async {
      a++;
    });
    AnalysisRefreshScheduler.schedule('b', () async {
      b++;
    });

    await Future<void>.delayed(
      AnalysisRefreshScheduler.debounce + const Duration(milliseconds: 100),
    );
    expect(a, 1);
    expect(b, 1);

    AnalysisRefreshScheduler.cancelForTest('a');
    AnalysisRefreshScheduler.cancelForTest('b');
  });
}
