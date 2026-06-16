import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// 把 integration_test 上报的各 reportKey 时间线落盘为
/// `build/perf/[key].timeline_summary.json`（含 frame build/raster 统计）。
Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final timeline = driver.Timeline.fromJson(value);
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile(
          entry.key,
          pretty: true,
          includeSummary: true,
          destinationDirectory: 'build/perf',
        );
      }
    },
  );
}
