library analytics;

export 'package:analytics/outputs/active_campaign_output.dart';
export 'analytic_log_adapter.dart';

/// Analytics output abstract class
abstract class AnalyticsOutput {
  /// Send even tracking
  ///
  /// `name` event name
  ///
  /// `info` the event data
  void sendEvent(String name, dynamic info);

  /// Send user properties
  ///
  /// `info` user properties
  void sendUserProperty(Map info);
}

/// Analytics class
class Analytics {
  Analytics._privateConstructor();
  static Analytics shared = Analytics._privateConstructor();
  List<AnalyticsOutput> _outputs;

  /// Set the analytics outputs
  set output(dynamic output) {
    if (output is List<AnalyticsOutput>) {
      _outputs = output;
    } else if (output is AnalyticsOutput) {
      _outputs = [output];
    }
  }

  /// Loop through all outputs to send analytics events
  void sendEvent(String name, dynamic info) {
    for (final output in _outputs) {
      output.sendEvent(name, info);
    }
  }

  /// Loop through all outputs to send user properties
  void sendUserProperty(Map info) {
    for (final output in _outputs) {
      output.sendUserProperty(info);
    }
  }
}
